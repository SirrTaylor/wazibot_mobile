/// lib/shared/widgets/loading_shimmer.dart
library;

import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class LoadingShimmer extends StatelessWidget {
  final double? height;
  final double? width;
  final double radius;

  const LoadingShimmer({
    super.key,
    this.height,
    this.width,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Shimmer.fromColors(
      baseColor: isDark ? const Color(0xFF1A2235) : const Color(0xFFE8EDF5),
      highlightColor: isDark ? const Color(0xFF243045) : const Color(0xFFF4F6FA),
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1A2235) : const Color(0xFFE8EDF5),
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class ShimmerList extends StatelessWidget {
  final int count;
  final double itemHeight;

  const ShimmerList({super.key, this.count = 5, this.itemHeight = 70});

  @override
  Widget build(BuildContext context) => Column(
        children: List.generate(
          count,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: LoadingShimmer(height: itemHeight),
          ),
        ),
      );
}
