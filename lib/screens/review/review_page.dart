import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:wastefood/services/firestore_service.dart';

class ReviewPage extends StatefulWidget {
  final String produkId;
  final String userId;
  final String tokoId;
  final String orderId;

  const ReviewPage({
    super.key,
    required this.produkId,
    required this.userId,
    required this.tokoId,
    required this.orderId,
  });

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  double _rating = 0;
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  final FirestoreService firestoreService = FirestoreService();

  Future<void> _submitReview() async {
    if (_rating == 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Silakan beri rating terlebih dahulu.")),
        );
      }
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final komentar = _commentController.text.trim();
      final int rating = _rating.round();

      // Simpan review ke produk
      await firestoreService.saveReviewProduk(
        produkId: widget.produkId,
        userId: widget.userId,
        orderId: widget.orderId,
        rating: rating,
        komentar: komentar,
      );

      // Simpan review ke toko
      await firestoreService.saveReviewToko(
        tokoId: widget.tokoId,
        userId: widget.userId,
        orderId: widget.orderId,
        rating: rating,
        komentar: komentar,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Ulasan berhasil dikirim!")),
      );

      Navigator.pop(context);
    } catch (e) {
      debugPrint("Error saat mengirim ulasan: $e");

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Gagal mengirim ulasan. Silakan coba lagi.")),
        );
      }
    }

    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }

  void _skipReview() {
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: const Text("Berikan Ulasan"),
        backgroundColor: Colors.green,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              "Berapa bintang yang ingin Anda berikan?",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            RatingBar.builder(
              initialRating: 0,
              minRating: 1,
              allowHalfRating: true,
              itemCount: 5,
              itemBuilder: (context, _) =>
                  const Icon(Icons.star, color: Colors.amber),
              onRatingUpdate: (rating) {
                setState(() => _rating = rating);
              },
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _commentController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: "Tulis komentar (opsional)...",
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const Spacer(),
            if (_isSubmitting)
              const CircularProgressIndicator()
            else
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _submitReview,
                      child: const Text(
                        "Kirim Ulasan",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton(
                    onPressed: _skipReview,
                    child: const Text(
                      "Lewati",
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
