import 'package:flutter/material.dart';
import '../utils/url_launcher.dart';
import '../widgets/page_navigation.dart';

const String kFallbackHead = 'assets/image/headimg_dl.jpg';

class HomePage extends StatelessWidget {
  final PageController pageController;
  final bool isEasterEggUnlocked;

  const HomePage({
    super.key,
    required this.pageController,
    required this.isEasterEggUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                image: DecorationImage(
                  image: AssetImage(kFallbackHead),
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: () => launchUrlString('https://blog.191800.xyz/'),
              child: RichText(
                text: const TextSpan(
                  children: [
                    TextSpan(
                      text: 'ZY-EFUN',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextSpan(
                      text: ' ',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              '描述 着\nZY沂沨。',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white, fontSize: 18, height: 1.5),
            ),
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeInOut,
                );
              },
              child: const Text(
                'ZY.Zone！！& ZY沂沨！',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            const Spacer(),
            PageNavigation(
              currentPage: 0,
              totalPages: isEasterEggUnlocked ? 7 : 6,
              pageController: pageController,
            ),
          ],
        ),
      ),
    );
  }
}
