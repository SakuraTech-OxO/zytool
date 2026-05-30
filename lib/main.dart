import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.io) 'dart:io';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:window_size/window_size.dart';

import 'models/upload_file.dart';
import 'pages/home_page.dart';
import 'pages/transfer_page.dart';
import 'pages/protobuf_page.dart';
import 'pages/when_page.dart';
import 'pages/register_page.dart';
import 'pages/about_page.dart';
import 'pages/contact_page.dart';
import 'pages/qqbot_chat_page.dart';
import 'pages/qqbot_auth_page.dart';

const String kFallbackHead = 'assets/image/headimg_dl.jpg';

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await LiquidGlassWidgets.initialize();
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS)) {
    setWindowMinSize(const Size(800, 600));
  }
  runApp(LiquidGlassWidgets.wrap(child: const ZyToolApp()));
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
        scaffoldBackgroundColor: Colors.transparent,
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

  // QQBot Auth State
  String? _qqbotToken;
  int? _qqbotUserId;
  String? _qqbotAppId;
  String _qqbotBackendUrl = kIsWeb ? 'http://localhost:3000' : (Platform.isAndroid ? 'http://10.0.2.2:3000' : 'http://localhost:3000');

  final List<SiteLink> _siteLinks = [
    SiteLink(emoji: '🍉', title: 'ZY沂沨·札记', description: 'ZY沂沨的博客，每次的新博文都在这里', url: 'https://blog.191800.xyz/'),
    SiteLink(emoji: '🍒', title: 'ZY沂沨·导航', description: '收集热门API站~', url: 'http://tsmoe.3vkj.vip/'),
  ];

  List<_NavItem> get _navItems => [
    _NavItem(icon: Icons.home_rounded, title: '欢迎页面', page: 0),
    _NavItem(icon: Icons.smart_toy_rounded, title: 'QQBot Chat', page: 1),
    _NavItem(icon: Icons.upload_file_rounded, title: '临时传输', page: 2),
    _NavItem(icon: Icons.code_rounded, title: 'Protobuf工具', page: 3),
    if (_isEasterEggUnlocked) _NavItem(icon: Icons.lightbulb_rounded, title: '异想天开', page: 4),
    _NavItem(icon: Icons.language_rounded, title: '站点一览', page: _isEasterEggUnlocked ? 5 : 4),
    if (_isEasterEggUnlocked) _NavItem(icon: Icons.chat_rounded, title: '聊聊ZY沂沨', page: 6),
    _NavItem(icon: Icons.email_rounded, title: '联系ZY沂沨', page: _isEasterEggUnlocked ? 7 : 5),
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
    if (!_didStartPreload) {
      _didStartPreload = true;
      _preloadInitialBackgrounds();
    }
  }

  @override
  void dispose() {
    _autoScrollTimer?.cancel();
    _countdownTimer?.cancel();
    _titleTapTimer?.cancel();
    super.dispose();
  }

  void _startAutoScroll() {
    _autoScrollTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() { _currentBgIndex = (_currentBgIndex + 1) % _safeBackgroundOrder.length; });
        _preloadUpcomingBackgrounds();
      }
    });
  }

  List<int> _shuffledBackgroundOrder() {
    return List<int>.generate(kBackgroundImages.length, (index) => index)..shuffle(Random());
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
    await Future.wait(initialIndexes.map((index) async {
      await precacheImage(AssetImage(kBackgroundImages[index]), context);
      if (!mounted) return;
    }));
    if (!mounted) return;
    setState(() { _isLoading = false; });
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
      if (mounted) { setState(() { _calculateBirthday(); }); }
    });
  }

  void _calculateBirthday() {
    try {
      final now = DateTime.now();
      var birthday = DateTime(now.year, 12, 12);
      if (now.isAfter(birthday)) { birthday = DateTime(now.year + 1, 12, 12); }
      _timeUntilBirthday = birthday.difference(now);
    } catch (e) {
      _timeUntilBirthday = const Duration(days: 365);
    }
  }

  void _handleTitleTap() {
    setState(() { _titleTapCount++; });
    _titleTapTimer?.cancel();
    if (_titleTapCount == 1) {
      _titleTapTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && _titleTapCount < 9) { setState(() { _titleTapCount = 0; }); }
      });
    }
    if (_titleTapCount >= 9 && _titleTapCount < 12) {
      final remaining = 12 - _titleTapCount;
      _titleTapTimer = Timer(const Duration(seconds: 5), () {
        if (mounted && !_isEasterEggUnlocked) { setState(() { _titleTapCount = 0; }); }
      });
      _showTopSnackBar('还有$remaining次');
    }
    if (_titleTapCount >= 12) {
      setState(() { _isEasterEggUnlocked = true; _titleTapCount = 0; });
      _showTopSnackBar('彩蛋页面已解锁！');
    }
  }

  void _showTopSnackBar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 1),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(bottom: MediaQuery.of(context).size.height - 150, left: 20, right: 20),
    ));
  }

  Future<void> _pickFiles() async {
    try {
      FilePickerResult? result = await FilePicker.pickFiles(allowMultiple: true, withData: true);
      if (result != null && result.files.isNotEmpty) {
        final newFiles = result.files.map((file) {
          final ext = file.extension ?? 'bin';
          return UploadFile(name: file.name, extension: ext, bytes: file.bytes ?? Uint8List(0), fileSize: file.size);
        }).toList();
        setState(() { _uploadFiles.addAll(newFiles); });
        await _uploadAllFiles();
      }
    } catch (e) {
      debugPrint('File picker error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('选择文件失败: $e'), duration: const Duration(seconds: 3), behavior: SnackBarBehavior.floating));
      }
    }
  }

  Future<void> _uploadAllFiles() async {
    setState(() { _isUploading = true; });
    for (var file in _uploadFiles) {
      if (file.bytes.isEmpty) continue;
      setState(() { file.isUploading = true; file.progress = 0; file.error = null; file.url = null; });
      try {
        final url = await _uploadFile(file);
        setState(() { file.url = url; file.isCompleted = true; file.progress = 1; file.uploadDate = DateTime.now(); });
      } catch (e) {
        setState(() { file.error = e.toString(); });
      } finally {
        setState(() { file.isUploading = false; });
      }
    }
    setState(() { _isUploading = false; });
  }

  Future<String> _uploadFile(UploadFile file) async {
    final credUrl = Uri.parse('https://ci-exhibition.cloud.tencent.com/samples/createUploadKey?ext=${file.extension}&ciProcess=sensitive-content-recognition');
    final credResponse = await http.get(credUrl, headers: {
      'User-Agent': 'Mozilla/5.0 (Linux; Android 13; 22041216C Build/TP1A.220624.014) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.7204.179 Mobile Safari/537.36',
      'sec-ch-ua-platform': '"Android"', 'origin': 'https://cloud.tencent.com', 'x-requested-with': 'mark.via',
      'sec-fetch-site': 'same-site', 'sec-fetch-mode': 'cors', 'sec-fetch-dest': 'empty',
      'referer': 'https://cloud.tencent.com/act/pro/ciExhibition?from=15775&tab=contentReview&sub=pictureReview',
    });
    if (credResponse.statusCode != 200) { throw Exception('获取上传凭证失败: ${credResponse.statusCode}'); }
    final credData = json.decode(credResponse.body);
    if (credData['data'] == null || credData['data']['key'] == null || credData['data']['uploadAuthorization'] == null) {
      throw Exception('获取凭证失败：返回数据格式异常');
    }
    final uploadKey = credData['data']['key'];
    final uploadAuth = credData['data']['uploadAuthorization'];
    final uploadUrl = 'https://ci-h5-demo-1258125638.cos.ap-chengdu.myqcloud.com/$uploadKey';
    setState(() { file.progress = 0.3; });
    final uploadResponse = await http.put(Uri.parse(uploadUrl), headers: {
      'Authorization': uploadAuth, 'Content-Length': file.bytes.length.toString(),
      'User-Agent': 'Mozilla/5.0 (Linux; Android 13; 22041216C Build/TP1A.220624.014) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.7204.179 Mobile Safari/537.36',
      'sec-ch-ua-platform': '"Android"', 'origin': 'https://cloud.tencent.com', 'x-requested-with': 'mark.via',
      'sec-fetch-site': 'same-site', 'sec-fetch-mode': 'cors', 'sec-fetch-dest': 'empty',
      'referer': 'https://cloud.tencent.com/act/pro/ciExhibition?from=15775&tab=contentReview&sub=pictureReview',
    }, body: file.bytes);
    setState(() { file.progress = 0.9; });
    if (uploadResponse.statusCode != 200) { throw Exception('上传失败: ${uploadResponse.statusCode}'); }
    return uploadUrl;
  }

  void _navigateToPage(int page) {
    setState(() { _currentPage = page; _isSidebarOpen = false; });
  }

  bool get _isMobile => MediaQuery.of(context).size.width < 600;

  @override
  Widget build(BuildContext context) {
    final isNotHomePage = _currentPage > 0;

    return GlassPage(
      background: _buildBackgroundSlideshow(),
      child: Scaffold(
        extendBody: true,
        body: Stack(
          clipBehavior: Clip.none,
          children: [
            if (isNotHomePage)
              Positioned.fill(child: Container(color: Colors.black.withOpacity(0.3))),
            Positioned.fill(
              top: isNotHomePage ? 64 : 0,
              child: IndexedStack(
                index: _currentPage,
                children: [
                  HomePage(),
                  _qqbotToken != null
                      ? QQBotChatPage(
                          token: _qqbotToken,
                          userId: _qqbotUserId,
                          appId: _qqbotAppId,
                          backendUrl: _qqbotBackendUrl,
                          onLogout: () {
                            setState(() {
                              _qqbotToken = null;
                              _qqbotUserId = null;
                              _qqbotAppId = null;
                            });
                          },
                        )
                      : QQBotAuthPage(
                          onLoginSuccess: (token, userId, appId) {
                            setState(() {
                              _qqbotToken = token;
                              _qqbotUserId = userId;
                              _qqbotAppId = appId;
                            });
                          },
                        ),
                  TransferPage(uploadFiles: _uploadFiles, isUploading: _isUploading, onPickFiles: _pickFiles),
                  ProtobufPage(),
                  if (_isEasterEggUnlocked) WhenPage(timeUntilBirthday: _timeUntilBirthday),
                  RegisterPage(siteLinks: _siteLinks),
                  if (_isEasterEggUnlocked) AboutPage(),
                  ContactPage(),
                ],
              ),
            ),
            if (_isSidebarOpen)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () { setState(() { _isSidebarOpen = false; }); },
                  child: Container(color: Colors.transparent),
                ),
              ),
            _buildNavigationSidebar(),
            _buildHeader(),
            if (_isLoading) _buildPageLoader(),
          ],
        ),
        bottomNavigationBar: _isMobile ? _buildBottomBar() : null,
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
              child: Transform.scale(scale: 1.08 - progress * 0.03, alignment: alignment, child: child),
            );
          },
          child: Image.asset(imageUrl, fit: BoxFit.cover, width: double.infinity, height: double.infinity, alignment: alignment),
        ),
      ),
    );
  }

  Alignment _kenBurnsAlignment(int index) {
    const alignments = [Alignment.topCenter, Alignment.bottomCenter, Alignment.centerLeft, Alignment.centerRight];
    return alignments[index % alignments.length];
  }

  Offset _kenBurnsOffset(int index, double progress) {
    const distance = 18.0;
    final amount = (progress - 0.5) * distance;
    switch (index % 4) {
      case 0: return Offset(0, -amount);
      case 1: return Offset(0, amount);
      case 2: return Offset(-amount, 0);
      default: return Offset(amount, 0);
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
                const SizedBox(width: 42, height: 42, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3)),
                const SizedBox(height: 24),
                const Text('欢迎来到ZY沂沨の~', style: TextStyle(color: Colors.white, fontSize: 18)),
                const SizedBox(height: 8),
                const Text('注：首次加载需要点耐心~', style: TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _currentPageTitle() {
    if (_currentPage == 0) return '';
    final titles = _isEasterEggUnlocked
        ? ['QQBot Chat', '临时传输', 'Protobuf工具', '异想天开', '站点一览', '聊聊ZY沂沨', '联系ZY沂沨']
        : ['QQBot Chat', '临时传输', 'Protobuf工具', '站点一览', '联系ZY沂沨'];
    final index = _currentPage - 1;
    if (index < 0 || index >= titles.length) return '';
    return titles[index];
  }

  Widget _buildHeader() {
    final title = _currentPageTitle();
    return Positioned(
      top: 0, left: 0, right: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: GlassPanel(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () { setState(() { _isSidebarOpen = !_isSidebarOpen; }); },
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    GlassButton(
                      icon: Icon(_isSidebarOpen ? Icons.close_rounded : Icons.menu_rounded, size: 20),
                      onTap: () { setState(() { _isSidebarOpen = !_isSidebarOpen; }); },
                      width: 36, height: 36,
                    ),
                    if (title.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Container(width: 1, height: 20, color: Colors.white24),
                      const SizedBox(width: 10),
                      Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis)),
                    ],
                    if (title.isEmpty) const Spacer(),
                    Container(
                      width: 34, height: 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white54, width: 1.5),
                        image: const DecorationImage(image: AssetImage('assets/image/headimg_dl.jpg'), fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationSidebar() {
    return AnimatedPositioned(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      left: _isSidebarOpen ? 12 : -280,
      top: 0, bottom: 0, width: 260,
      child: SafeArea(
        child: GlassPanel(
          margin: const EdgeInsets.fromLTRB(0, 68, 0, 16),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: _handleTitleTap,
                child: const Text('ZY沂沨', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 6),
              Text('快速切换页面', style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12)),
              const SizedBox(height: 18),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.zero,
                  itemCount: _navItems.length,
                  itemBuilder: (context, index) {
                    final item = _navItems[index];
                    final isActive = _currentPage == item.page;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: GlassButton.custom(
                        onTap: () => _navigateToPage(item.page),
                        width: double.infinity,
                        height: 44,
                        shape: const LiquidRoundedSuperellipse(borderRadius: 14),
                        child: Row(
                          children: [
                            Icon(item.icon, size: 20, color: isActive ? Colors.white : Colors.white70),
                            const SizedBox(width: 12),
                            Expanded(child: Text(item.title, style: TextStyle(
                              color: Colors.white, fontSize: 14,
                              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                            ))),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final mobileItems = _navItems.take(4).toList();
    final safeIndex = _currentPage > mobileItems.length - 1 ? 0 : _currentPage;
    return GlassBottomBar(
      selectedIndex: safeIndex,
      onTabSelected: (i) => _navigateToPage(mobileItems[i].page),
      tabs: mobileItems.map((item) => GlassBottomBarTab(
        icon: Icon(item.icon),
      )).toList(),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String title;
  final int page;
  _NavItem({required this.icon, required this.title, required this.page});
}
