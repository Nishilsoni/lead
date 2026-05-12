import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Shimmer skeleton loader for the lead list.
class ShimmerLoading extends StatelessWidget {
  final int itemCount;

  const ShimmerLoading({super.key, this.itemCount = 6});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE5E7EB),
      highlightColor: const Color(0xFFF5F7FA),
      child: ListView.builder(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: itemCount,
        itemBuilder: (_, index) => const _ShimmerCard(),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _box(width: 160, height: 18),
              _box(width: 80, height: 24, radius: 20),
            ],
          ),
          const SizedBox(height: 12),
          _box(width: 120, height: 14),
          const SizedBox(height: 10),
          Row(
            children: [
              _box(width: 16, height: 16),
              const SizedBox(width: 8),
              _box(width: 130, height: 14),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _box(width: 16, height: 16),
              const SizedBox(width: 8),
              _box(width: 180, height: 14),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _box(width: 60, height: 22, radius: 12),
              const SizedBox(width: 8),
              _box(width: 80, height: 22, radius: 12),
            ],
          ),
        ],
      ),
    );
  }

  Widget _box({
    required double width,
    required double height,
    double radius = 6,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}
