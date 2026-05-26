import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

const String kFallbackAvatarAsset = 'assets/image/img_avatar.png';

class Avatar extends StatelessWidget {
  final String avatarUrl;

  const Avatar({super.key, required this.avatarUrl});

  @override
  Widget build(BuildContext context) {
    if (!avatarUrl.startsWith('http')) {
      return Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          image: DecorationImage(
            image: AssetImage(avatarUrl),
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _imageBytes(avatarUrl),
      builder: (context, snapshot) {
        if (snapshot.hasData && snapshot.data != null) {
          return Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              image: DecorationImage(
                image: MemoryImage(snapshot.data!),
                fit: BoxFit.cover,
              ),
            ),
          );
        }
        return Container(
          width: 50,
          height: 50,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            image: DecorationImage(
              image: AssetImage(kFallbackAvatarAsset),
              fit: BoxFit.cover,
            ),
          ),
        );
      },
    );
  }

  Future<Uint8List?> _imageBytes(String url) async {
    try {
      final uri = Uri.parse(
        'https://images.weserv.nl/?url=${Uri.encodeComponent(url)}',
      );
      final response = await http.get(
        uri,
        headers: {
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        },
      );
      if (response.statusCode == 200) {
        return response.bodyBytes;
      }
    } catch (e) {
      debugPrint('Failed to fetch image: $url');
    }
    return null;
  }
}
