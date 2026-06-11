import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:pinput/pinput.dart';
import 'package:servicesphereagent/features/chat/screens/chat_screen.dart';

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

  // ─── LAUNCH MAPS ───────────────────────────────────────────────────────────

  Future<void> _launchMap(GeoPoint? location, String address) async {
    Uri googleMapsUrl;
    if (location != null) {
      googleMapsUrl = Uri.parse(
        'google.navigation:q=${location.latitude},${location.longitude}',
      );
    } else {
      googleMapsUrl = Uri.parse(
        'google.navigation:q=${Uri.encodeComponent(address)}',
      );
    }
    try {
      if (await canLaunchUrl(googleMapsUrl)) {
        await launchUrl(googleMapsUrl);
      } else {
        final webUrl = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query='
          '${location?.latitude},${location?.longitude}',
        );
        await launchUrl(webUrl);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not open maps.')));
      }
    }
  }

  // ─── MAKE CALL ─────────────────────────────────────────────────────────────

  Future<void> _makePhoneCall(String? phoneNumber) async {
    if (phoneNumber == null || phoneNumber.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No phone number provided.')),
        );
      }
      return;
    }
    final uri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch dialer.')),
        );
      }
    }
  }

  // ─── QUOTE DIALOG ──────────────────────────────────────────────────────────

  Future<void> _showQuoteDialog() async {
    final priceController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Submit Quote',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Review the job and enter your price quote:',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: priceController,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Amount (₹)',
                  prefixText: '₹ ',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Enter an amount';
                  final price = double.tryParse(v);
                  if (price == null || price <= 0) {
                    return 'Enter a valid amount';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                final price = double.parse(priceController.text.trim());
                Navigator.pop(ctx);
                _updateStatus('accepted', quotePrice: price);
              }
            },
            style: ElevatedButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Send Quote'),
          ),
        ],
      ),
    );
  }

  // ─── REQUEST PAYMENT ───────────────────────────────────────────────────────

  Future<void> _requestPayment() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(widget.jobId)
          .update({'paymentStatus': 'pending_payment'});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── VERIFY OTP (CLOUD FUNCTION) ───────────────────────────────────────────

  Future<void> _verifyAgentOTP(String otp, String type) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          const Center(child: CircularProgressIndicator(color: Colors.green)),
    );

    try {
      final HttpsCallable callable = FirebaseFunctions.instance.httpsCallable(
        'verifyJobOTP',
      );
      final response = await callable.call(<String, dynamic>{
        'jobId': widget.jobId,
        'otp': otp,
        'type': type,
      });

      if (!mounted) return;
      Navigator.pop(context); // Close loading spinner
      Navigator.pop(context); // Close bottom sheet

      if (response.data['success'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.data['message']),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Close loading spinner
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message ?? 'Verification failed'),
          backgroundColor: Colors.redAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ─── OTP BOTTOM SHEET UI ───────────────────────────────────────────────────

  void _showOtpVerificationSheet(String type) {
    final defaultPinTheme = PinTheme(
      width: 50,
      height: 60,
      textStyle: const TextStyle(
        fontSize: 22,
        color: Colors.black87,
        fontWeight: FontWeight.w600,
      ),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 32,
            top: 32,
            left: 24,
            right: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                type == 'start'
                    ? 'Verify Start Code'
                    : 'Verify Completion Code',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                type == 'start'
                    ? 'Ask the customer for the 6-digit START code on their app.'
                    : 'Ask the customer for the final 6-digit END code to finish the job.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
              ),
              const SizedBox(height: 32),
              Pinput(
                length: 6,
                defaultPinTheme: defaultPinTheme,
                focusedPinTheme: defaultPinTheme.copyDecorationWith(
                  border: Border.all(color: Colors.green.shade600, width: 2),
                ),
                onCompleted: (pin) => _verifyAgentOTP(pin, type),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── CANCEL JOB ────────────────────────────────────────────────────────────

  Future<void> _cancelJob() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Job?'),
        content: const Text(
          'This will remove you from this job and send it back to the marketplace.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, Cancel',
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
            'status': 'pending_quote',
            'agentId': FieldValue.delete(),
            'agentName': FieldValue.delete(),
            'agentPhone': FieldValue.delete(),
            'agentRating': FieldValue.delete(),
            'acceptedAt': FieldValue.delete(),
            'price': 0.0,
          });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job cancelled. Open for others.')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── UPDATE STATUS (WITH WALLET GATEKEEPER) ────────────────────────────────

  Future<void> _updateStatus(String newStatus, {double? quotePrice}) async {
    setState(() => _isLoading = true);

    try {
      // 1. THE GATEKEEPER: Check wallet balance BEFORE accepting or quoting
      if (newStatus == 'accepted') {
        final agentDoc = await FirebaseFirestore.instance
            .collection('agents')
            .doc(_currentUid)
            .get();

        final double walletBalance = (agentDoc.data()?['walletBalance'] ?? 0)
            .toDouble();

        if (walletBalance < 500.0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Low Balance! You need at least ₹500 in your wallet to accept jobs.',
                ),
                backgroundColor: Colors.red,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 4),
              ),
            );
          }
          setState(() => _isLoading = false);
          return; // STOP THE FUNCTION - DO NOT ACCEPT OR QUOTE
        }
      }

      // 2. If balance is sufficient, proceed with the transaction
      final docRef = FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(widget.jobId);

      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final snapshot = await transaction.get(docRef);
        if (!snapshot.exists) throw Exception('Job does not exist!');

        final currentStatus = snapshot.get('status') as String;

        if (newStatus == 'accepted' &&
            currentStatus != 'pending' &&
            currentStatus != 'pending_quote') {
          throw Exception('Job is already taken.');
        }

        final Map<String, dynamic> updateData = {};

        if (newStatus == 'accepted') {
          if (quotePrice != null) {
            updateData['price'] = quotePrice;
            updateData['quotedAt'] = FieldValue.serverTimestamp();
            updateData['status'] = 'pending_approval';
            updateData['agentId'] = _currentUid;
          } else {
            updateData['status'] = 'accepted';
            updateData['acceptedAt'] = FieldValue.serverTimestamp();
            updateData['agentId'] = _currentUid;
          }

          final agentSnap = await transaction.get(
            FirebaseFirestore.instance.collection('agents').doc(_currentUid),
          );
          if (agentSnap.exists) {
            updateData['agentName'] = agentSnap.get('name') ?? '';
            updateData['agentPhone'] = agentSnap.get('phone') ?? '';
            updateData['agentRating'] = agentSnap.get('rating') ?? 0.0;
          }
        } else if (newStatus == 'completed') {
          updateData['status'] = 'completed';
          updateData['completedAt'] = FieldValue.serverTimestamp();
          updateData['paymentStatus'] = 'unpaid';
        }

        transaction.update(docRef, updateData);
      });

      if (mounted) {
        final msg = newStatus == 'accepted'
            ? (quotePrice != null ? 'Quote sent!' : 'Job accepted!')
            : 'Job marked as complete! Waiting for customer payment.';

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('serviceRequests')
          .doc(widget.jobId)
          .snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.hasData && snapshot.data!.exists
            ? snapshot.data!.data() as Map<String, dynamic>
            : widget.jobData;

        final String title = data['title'] ?? 'Untitled Job';
        final String description = data['description'] ?? 'No description.';
        final String address = data['address'] ?? 'No location';
        final double price = (data['price'] ?? 0).toDouble();
        final String category = data['category'] ?? 'General';
        final String customerName = data['customerName'] ?? 'Customer';
        final String status = data['status'] ?? 'pending';
        final String paymentStatus = data['paymentStatus'] ?? 'pending';
        final String? customerPhone = data['customerPhone'];
        final String? imageUrl = data['imageUrl'];
        final GeoPoint? location = data['location'];
        final Timestamp? scheduledTs = data['scheduledTime'];

        final String scheduledStr = scheduledTs != null
            ? DateFormat('MMM d, y • h:mm a').format(scheduledTs.toDate())
            : 'ASAP';

        return Scaffold(
          backgroundColor: isDark
              ? const Color(0xFF121212)
              : const Color(0xFFF4F6F9),
          appBar: AppBar(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            elevation: 0,
            centerTitle: true,
            leading: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: isDark ? Colors.white : Colors.black87,
                size: 20,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Job Details',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── JOB PHOTO ──────────────────────────────────
                      if (imageUrl != null && imageUrl.isNotEmpty) ...[
                        GestureDetector(
                          onTap: () => showDialog(
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
                          ),
                          child: Container(
                            height: 220,
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
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
                                borderRadius: BorderRadius.circular(20),
                                color: Colors.black26,
                              ),
                              child: const Center(
                                child: Icon(
                                  Icons.fullscreen_rounded,
                                  color: Colors.white,
                                  size: 32,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],

                      // ── SCHEDULE BANNER ────────────────────────────
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 18,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.calendar_today_rounded,
                                color: Colors.orange.shade800,
                                size: 18,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'SCHEDULED FOR',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.orange.shade800,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  scheduledStr,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ── PRICE CARD ─────────────────────────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withOpacity(0.75),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: theme.colorScheme.primary.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
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
                                letterSpacing: 1.5,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              price > 0
                                  ? '₹ ${price.toStringAsFixed(0)}'
                                  : 'Needs Quote',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 38,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Estimated Earnings',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── DESCRIPTION ────────────────────────────────
                      _buildSectionHeader('Problem Description'),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade600,
                                height: 1.6,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── LOCATION & CUSTOMER ────────────────────────
                      _buildSectionHeader('Location & Customer'),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF2A2A2A)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildDetailRow(
                                    Icons.location_on_rounded,
                                    'Address',
                                    address,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                IconButton.filled(
                                  onPressed: () =>
                                      _launchMap(location, address),
                                  icon: const Icon(
                                    Icons.directions_rounded,
                                    color: Colors.white,
                                  ),
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.blue,
                                  ),
                                  tooltip: 'Navigate',
                                ),
                              ],
                            ),
                            if (status != 'pending' &&
                                status != 'pending_quote') ...[
                              const Divider(height: 28),
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildDetailRow(
                                      Icons.person_rounded,
                                      'Customer',
                                      customerName,
                                    ),
                                  ),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton.filled(
                                        onPressed: () =>
                                            _makePhoneCall(customerPhone),
                                        icon: const Icon(
                                          Icons.phone_rounded,
                                          color: Colors.white,
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.green,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      IconButton.filled(
                                        onPressed: () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => ChatScreen(
                                              jobId: widget.jobId,
                                              otherUserName: customerName,
                                            ),
                                          ),
                                        ),
                                        icon: const Icon(
                                          Icons.chat_bubble_rounded,
                                          color: Colors.white,
                                        ),
                                        style: IconButton.styleFrom(
                                          backgroundColor: Colors.indigo,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),

              // ── BOTTOM ACTION BAR ─────────────────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 12,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildActionArea(status, paymentStatus, price),
                    if (status == 'accepted') ...[
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: _isLoading ? null : _cancelJob,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.red,
                          ),
                          child: const Text(
                            'Cancel Job',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ─── ACTION AREA (STATE MACHINE) ───────────────────────────────────────────

  Widget _buildActionArea(String status, String paymentStatus, double price) {
    if (status == 'pending_quote' || (status == 'pending' && price == 0)) {
      return _buildPrimaryButton(
        label: 'QUOTE PRICE',
        color: Colors.blueAccent,
        icon: Icons.attach_money_rounded,
        onPressed: _showQuoteDialog,
      );
    }
    if (status == 'pending') {
      return _buildPrimaryButton(
        label: 'ACCEPT JOB',
        color: Colors.green,
        icon: Icons.check_circle_outline_rounded,
        onPressed: () => _updateStatus('accepted'),
      );
    }
    if (status == 'pending_approval') {
      return _buildStatusContainer(
        'WAITING FOR CUSTOMER APPROVAL',
        Colors.orange,
      );
    }
    if (status == 'accepted') {
      return _SliderCompleteButton(
        label: 'Slide to Start',
        onSlideComplete: () => _showOtpVerificationSheet('start'),
      );
    }
    if (status == 'in_progress') {
      if (paymentStatus == 'paid') {
        return _SliderCompleteButton(
          label: 'Slide to Complete',
          onSlideComplete: () => _showOtpVerificationSheet('end'),
        );
      } else if (paymentStatus == 'pending_payment') {
        return _buildStatusContainer(
          'WAITING FOR CUSTOMER PAYMENT...',
          Colors.teal,
        );
      } else {
        return _buildPrimaryButton(
          label: 'Request Payment',
          color: Colors.teal,
          icon: Icons.payments_rounded,
          onPressed: _requestPayment,
        );
      }
    }
    if (status == 'completed') {
      return _buildStatusContainer('JOB COMPLETED', Colors.green);
    }

    return _buildStatusContainer('JOB CLOSED', Colors.grey);
  }

  Widget _buildStatusContainer(String text, MaterialColor color) {
    return Container(
      width: double.infinity,
      height: 54,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.shade200),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: color.shade800,
          fontSize: 13,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required Color color,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _isLoading ? null : onPressed,
        icon: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Icon(icon, size: 20),
        label: Text(
          label,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: Colors.black54,
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: Colors.black54),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SLIDER COMPLETE BUTTON
// ═══════════════════════════════════════════════════════════════════════════════

class _SliderCompleteButton extends StatefulWidget {
  final VoidCallback onSlideComplete;
  final String label;

  const _SliderCompleteButton({
    required this.onSlideComplete,
    required this.label,
  });

  @override
  State<_SliderCompleteButton> createState() => _SliderCompleteButtonState();
}

class _SliderCompleteButtonState extends State<_SliderCompleteButton>
    with SingleTickerProviderStateMixin {
  double _dragPosition = 0;
  bool _isCompleted = false;

  // Total track width minus thumb size
  static const double _thumbSize = 56;
  static const double _trackHeight = 60;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticOut),
    );
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails details, double maxWidth) {
    if (_isCompleted) return;
    setState(() {
      _dragPosition = (_dragPosition + details.delta.dx).clamp(
        0,
        maxWidth - _thumbSize,
      );
    });
  }

  void _onDragEnd(DragEndDetails details, double maxWidth) {
    if (_isCompleted) return;

    final threshold = (maxWidth - _thumbSize) * 0.85;

    if (_dragPosition >= threshold) {
      setState(() {
        _dragPosition = maxWidth - _thumbSize;
        _isCompleted = true;
      });
      Future.delayed(const Duration(milliseconds: 300), () {
        widget.onSlideComplete();
        // Reset after OTP dialog
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            setState(() {
              _dragPosition = 0;
              _isCompleted = false;
            });
          }
        });
      });
    } else {
      // Snap back
      setState(() => _dragPosition = 0);
      _shakeController.forward(from: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth;
        final progress = _dragPosition / (maxWidth - _thumbSize);

        return AnimatedBuilder(
          animation: _shakeAnimation,
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(
                _isCompleted
                    ? 0
                    : _shakeAnimation.value == 0
                    ? 0
                    : 4 * (0.5 - (_shakeAnimation.value % 0.25) / 0.25),
                0,
              ),
              child: child,
            );
          },
          child: Container(
            height: _trackHeight,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Color.lerp(
                primaryColor.withOpacity(0.15),
                primaryColor.withOpacity(0.3),
                progress,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withOpacity(0.3)),
            ),
            child: Stack(
              children: [
                // Progress fill
                Positioned.fill(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(15),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: _dragPosition + _thumbSize,
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
                  ),
                ),

                // Label
                Center(
                  child: AnimatedOpacity(
                    opacity: 1 - progress,
                    duration: const Duration(milliseconds: 100),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(width: _thumbSize),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: primaryColor.withOpacity(0.5),
                          size: 18,
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: primaryColor.withOpacity(0.7),
                          size: 18,
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: primaryColor,
                          size: 18,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.label,
                          style: TextStyle(
                            color: primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Draggable thumb
                Positioned(
                  left: _dragPosition,
                  top: 0,
                  bottom: 0,
                  child: GestureDetector(
                    onHorizontalDragUpdate: (d) => _onDragUpdate(d, maxWidth),
                    onHorizontalDragEnd: (d) => _onDragEnd(d, maxWidth),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 100),
                      width: _thumbSize,
                      height: _thumbSize,
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: _isCompleted ? Colors.green : primaryColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Icon(
                        _isCompleted
                            ? Icons.check_rounded
                            : Icons.chevron_right_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
