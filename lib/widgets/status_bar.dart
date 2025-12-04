import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/text_styles.dart';

class StatusBar extends StatelessWidget {
  final bool isOffline;
  final String? gpsCoordinates;

  const StatusBar({super.key, this.isOffline = true, this.gpsCoordinates});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.backgroundElevated.withOpacity(0.95),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            // Offline Mode Indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isOffline ? AppColors.alertAmber : AppColors.success,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isOffline ? Icons.cloud_off : Icons.cloud_done,
                    size: 14,
                    color: AppColors.textOnLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isOffline ? 'OFFLINE' : 'ONLINE',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.textOnLight,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),

            // GPS Coordinates
            if (gpsCoordinates != null) ...[
              const Icon(
                Icons.location_on,
                size: 16,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(gpsCoordinates!, style: AppTextStyles.coordinates),
            ],
          ],
        ),
      ),
    );
  }
}
