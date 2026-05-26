import 'package:flutter/material.dart';

class PageNavigation extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final PageController pageController;

  const PageNavigation({
    super.key,
    required this.currentPage,
    required this.totalPages,
    required this.pageController,
  });

  @override
  Widget build(BuildContext context) {
    final canGoUp = currentPage > 0;
    final canGoDown = currentPage < totalPages - 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 40),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: canGoUp
                ? () {
                    pageController.animateToPage(
                      currentPage - 1,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: canGoUp
                      ? Colors.white.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.keyboard_arrow_up,
                color: canGoUp ? Colors.white : Colors.white30,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 30),
          GestureDetector(
            onTap: () {
              pageController.animateToPage(
                0,
                duration: const Duration(milliseconds: 500),
                curve: Curves.easeInOut,
              );
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.home,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
          const SizedBox(width: 30),
          GestureDetector(
            onTap: canGoDown
                ? () {
                    pageController.animateToPage(
                      currentPage + 1,
                      duration: const Duration(milliseconds: 500),
                      curve: Curves.easeInOut,
                    );
                  }
                : null,
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: canGoDown
                      ? Colors.white.withOpacity(0.3)
                      : Colors.white.withOpacity(0.1),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.keyboard_arrow_down,
                color: canGoDown ? Colors.white : Colors.white30,
                size: 30,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
