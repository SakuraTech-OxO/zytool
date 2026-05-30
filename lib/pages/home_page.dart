import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../utils/url_launcher.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  String _hitokotoText = '';
  String _displayedText = '';
  Timer? _typingTimer;
  int _charIndex = 0;
  bool _isFetching = false;

  late AnimationController _gradientController;

  @override
  void initState() {
    super.initState();
    _gradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _fetchHitokoto();
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    _gradientController.dispose();
    super.dispose();
  }

  Future<void> _fetchHitokoto() async {
    if (_isFetching) return;
    _isFetching = true;
    try {
      final response = await http.get(Uri.parse('https://v1.hitokoto.cn/'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final hitokoto = data['hitokoto'] as String? ?? '';
        if (mounted) {
          setState(() {
            _hitokotoText = hitokoto;
            _displayedText = '';
            _charIndex = 0;
          });
          _startTyping();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hitokotoText = '愿你眼中总有光芒，活成你想要的模样。';
          _displayedText = '';
          _charIndex = 0;
        });
        _startTyping();
      }
    } finally {
      _isFetching = false;
    }
  }

  void _startTyping() {
    _typingTimer?.cancel();
    _typingTimer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      if (_charIndex < _hitokotoText.length) {
        if (mounted) {
          setState(() {
            _charIndex++;
            _displayedText = _hitokotoText.substring(0, _charIndex);
          });
        }
      } else {
        timer.cancel();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                image: const DecorationImage(
                  image: AssetImage('assets/image/headimg_dl.jpg'),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: () => launchUrlString('https://blog.191800.xyz/'),
              child: AnimatedBuilder(
                animation: _gradientController,
                builder: (context, child) {
                  final t = _gradientController.value;
                  Color hueShift(Color base, double shift) {
                    final hsl = HSLColor.fromColor(base);
                    final newHue = (hsl.hue + shift * 360) % 360;
                    return hsl.withHue(newHue).toColor();
                  }
                  final baseColors = const [
                    Color(0xFFFF6B6B),
                    Color(0xFFFFE66D),
                    Color(0xFF4ECDC4),
                    Color(0xFF45B7D1),
                    Color(0xFF96E6A1),
                  ];
                  final shiftedColors = baseColors.map((c) => hueShift(c, t)).toList();
                  return ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [...shiftedColors, shiftedColors.first],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(bounds);
                    },
                    blendMode: BlendMode.srcIn,
                    child: const Text(
                      'ZY-EFUN',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _displayedText,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
