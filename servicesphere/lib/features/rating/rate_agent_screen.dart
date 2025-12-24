import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart'; // Run: flutter pub add flutter_rating_bar

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
        // Formula: ((OldRating * OldCount) + NewRating) / (OldCount + 1)
        double newRating =
            ((currentRating * ratingCount) + _rating) / (ratingCount + 1);

        // Update Agent
        transaction.update(agentRef, {
          'rating': newRating,
          'ratingCount': ratingCount + 1,
        });
      });

      // 2. Mark the Job as Rated so the button disappears
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Rate Service",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const CircleAvatar(
              radius: 40,
              backgroundColor: Color(0xFFF0F4FF),
              child: Icon(Icons.person, size: 40, color: Color(0xFF2F5C8A)),
            ),
            const SizedBox(height: 16),
            Text(
              "How was ${widget.agentName}?",
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              "Your feedback helps us improve.",
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 32),

            // Rating Bar (Star Input)
            RatingBar.builder(
              initialRating: 5,
              minRating: 1,
              direction: Axis.horizontal,
              allowHalfRating: true,
              itemCount: 5,
              itemPadding: const EdgeInsets.symmetric(horizontal: 4.0),
              itemBuilder: (context, _) =>
                  const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) {
                setState(() => _rating = rating);
              },
            ),
            const SizedBox(height: 32),

            // Review Text Field
            TextField(
              controller: _reviewController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Write a review (optional)...",
                filled: true,
                fillColor: const Color(0xFFF8F9FA),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 32),

            // Submit Button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitRating,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        "Submit Review",
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
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
