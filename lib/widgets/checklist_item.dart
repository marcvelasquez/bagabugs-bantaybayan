import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/theme/colors.dart';

/// Checklist item widget with checkbox toggle and swipe-to-delete
class ChecklistItem extends StatelessWidget {
  final String title;
  final bool isChecked;
  final VoidCallback onTap;
  final VoidCallback? onDelete;
  final bool isDarkMode;
  final String? uniqueKey;

  const ChecklistItem({
    super.key,
    required this.title,
    required this.isChecked,
    required this.onTap,
    this.onDelete,
    required this.isDarkMode,
    this.uniqueKey,
  });

  @override
  Widget build(BuildContext context) {
    final content = InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDarkMode ? Colors.white.withOpacity(0.1) : Colors.grey[200]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            // Checkbox icon
            Icon(
              isChecked ? Icons.check_circle : Icons.circle_outlined,
              color: isChecked
                  ? AppColors.success
                  : (isDarkMode ? Colors.white.withOpacity(0.4) : Colors.grey[400]),
              size: 22,
            ),
            const SizedBox(width: 12),
            // Title
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  decoration: isChecked ? TextDecoration.lineThrough : null,
                  decorationColor: isDarkMode ? Colors.white.withOpacity(0.3) : Colors.grey[400],
                  color: isChecked
                      ? (isDarkMode ? Colors.white.withOpacity(0.5) : Colors.grey[500])
                      : (isDarkMode ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );

    if (onDelete == null) {
      return content;
    }

    return Dismissible(
      key: Key(uniqueKey ?? title),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        color: AppColors.error,
        child: const Icon(
          Icons.delete_outline,
          color: Colors.white,
          size: 24,
        ),
      ),
      confirmDismiss: (direction) async {
        HapticFeedback.mediumImpact();
        return true;
      },
      onDismissed: (direction) {
        onDelete!();
      },
      child: content,
    );
  }
}
