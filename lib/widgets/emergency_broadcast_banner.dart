import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/text_styles.dart';

class EmergencyBroadcastBanner extends StatefulWidget {
  final String message;
  final VoidCallback? onDismiss;
  final VoidCallback? onReadMore;
  final bool isUrgent; // true for red, false for amber

  const EmergencyBroadcastBanner({
    super.key,
    required this.message,
    this.onDismiss,
    this.onReadMore,
    this.isUrgent = false,
  });

  @override
  State<EmergencyBroadcastBanner> createState() =>
      _EmergencyBroadcastBannerState();
}

class _EmergencyBroadcastBannerState extends State<EmergencyBroadcastBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _slideController;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOut));

    _slideController.forward();
  }

  @override
  void dispose() {
    _slideController.dispose();
    super.dispose();
  }

  void _dismiss() {
    _slideController.reverse().then((_) {
      if (widget.onDismiss != null) {
        widget.onDismiss!();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final backgroundColor = widget.isUrgent
        ? AppColors.emergencyRed
        : AppColors.alertAmber;

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: backgroundColor,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowMedium,
              offset: const Offset(0, 4),
              blurRadius: 8,
            ),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Row(
            children: [
              Icon(
                widget.isUrgent ? Icons.emergency : Icons.campaign,
                color: AppColors.textOnLight,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'GLOBAL ANNOUNCEMENT',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textOnLight,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.message,
                      style: AppTextStyles.emergencyBanner,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (widget.onReadMore != null)
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right,
                    color: AppColors.textOnLight,
                  ),
                  onPressed: widget.onReadMore,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              IconButton(
                icon: const Icon(Icons.close, color: AppColors.textOnLight),
                onPressed: _dismiss,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
