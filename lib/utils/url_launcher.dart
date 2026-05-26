import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

void launchUrlString(String url) async {
  if (url.isNotEmpty) {
    final uri = Uri.parse(url);
    try {
      await launchUrl(uri, mode: LaunchMode.platformDefault);
    } catch (e) {
      debugPrint('Failed to launch URL: $e');
    }
  }
}
