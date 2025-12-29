import 'dart:math'; // Required for random OTP generation
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class JobDetailsScreen extends StatefulWidget {
  final String jobId;
  final Map<String, dynamic> jobData;

  const JobDetailsScreen({
    super.key,
    required this.jobId,
    required this.jobData,
  });

  @override
  State<JobDetailsScreen> createState() => _JobDetailsScreenState();
}

class _JobDetailsScreenState extends State<JobDetailsScreen> {
  bool _isLoading = false;
  final String _currentUid = FirebaseAuth.instance.currentUser!.uid;

  // --- 1. LAUNCH MAPS ---
  Future<void> _launchMap(GeoPoint? location, String address) async {
    Uri googleMapsUrl;
    if (location != null) {
      // Use exact coordinates if available
      googleMapsUrl = Uri.parse(
        "google.navigation:q=${location.latitude},${location.longitude}",
      );
    } else {
      // Fallback to text address
      googleMapsUrl = Uri.parse(
        "google.navigation:q=${Uri.encodeComponent(address)}",
      );
    }

    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        // Fallback to web browser
        final webUrl = Uri.parse(
          "https://www.google.com/maps/search/?api=1&query=${location?.latitude},${location?.longitude}",
        );
        await launchUrl(webUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not open maps application.")),
        );
      }
    }
  }

  // --- 2. MAKE CALL ---
  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No phone number provided by customer.")),
      );
      return;
    }

    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch dialer")),
        );
      }
    }
  }

  // --- 3. OTP DIALOG (SECURITY CHECK) ---
  Future<void> _showOtpDialog(String correctOtp) async {
    final otpController = TextEditingController();

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Enter Completion OTP"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Ask the customer for the 4-digit code shown in their app to verify completion.",
            ),
            const SizedBox(height: 16),
            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 5,
              ),
              decoration: const InputDecoration(
                hintText: "0000",
                border: OutlineInputBorder(),
                counterText: "",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              if (otpController.text.trim() == correctOtp) {
                Navigator.pop(ctx); // Close dialog
                _updateStatus('completed'); // Proceed to complete
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("Incorrect OTP! Ask customer again."),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text("Verify & Complete"),
          ),
        ],
      ),
    );
  }

  // --- 4. UPDATE STATUS (With OTP Generation) ---
  Future<void> _updateStatus(String newStatus, {double? quotePrice}) async {
    setState(() => _isLoading = true);
    try {
      final docRef = FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(widget.jobId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        DocumentSnapshot snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception("Job does not exist!");

        String currentStatus = snapshot.get('status');

        // Race condition check
        if (newStatus == 'accepted' &&
            currentStatus != 'pending' &&
            currentStatus != 'pending_quote') {
          throw Exception("Job is already taken.");
        }

        Map<String, dynamic> updateData = {
          'status': newStatus == 'accepted' && quotePrice != null
              ? 'pending_approval'
              : newStatus,
          'agentId': _currentUid,
        };

        if (newStatus == 'accepted') {
          // If Quoting
          if (quotePrice != null) {
            updateData['price'] = quotePrice;
            updateData['quotedAt'] = FieldValue.serverTimestamp();
            updateData['status'] = 'pending_approval';
          } else {
            // Direct Accept
            updateData['acceptedAt'] = FieldValue.serverTimestamp();
            // Generate OTP
            final random = Random();
            final otp = (1000 + random.nextInt(9000)).toString();
            updateData['completionOtp'] = otp;
          }

          // Add Agent Info (Best effort inside transaction or fetch before)
          // Ideally fetch before transaction to keep it fast, but acceptable for MVP
          DocumentSnapshot agentSnap = await transaction.get(
            FirebaseFirestore.instance.collection('agents').doc(_currentUid),
          );
          if (agentSnap.exists) {
            updateData['agentName'] = agentSnap.get('name');
            updateData['agentPhone'] = agentSnap.get('phone');
            updateData['agentRating'] = agentSnap.get('rating');
          }
        } else if (newStatus == 'completed') {
          updateData['completedAt'] = FieldValue.serverTimestamp();
        }

        transaction.update(docRef, updateData);
      });

      if (mounted) {
        String msg = newStatus == 'accepted'
            ? (quotePrice != null ? "Quote Sent!" : "Job Accepted!")
            : "Job Completed!";
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 5. CANCEL JOB ---
  Future<void> _cancelJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Job?"),
        content: const Text(
          "This will remove you from this job and send it back to the marketplace for other agents. Are you sure?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              "Yes, Cancel",
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(widget.jobId)
          .update({
            'status': 'pending', // Reset status
            'agentId': FieldValue.delete(), // Remove Agent ID
            'agentName': FieldValue.delete(),
            'agentPhone': FieldValue.delete(),
            'agentRating': FieldValue.delete(),
            'acceptedAt': FieldValue.delete(),
            'completionOtp': FieldValue.delete(), // Clear OTP
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Job Cancelled. It is now open for others."),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --- 6. QUOTE DIALOG ---
  Future<void> _showQuoteDialog() async {
    final priceController = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Submit Quote"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("The user requested an estimate. Enter your price:"),
            const SizedBox(height: 16),
            TextField(
              controller: priceController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "Amount (₹)",
                prefixText: "₹ ",
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () {
              final price = double.tryParse(priceController.text.trim());
              if (price != null && price > 0) {
                Navigator.pop(ctx);
                _updateStatus('accepted', quotePrice: price);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Enter a valid amount")),
                );
              }
            },
            child: const Text("Send Quote"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final data = widget.jobData;

    final String title = data['title'] ?? 'Untitled Job';
    final String description = data['description'] ?? 'No description.';
    final String address = data['address'] ?? 'No location';
    final double price = (data['price'] ?? 0).toDouble();
    final String category = data['category'] ?? 'General';
    final String customerName = data['customerName'] ?? 'Customer';
    final String status = data['status'] ?? 'pending';
    final String? customerPhone = data['customerPhone'];

    // Get Location & Schedule & OTP
    final GeoPoint? location = data['location'];
    final Timestamp? scheduledTs = data['scheduledTime'];
    final String otp = data['completionOtp'] ?? '0000';
    // --- NEW: Image URL ---
    final String? imageUrl = data['imageUrl'];

    String scheduledStr = "ASAP";
    if (scheduledTs != null) {
      scheduledStr = DateFormat(
        'MMM d, y • h:mm a',
      ).format(scheduledTs.toDate());
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Job Details",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- 1. JOB PHOTO (NEW) ---
            if (imageUrl != null && imageUrl.isNotEmpty) ...[
              GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => Dialog(
                      backgroundColor: Colors.transparent,
                      child: InteractiveViewer(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.network(imageUrl),
                        ),
                      ),
                    ),
                  );
                },
                child: Container(
                  height: 200,
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    image: DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black26, // Dark overlay for icon visibility
                    ),
                    child: const Center(
                      child: Icon(Icons.zoom_in, color: Colors.white, size: 40),
                    ),
                  ),
                ),
              ),
            ],

            // SCHEDULE BANNER
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 20),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.5)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, color: Colors.orange),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "SCHEDULED FOR",
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                      Text(
                        scheduledStr,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // PRICE CARD
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: theme.primaryColor.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Text(
                    category.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    price > 0 ? "₹ ${price.toStringAsFixed(0)}" : "Needs Quote",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Estimated Earnings",
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // DESCRIPTION
            const Text(
              "Problem Description",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[700],
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // LOCATION & CUSTOMER
            const Text(
              "Location & Customer",
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.grey,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: [
                  // --- ADDRESS WITH NAVIGATE BUTTON ---
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          Icons.location_on,
                          "Address",
                          address,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _launchMap(location, address),
                        icon: const Icon(Icons.directions, color: Colors.blue),
                        tooltip: "Navigate",
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.blue.withOpacity(0.1),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(12),
                        ),
                      ),
                    ],
                  ),

                  const Divider(height: 24),

                  // CUSTOMER INFO WITH CALL BUTTON
                  Row(
                    children: [
                      Expanded(
                        child: _buildDetailRow(
                          Icons.person,
                          "Customer",
                          customerName,
                        ),
                      ),
                      if (status == 'accepted')
                        IconButton(
                          onPressed: () => _makePhoneCall(customerPhone),
                          icon: const Icon(Icons.phone, color: Colors.green),
                          style: IconButton.styleFrom(
                            backgroundColor:
                                (customerPhone != null
                                        ? Colors.green
                                        : Colors.grey)
                                    .withOpacity(0.1),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.all(12),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 100),
          ],
        ),
      ),

      // ACTION BUTTONS (Stacked)
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min, // Wrap content height
          children: [
            SizedBox(
              width: double.infinity,
              height: 56,
              child: _buildActionButton(status, price, otp),
            ),
            // --- CANCEL BUTTON (Visible only if Accepted) ---
            if (status == 'accepted') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: _isLoading ? null : _cancelJob,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                  label: const Text(
                    "Cancel Job",
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    backgroundColor: Colors.red.withOpacity(0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // --- WIDGETS ---
  Widget _buildActionButton(String status, double price, String otp) {
    // 1. Quote
    if (status == 'pending_quote' || (status == 'pending' && price == 0)) {
      return ElevatedButton(
        onPressed: _isLoading ? null : _showQuoteDialog,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blueAccent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "QUOTE PRICE",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      );
    }
    // 2. Accept
    else if (status == 'pending') {
      return ElevatedButton(
        onPressed: _isLoading ? null : () => _updateStatus('accepted'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "ACCEPT JOB",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      );
    }
    // 3. Complete
    else if (status == 'accepted') {
      return ElevatedButton(
        onPressed: _isLoading ? null : () => _showOtpDialog(otp),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 4,
        ),
        child: _isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : const Text(
                "MARK COMPLETED",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      );
    } else if (status == 'pending_approval') {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          "WAITING FOR USER APPROVAL",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
        ),
      );
    } else {
      return Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.grey[300],
          borderRadius: BorderRadius.circular(16),
        ),
        child: const Text(
          "JOB CLOSED",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
        ),
      );
    }
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 20, color: Colors.black54),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
