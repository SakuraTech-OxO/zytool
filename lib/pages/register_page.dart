import 'package:flutter/material.dart';
import '../models/upload_file.dart';
import '../utils/url_launcher.dart';
import '../widgets/page_navigation.dart';

class RegisterPage extends StatelessWidget {
  final PageController pageController;
  final bool isEasterEggUnlocked;
  final List<SiteLink> siteLinks;

  const RegisterPage({
    super.key,
    required this.pageController,
    required this.isEasterEggUnlocked,
    required this.siteLinks,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Text(
              '🍭 ZY沂沨站点一览',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 30),
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: siteLinks.length,
                itemBuilder: (context, index) {
                  final link = siteLinks[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 15),
                    child: GestureDetector(
                      onTap: () => launchUrlString(link.url),
                      child: Container(
                        padding: const EdgeInsets.all(15),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              link.emoji,
                              style: const TextStyle(fontSize: 24),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    link.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    link.description,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.7),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const Icon(
                              Icons.arrow_forward_ios,
                              color: Colors.white54,
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            PageNavigation(
              currentPage: isEasterEggUnlocked ? 4 : 3,
              totalPages: isEasterEggUnlocked ? 7 : 6,
              pageController: pageController,
            ),
          ],
        ),
      ),
    );
  }
}
