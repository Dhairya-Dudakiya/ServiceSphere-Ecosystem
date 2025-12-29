import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

class RateAgentScreen extends StatefulWidget {
  final String jobId;
  final String agentId;
  final String agentName;

  const RateAgentScreen({
    super.key,
    required this.jobId,
    required this.agentId,
    required this.agentName,
  });

  @override
  State<RateAgentScreen> createState() => _RateAgentScreenState();
}

class _RateAgentScreenState extends State<RateAgentScreen> {
  double _rating = 5.0;
  final TextEditingController _reviewController = TextEditingController();
  bool _isLoading = false;

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a star rating")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final agentRef = firestore.collection('agents').doc(widget.agentId);

      // 1. Run a Transaction to safely update the Agent's average rating
      await firestore.runTransaction((transaction) async {
        final agentDoc = await transaction.get(agentRef);

        if (!agentDoc.exists) throw Exception("Agent not found");

        final data = agentDoc.data()!;
        double currentRating = (data['rating'] ?? 0.0).toDouble();
        int ratingCount = (data['ratingCount'] ?? 0) as int;

        // Calculate New Average
        double newRating =
            ((currentRating * ratingCount) + _rating) / (ratingCount + 1);

        // Update Agent
        transaction.update(agentRef, {
          'rating': newRating,
          'ratingCount': ratingCount + 1,
        });
      });

      // 2. Mark the Job as Rated
      await firestore.collection('serviceRequests').doc(widget.jobId).update({
        'isRated': true,
        'userRating': _rating,
        'userReview': _reviewController.text.trim(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Thanks for your feedback!"),
            backgroundColor: Colors.green,
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

  @override
  Widget build(BuildContext context) {
    // Force light theme colors for consistency on this specific modal-like screen
    final primaryColor = Theme.of(context).primaryColor;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA), // Light Grey Background
      appBar: AppBar(
        title: const Text(
          "Rate Service",
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 20),

            // --- AGENT AVATAR ---
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border:
                    Border.all(color: primaryColor.withOpacity(0.2), width: 3),
              ),
              child: CircleAvatar(
                radius: 40,
                backgroundColor: primaryColor.withOpacity(0.1),
                child: Text(
                  widget.agentName.isNotEmpty
                      ? widget.agentName[0].toUpperCase()
                      : 'A',
                  style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: primaryColor),
                ),
              ),
            ),

            const SizedBox(height: 24),

            Text(
              "How was ${widget.agentName}?",
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your feedback helps us improve our service quality.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey, fontSize: 14),
            ),

            const SizedBox(height: 40),

            // --- RATING BAR ---
            RatingBar.builder(
              initialRating: 5,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 8.0),
              itemSize: 40,
              itemBuilder: (context, _) => const Icon(
                Icons.star_rounded,
                color: Colors.amber,
              ),
              onRatingUpdate: (rating) {
                setState(() => _rating = rating);
              },
            ),

            const SizedBox(height: 10),
            Text(
              "$_rating / 5.0",
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.amber),
            ),

            const SizedBox(height: 40),

            // --- REVIEW INPUT ---
            TextField(
              controller: _reviewController,
              maxLines: 4,
              style: const TextStyle(color: Colors.black87),
              decoration: InputDecoration(
                hintText: "Write your review here (optional)...",
                hintStyle: const TextStyle(color: Colors.grey),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: primaryColor, width: 2),
                ),
              ),
            ),

            const SizedBox(height: 32),

            // --- SUBMIT BUTTON ---
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  disabledBackgroundColor: primaryColor.withOpacity(0.6),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : const Text(
                        "Submit Review",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
