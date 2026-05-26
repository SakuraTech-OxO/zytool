import 'package:flutter/material.dart';
import 'avatar.dart';

class ChatMessage extends StatelessWidget {
  final bool isSender;
  final String avatarUrl;
  final String message;
  final Color messageColor;
  final String? highlightText;
  final Color? highlightColor;

  const ChatMessage({
    super.key,
    required this.isSender,
    required this.avatarUrl,
    required this.message,
    required this.messageColor,
    this.highlightText,
    this.highlightColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: isSender
          ? MainAxisAlignment.start
          : MainAxisAlignment.end,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isSender) ...[Avatar(avatarUrl: avatarUrl), const SizedBox(width: 10)],
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isSender
                  ? const Color(0xFF7FFFD4)
                  : const Color(0xFFFFD700),
              borderRadius: BorderRadius.circular(8),
            ),
            child: highlightText != null
                ? RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: message.split(highlightText!)[0],
                          style: TextStyle(color: messageColor, fontSize: 15),
                        ),
                        TextSpan(
                          text: highlightText,
                          style: TextStyle(
                            color: highlightColor,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (message.split(highlightText!).length > 1)
                          TextSpan(
                            text: message.split(highlightText!)[1],
                            style: TextStyle(color: messageColor, fontSize: 15),
                          ),
                      ],
                    ),
                  )
                : Text(
                    message,
                    style: TextStyle(color: messageColor, fontSize: 15),
                  ),
          ),
        ),
        if (!isSender) ...[const SizedBox(width: 10), Avatar(avatarUrl: avatarUrl)],
      ],
    );
  }
}
