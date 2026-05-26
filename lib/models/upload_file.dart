import 'package:flutter/foundation.dart';

class UploadFile {
  final String name;
  final String extension;
  final Uint8List bytes;
  final int fileSize;
  double progress;
  String? url;
  String? error;
  bool isUploading;
  bool isCompleted;
  DateTime? uploadDate;

  UploadFile({
    required this.name,
    required this.extension,
    required this.bytes,
    required this.fileSize,
    this.progress = 0,
    this.url,
    this.error,
    this.isUploading = false,
    this.isCompleted = false,
    this.uploadDate,
  });
}

class SiteLink {
  final String emoji;
  final String title;
  final String description;
  final String url;

  const SiteLink({
    required this.emoji,
    required this.title,
    required this.description,
    required this.url,
  });
}
