import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';

import 'models/upload_file.dart';
import 'pages/home_page.dart';
import 'pages/transfer_page.dart';
import 'pages/protobuf_page.dart';
import 'pages/when_page.dart';
import 'pages/register_page.dart';
import 'pages/about_page.dart';
import 'pages/contact_page.dart';

const List<String> kBackgroundImages = [
  'assets/image/bg_01.jpg',
  'assets/image/bg_02.jpg',
  'assets/image/bg_03.jpg',
  'assets/image/bg_04.jpg',
  'assets/image/bg_05.jpg',
  'assets/image/bg_06.png',
  'assets/image/bg_07.jpg',
  'assets/image/bg_08.png',
  'assets/image/bg_09.jpg',
  'assets/image/bg_10.jpg',
  'assets/image/bg_11.jpg',
  'assets/image/bg_12.jpg',
  'assets/image/bg_13.jpg',
];

void main() {
  runApp(const ZyToolApp());
}

class ZyToolApp extends StatelessWidget {
  const ZyToolApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ZY沂沨',
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF080B12),
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C7CFF),
          brightness: Brightness.dark,
          surface: const Color(0xFF111620),
        ),
        fontFamily: 'Source Sans Pro',
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final PageController _pageController = PageController();
  Timer? _autoScrollTimer;
  Timer? _countdownTimer;
  List<int>? _backgroundOrder;
  int _currentBgIndex = 0;
  int _currentPage = 0;
  bool _isLoading = true;
  bool _didStartPreload = false;
  bool _isSidebarOpen = false;
  Duration _timeUntilBirthday = Duration.zero;
  int _titleTapCount = 0;
  Timer? _titleTapTimer;
  bool _isEasterEggUnlocked = false;

  List<UploadFile> _uploadFiles = [];
  bool _isUploading = false;

  final List<SiteLink> _siteLinks = [
    SiteLink(
      emoji: '🍉',
      title: 'ZY沂沨·札记',
      description: 'ZY沂沨的博客，每次的新博文都在这里',
      url: 'https://blog.191800.xyz/',
    ),
    SiteLink(
      emoji: '🍒',
      title: 'ZY沂沨·导航',
      description: '收集热门API站~',
      url: 'http://tsmoe.3vkj.vip/',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _backgroundOrder = _shuffledBackgroundOrder();
    _calculateBirthday();
    _startCountdown();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didStartPreload) return;
    _didStartPreload = true;
    _preloadInitialBackgrounds();
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _countdownTimer?.cancel();
    _titleTapTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentBgIndex = (_currentBgIndex + 1) % _safeBackgroundOrder.length;
        });
        _preloadUpcomingBackgrounds();
      }
    });
  }

  List<int> _shuffledBackgroundOrder() {
    return List<int>.generate(kBackgroundImages.length, (index) => index)
      ..shuffle(Random());
  }

  List<int> get _safeBackgroundOrder {
    final order = _backgroundOrder;
    if (order != null && order.isNotEmpty) return order;

    final newOrder = _shuffledBackgroundOrder();
    _backgroundOrder = newOrder;
    return newOrder;
  }

  Future<void> _preloadInitialBackgrounds() async {
    final initialIndexes = _safeBackgroundOrder.take(3).toList();

    await Future.wait(
      initialIndexes.map((index) async {
        await precacheImage(AssetImage(kBackgroundImages[index]), context);
        if (!mounted) return;
      }),
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
    _startAutoScroll();
    _preloadUpcomingBackgrounds();
  }

  void _preloadUpcomingBackgrounds() {
    for (var offset = 1; offset <= 3; offset++) {
      final order = _safeBackgroundOrder;
      final orderIndex = (_currentBgIndex + offset) % order.length;
      final imageIndex = order[orderIndex];
      precacheImage(AssetImage(kBackgroundImages[imageIndex]), context);
    }
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _calculateBirthday();
        });
      }
    });
  }

  void _calculateBirthday() {
    try {
      final now = DateTime.now();
      var birthday = DateTime(now.year, 12, 12);
      if (now.isAfter(birthday)) {
        birthday = DateTime(now.year + 1, 12, 12);
      }
      _timeUntilBirthday = birthday.difference(now);
    } catch (e) {
      _timeUntilBirthday = const Duration(days: 365);
    }
  }

  void _handleTitleTap() {
    setState(() {
      _titleTapCount++;
    });

    _titleTapTimer?.cancel();

    if (_titleTapCount == 1) {
      _titleTapTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _titleTapCount < 9) {
          setState(() {
            _titleTapCount = 0;
          });
        }
      });
    }

    if (_titleTapCount >= 9 && _titleTapCount < 12) {
      final remaining = 12 - _titleTapCount;
      _titleTapTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && !_isEasterEggUnlocked) {
          setState(() {
            _titleTapCount = 0;
          });
        }
      });
      _showTopSnackBar('还有$remaining次');
    }

    if (_titleTapCount >= 12) {
      setState(() {
        _isEasterEggUnlocked = true;
        _titleTapCount = 0;
      });
      _showTopSnackBar('彩蛋页面已解锁！');
    }
  }

  void _showTopSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 20,
          right: 20,
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(
        allowMultiple: true,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final newFiles = result.files.map((file) {
          final ext = file.extension ?? 'bin';
          return UploadFile(
            name: file.name,
            extension: ext,
            bytes: file.bytes ?? Uint8List(0),
            fileSize: file.size,
          );
        }).toList();

        setState(() {
          _uploadFiles.addAll(newFiles);
        });

        await _uploadAllFiles();
      }
    } catch (e) {
      debugPrint('File picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('选择文件失败: $e'),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _uploadAllFiles() async {
    setState(() {
      _isUploading = true;
    });

    for (var file in _uploadFiles) {
      if (file.bytes.isEmpty) continue;

      setState(() {
        file.isUploading = true;
        file.progress = 0;
        file.error = null;
        file.url = null;
      });

      try {
        final url = await _uploadFile(file);
        setState(() {
          file.url = url;
          file.isCompleted = true;
          file.progress = 1;
          file.uploadDate = DateTime.now();
        });
      } catch (e) {
        setState(() {
          file.error = e.toString();
        });
      } finally {
        setState(() {
          file.isUploading = false;
        });
      }
    }

    setState(() {
      _isUploading = false;
    });
  }

  Future<String> _uploadFile(UploadFile file) async {
    final credUrl = Uri.parse(
      'https://ci-exhibition.cloud.tencent.com/samples/createUploadKey?ext=${file.extension}&ciProcess=sensitive-content-recognition',
    );

    final credResponse = await http.get(
      credUrl,
      headers: {
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; 22041216C Build/TP1A.220624.014) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.7204.179 Mobile Safari/537.36',
        'sec-ch-ua-platform': '"Android"',
        'origin': 'https://cloud.tencent.com',
        'x-requested-with': 'mark.via',
        'sec-fetch-site': 'same-site',
        'sec-fetch-mode': 'cors',
        'sec-fetch-dest': 'empty',
        'referer': 'https://cloud.tencent.com/act/pro/ciExhibition?from=15775&tab=contentReview&sub=pictureReview',
      },
    );

    if (credResponse.statusCode != 200) {
      throw Exception('获取上传凭证失败: ${credResponse.statusCode}');
    }

    final credData = json.decode(credResponse.body);
    if (credData['data'] == null || credData['data']['key'] == null || credData['data']['uploadAuthorization'] == null) {
      throw Exception('获取凭证失败：返回数据格式异常');
    }

    final uploadKey = credData['data']['key'];
    final uploadAuth = credData['data']['uploadAuthorization'];
    final uploadUrl = 'https://ci-h5-demo-1258125638.cos.ap-chengdu.myqcloud.com/$uploadKey';

    setState(() {
      file.progress = 0.3;
    });

    final uploadResponse = await http.put(
      Uri.parse(uploadUrl),
      headers: {
        'Authorization': uploadAuth,
        'Content-Length': file.bytes.length.toString(),
        'User-Agent': 'Mozilla/5.0 (Linux; Android 13; 22041216C Build/TP1A.220624.014) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.7204.179 Mobile Safari/537.36',
        'sec-ch-ua-platform': '"Android"',
        'origin': 'https://cloud.tencent.com',
        'x-requested-with': 'mark.via',
        'sec-fetch-site': 'same-site',
        'sec-fetch-mode': 'cors',
        'sec-fetch-dest': 'empty',
        'referer': 'https://cloud.tencent.com/act/pro/ciExhibition?from=15775&tab=contentReview&sub=pictureReview',
      },
      body: file.bytes,
    );

    setState(() {
      file.progress = 0.9;
    });

    if (uploadResponse.statusCode != 200) {
      throw Exception('上传失败: ${uploadResponse.statusCode}');
    }

    return uploadUrl;
  }

  @override
  Widget build(BuildContext context) {
    final isNotHomePage = _currentPage > 0;

    return Scaffold(
      body: Stack(
        children: [
          _buildBackgroundSlideshow(),
          if (isNotHomePage)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.5),
              ),
            ),
          if (isNotHomePage)
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                child: Container(
                  color: Colors.transparent,
                ),
              ),
            ),
          PageView(
            controller: _pageController,
            scrollDirection: Axis.vertical,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            children: [
              HomePage(
                pageController: _pageController,
                isEasterEggUnlocked: _isEasterEggUnlocked,
              ),
              TransferPage(
                pageController: _pageController,
                isEasterEggUnlocked: _isEasterEggUnlocked,
                uploadFiles: _uploadFiles,
                isUploading: _isUploading,
                onPickFiles: _pickFiles,
              ),
              ProtobufPage(
                pageController: _pageController,
                isEasterEggUnlocked: _isEasterEggUnlocked,
              ),
              if (_isEasterEggUnlocked)
                WhenPage(
                  pageController: _pageController,
                  isEasterEggUnlocked: _isEasterEggUnlocked,
                  timeUntilBirthday: _timeUntilBirthday,
                ),
              RegisterPage(
                pageController: _pageController,
                isEasterEggUnlocked: _isEasterEggUnlocked,
                siteLinks: _siteLinks,
              ),
              AboutPage(
                pageController: _pageController,
                isEasterEggUnlocked: _isEasterEggUnlocked,
              ),
              ContactPage(
                pageController: _pageController,
                isEasterEggUnlocked: _isEasterEggUnlocked,
              ),
            ],
          ),
          _buildNavigationSidebar(),
          _buildHeader(),
          if (_isLoading) _buildPageLoader(),
        ],
      ),
    );
  }

  Widget _buildBackgroundSlideshow() {
    final order = _safeBackgroundOrder;
    final imageIndex = order[_currentBgIndex % order.length];
    final imageUrl = kBackgroundImages[imageIndex];
    final alignment = _kenBurnsAlignment(_currentBgIndex);

    return Positioned.fill(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 1000),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        child: TweenAnimationBuilder<double>(
          key: ValueKey<String>(imageUrl),
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(seconds: 5),
          curve: Curves.linear,
          builder: (context, progress, child) {
            final offset = _kenBurnsOffset(_currentBgIndex, progress);
            return Transform.translate(
              offset: offset,
              child: Transform.scale(
                scale: 1.08 - progress * 0.03,
                alignment: alignment,
                child: child,
              ),
            );
          },
          child: Image.asset(
            imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: double.infinity,
            alignment: alignment,
          ),
        ),
      ),
    );
  }

  Alignment _kenBurnsAlignment(int index) {
    const alignments = [
      Alignment.topCenter,
      Alignment.bottomCenter,
      Alignment.centerLeft,
      Alignment.centerRight,
    ];
    return alignments[index % alignments.length];
  }

  Offset _kenBurnsOffset(int index, double progress) {
    const distance = 18.0;
    final amount = (progress - 0.5) * distance;
    switch (index % 4) {
      case 0:
        return Offset(0, -amount);
      case 1:
        return Offset(0, amount);
      case 2:
        return Offset(-amount, 0);
      default:
        return Offset(amount, 0);
    }
  }

  Widget _buildPageLoader() {
    return Positioned.fill(
      child: AnimatedOpacity(
        opacity: _isLoading ? 1 : 0,
        duration: const Duration(milliseconds: 500),
        child: Container(
          color: const Color(0xFF080B12),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 42,
                  height: 42,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  '欢迎来到ZY沂沨の~',
                  style: TextStyle(color: Colors.white, fontSize: 18),
                ),
                const SizedBox(height: 8),
                const Text(
                  '注：首次加载需要点耐心~',
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Positioned(
      top: 0,
      left: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: GestureDetector(
            onTap: () {
              setState(() {
                _isSidebarOpen = !_isSidebarOpen;
              });
            },
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.42),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white24),
              ),
              child: Icon(
                _isSidebarOpen ? Icons.close : Icons.menu,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationSidebar() {
    final navItems = [
      {'icon': '🎪', 'title': '欢迎页面', 'page': 0},
      {'icon': '📤', 'title': '临时传输', 'page': 1},
      {'icon': '🔧', 'title': 'Protobuf工具', 'page': 2},
      if (_isEasterEggUnlocked) {'icon': '💡', 'title': '异想天开', 'page': 3},
      {'icon': '🌏', 'title': '站点一览', 'page': _isEasterEggUnlocked ? 4 : 3},
      {'icon': '👒', 'title': '聊聊ZY沂沨', 'page': _isEasterEggUnlocked ? 5 : 4},
      {'icon': '📧', 'title': '联系ZY沂沨', 'page': _isEasterEggUnlocked ? 6 : 5},
    ];

    return Positioned(
      left: 0,
      top: 0,
      bottom: 0,
      child: AnimatedSlide(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutCubic,
        offset: _isSidebarOpen ? Offset.zero : const Offset(-1.05, 0),
        child: SafeArea(
          child: Container(
            width: 245,
            margin: const EdgeInsets.fromLTRB(16, 86, 0, 24),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.58),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white24),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 28,
                  offset: Offset(0, 18),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: _handleTitleTap,
                  child: const Text(
                    'ZY沂沨',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '快速切换页面',
                  style: TextStyle(color: Colors.white60, fontSize: 13),
                ),
                const SizedBox(height: 22),
                ...navItems.map((item) {
                  final isActive = _currentPage == item['page'];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: GestureDetector(
                      onTap: () {
                        _pageController.animateToPage(
                          item['page'] as int,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                        setState(() {
                          _isSidebarOpen = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? const Color(0xFF5677FC)
                              : Colors.white.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isActive ? Colors.white38 : Colors.white10,
                          ),
                        ),
                        child: Row(
                          children: [
                            Text(
                              item['icon'] as String,
                              style: const TextStyle(fontSize: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                item['title'] as String,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: isActive
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
