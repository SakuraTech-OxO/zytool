import 'package:flutter/material.dart';
import '../models/upload_file.dart';
import '../widgets/file_item.dart';
import '../widgets/page_navigation.dart';

class TransferPage extends StatelessWidget {
  final PageController pageController;
  final bool isEasterEggUnlocked;
  final List<UploadFile> uploadFiles;
  final bool isUploading;
  final VoidCallback onPickFiles;

  const TransferPage({
    super.key,
    required this.pageController,
    required this.isEasterEggUnlocked,
    required this.uploadFiles,
    required this.isUploading,
    required this.onPickFiles,
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
              '📤 临时传输',
              style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              '文件上传到腾讯COS，有效期约5分钟',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 30),
            GestureDetector(
              onTap: isUploading ? null : onPickFiles,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                decoration: BoxDecoration(
                  color: isUploading ? Colors.grey : const Color(0xFF5677FC),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isUploading ? Icons.hourglass_empty : Icons.add_circle_outline,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isUploading ? '上传中...' : '选择文件',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: uploadFiles.isEmpty
                  ? const Center(
                      child: Text(
                        '暂无文件',
                        style: TextStyle(color: Colors.white54, fontSize: 16),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: uploadFiles.length,
                      itemBuilder: (context, index) {
                        return FileItem(file: uploadFiles[index], index: index);
                      },
                    ),
            ),
            PageNavigation(
              currentPage: 1,
              totalPages: isEasterEggUnlocked ? 6 : 5,
              pageController: pageController,
            ),
          ],
        ),
      ),
    );
  }
}
