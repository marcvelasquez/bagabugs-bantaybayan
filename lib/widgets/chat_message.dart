import 'package:flutter/material.dart';
import '../core/theme/colors.dart';

/// Chat message model
class ChatMessage {
  final String text;
  final bool isBot;
  final DateTime timestamp;

  ChatMessage({required this.text, required this.isBot, DateTime? timestamp})
    : timestamp = timestamp ?? DateTime.now();
}

/// Chat message bubble widget
class ChatMessageWidget extends StatelessWidget {
  final ChatMessage message;
  final bool isDarkMode;

  const ChatMessageWidget({
    super.key,
    required this.message,
    required this.isDarkMode,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isBot = message.isBot;

    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: EdgeInsets.only(
          left: isBot ? 0 : 40,
          right: isBot ? 40 : 0,
          bottom: 10,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Bot icon (only for bot messages)
            if (isBot) ...[
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.smart_toy,
                  size: 18,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 6),
            ],
            // Message bubble
            Flexible(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isBot
                      ? (isDarkMode
                            ? AppColors.darkBackgroundElevated
                            : Colors.grey[100])
                      : const Color(0xFFFF6B6B),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isBot ? 4 : 14),
                    topRight: Radius.circular(isBot ? 14 : 4),
                    bottomLeft: const Radius.circular(14),
                    bottomRight: const Radius.circular(14),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.white.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Text(
                  message.text,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: 14,
                    height: 1.4,
                    color: isBot
                        ? AppColors.lightTextPrimary
                        : (isDarkMode
                              ? AppColors.darkBackgroundDeep
                              : Colors.white),
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
