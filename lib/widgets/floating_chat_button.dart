import 'package:flutter/material.dart';
import '../core/theme/colors.dart';
import '../core/theme/theme.dart';

class FloatingChatButton extends StatelessWidget {
  final VoidCallback onPressed;

  const FloatingChatButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      right: 16,
      bottom: 90, // Above bottom navigation bar
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(
          color: AppColors.surfaceWhite,
          shape: BoxShape.circle,
          boxShadow: AppTheme.heavyShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: const Center(
              child: Icon(
                Icons.chat_bubble_outline,
                color: AppColors.textOnLight,
                size: 28,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
