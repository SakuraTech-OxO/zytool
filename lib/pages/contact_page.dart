import 'package:flutter/material.dart';
import '../utils/url_launcher.dart';
import '../widgets/contact_item.dart';
import '../widgets/page_navigation.dart';

class ContactPage extends StatelessWidget {
  final PageController pageController;
  final bool isEasterEggUnlocked;

  const ContactPage({
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
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Text(
                      '💖 联系ZY沂沨',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 30),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: const Column(
                        children: [
                          ContactItem(
                            label: 'Email',
                            value: 'zyyf@191800.xyz',
                            url: 'mailto://zyyf@191800.xyz',
                          ),
                          Divider(color: Colors.white24, height: 30),
                          ContactItem(
                            label: 'QQGroup',
                            value: '1057604000',
                            url: 'https://qm.qq.com/q/qWBYLy7qo0',
                          ),
                          Divider(color: Colors.white24, height: 30),
                          ContactItem(
                            label: 'OICQ',
                            value: '1918530969',
                            url: 'https://wpa.qq.com/msgrd?v=3&uin=1918530969&site=qq&menu=yes',
                          ),
                          Divider(color: Colors.white24, height: 30),
                          ContactItem(
                            label: 'Github',
                            value: 'Ts-yf',
                            url: 'https://github.com/Ts-yf',
                          ),
                          Divider(color: Colors.white24, height: 30),
                          ContactItem(
                            label: 'Gitee',
                            value: 'Ts-yf',
                            url: 'https://gitee.com/Ts-yf',
                          ),
                          Divider(color: Colors.white24, height: 30),
                          ContactItem(
                            label: 'Blog',
                            value: 'blog.191800.xyz',
                            url: 'https://blog.191800.xyz',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
            const Text(
              '© 2026 ZY沂沨. All rights reserved.',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'ZY沂沨 by ',
                  style: TextStyle(color: Colors.white54),
                ),
                GestureDetector(
                  onTap: () => launchUrlString('https://blog.191800.xyz/'),
                  child: const Text(
                    'Brand',
                    style: TextStyle(
                      color: Color(0xFF6C7CFF),
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
                const Text(
                  ' . All right reserved 2026',
                  style: TextStyle(color: Colors.white54),
                ),
              ],
            ),
            const SizedBox(height: 10),
            PageNavigation(
              currentPage: isEasterEggUnlocked ? 5 : 4,
              totalPages: isEasterEggUnlocked ? 6 : 5,
              pageController: pageController,
            ),
          ],
        ),
      ),
    );
  }
}
