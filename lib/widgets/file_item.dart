import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/upload_file.dart';
import '../utils/formatters.dart';
import '../utils/url_launcher.dart';

class FileItem extends StatelessWidget {
  final UploadFile file;
  final int index;

  const FileItem({super.key, required this.file, required this.index});

  @override
  Widget build(BuildContext context) {
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(file.extension.toLowerCase());
    final isVideo = ['mp4', 'avi', 'mov', 'wmv', 'flv', 'webm'].contains(file.extension.toLowerCase());
    final isAudio = ['mp3', 'wav', 'ogg', 'aac', 'flac', 'm4a'].contains(file.extension.toLowerCase());

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (isImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    file.bytes,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 60,
                        height: 60,
                        color: Colors.grey[800],
                        child: const Icon(Icons.image, color: Colors.white54),
                      );
                    },
                  ),
                )
              else if (isVideo)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.purple.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.videocam, color: Colors.white, size: 30),
                )
              else if (isAudio)
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.music_note, color: Colors.white, size: 30),
                )
              else
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.insert_drive_file, color: Colors.white, size: 30),
                ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      file.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '.${file.extension}  ${formatFileSize(file.fileSize)}',
                      style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
                    ),
                    if (file.uploadDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        '上传于 ${formatDateTime(file.uploadDate!)}',
                        style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 11),
                      ),
                    ],
                  ],
                ),
              ),
              if (file.isCompleted)
                const Icon(Icons.check_circle, color: Colors.green, size: 24)
              else if (file.error != null)
                const Icon(Icons.error, color: Colors.red, size: 24)
              else if (file.isUploading)
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                ),
            ],
          ),
          if (file.isUploading) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: file.progress,
              backgroundColor: Colors.white.withOpacity(0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF5677FC)),
            ),
            const SizedBox(height: 5),
            Text(
              '${(file.progress * 100).toInt()}%',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
          if (file.error != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: file.error!));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('错误信息已复制'),
                    duration: Duration(seconds: 2),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        file.error!,
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Icon(Icons.copy, color: Colors.red, size: 16),
                  ],
                ),
              ),
            ),
          ],
          if (file.url != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => launchUrlString(file.url!),
                      child: Text(
                        file.url!,
                        style: const TextStyle(
                          color: Color(0xFF6C7CFF),
                          fontSize: 12,
                          decoration: TextDecoration.underline,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: file.url!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('链接已复制'),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    child: const Icon(Icons.copy, color: Colors.white54, size: 16),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
