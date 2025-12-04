import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/text_styles.dart';
import '../core/theme/theme.dart';

class ClusterMarker extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;

  const ClusterMarker({super.key, required this.count, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          shape: BoxShape.circle,
          boxShadow: AppTheme.mediumShadow,
          border: Border.all(color: AppColors.emergencyRed, width: 2),
        ),
        child: Center(
          child: Text(
            count.toString(),
            style: AppTextStyles.clusterNumber.copyWith(
              color: AppColors.emergencyRed,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
