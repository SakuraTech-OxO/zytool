import 'package:flutter/material.dart';

class WhenPage extends StatelessWidget {
  final Duration timeUntilBirthday;

  const WhenPage({
    super.key,
    required this.timeUntilBirthday,
  });

  @override
  Widget build(BuildContext context) {
    final days = timeUntilBirthday.inDays;
    final hours = timeUntilBirthday.inHours % 24;
    final minutes = timeUntilBirthday.inMinutes % 60;
    final seconds = timeUntilBirthday.inSeconds % 60;
    final progress = 1 - seconds / 60;

    return SizedBox.expand(
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            RichText(
              text: const TextSpan(
                children: [
                  TextSpan(
                    text: '距离 ',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                  TextSpan(
                    text: 'ZY沂沨',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(
                    text: ' 的生日 🎉',
                    style: TextStyle(color: Colors.white, fontSize: 24),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            _buildCircularCountdown(days, hours, minutes, seconds, progress),
          ],
        ),
      ),
    );
  }

  Widget _buildCircularCountdown(
    int days,
    int hours,
    int minutes,
    int seconds,
    double progress,
  ) {
    return Container(
      width: 270,
      height: 270,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black.withOpacity(0.42),
        border: Border.all(color: Colors.white24),
        boxShadow: const [
          BoxShadow(
            color: Colors.black38,
            blurRadius: 28,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 235,
            height: 235,
            child: CircularProgressIndicator(
              value: progress.clamp(0, 1),
              strokeWidth: 8,
              backgroundColor: Colors.white.withOpacity(0.12),
              color: const Color(0xFFFFD700),
              strokeCap: StrokeCap.round,
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                days.toString().padLeft(2, '0'),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 58,
                  fontWeight: FontWeight.w900,
                  height: 1,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '天',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              Text(
                '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
