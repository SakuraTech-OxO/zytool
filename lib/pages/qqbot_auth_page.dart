import 'dart:convert';
import 'dart:io' if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:path_provider/path_provider.dart';

String _getDefaultBackendUrl() {
  if (kIsWeb) {
    return 'http://localhost:3000';
  }
  if (Platform.isAndroid) {
    // Android 模拟器使用 10.0.2.2 访问宿主机
    return 'http://10.0.2.2:3000';
  }
  return 'http://localhost:3000';
}

class QQBotAuthPage extends StatefulWidget {
  final Function(String token, int userId, String appId) onLoginSuccess;

  const QQBotAuthPage({super.key, required this.onLoginSuccess});

  @override
  State<QQBotAuthPage> createState() => _QQBotAuthPageState();
}

class _QQBotAuthPageState extends State<QQBotAuthPage> {
  bool _isLoginMode = true;
  bool _isLoading = false;

  final TextEditingController _appIdController = TextEditingController();
  final TextEditingController _secretController = TextEditingController();
  final TextEditingController _wsUrlController = TextEditingController();
  final TextEditingController _intentsController = TextEditingController();

  String _backendUrl = _getDefaultBackendUrl();

  @override
  void initState() {
    super.initState();
    _intentsController.text = '33554431';
    _loadSavedConfig();
  }

  @override
  void dispose() {
    _appIdController.dispose();
    _secretController.dispose();
    _wsUrlController.dispose();
    _intentsController.dispose();
    super.dispose();
  }

  Future<void> _loadSavedConfig() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/qqbot_backend_config.json');
      if (await file.exists()) {
        final content = await file.readAsString();
        final data = json.decode(content) as Map<String, dynamic>;
        setState(() {
          _backendUrl = data['backendUrl'] ?? 'http://localhost:3000';
          _appIdController.text = data['appId'] ?? '';
          _secretController.text = data['secret'] ?? '';
          _wsUrlController.text = data['wsUrl'] ?? '';
        });
      }
    } catch (e) {
      debugPrint('Load config error: $e');
    }
  }

  Future<void> _saveConfig() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/qqbot_backend_config.json');
      await file.writeAsString(json.encode({
        'backendUrl': _backendUrl,
        'appId': _appIdController.text.trim(),
        'secret': _secretController.text.trim(),
        'wsUrl': _wsUrlController.text.trim(),
      }));
    } catch (e) {
      debugPrint('Save config error: $e');
    }
  }

  Future<void> _handleSubmit() async {
    final appId = _appIdController.text.trim();
    final secret = _secretController.text.trim();

    if (appId.isEmpty || secret.isEmpty) {
      _showError('请填写 AppID 和 Secret');
      return;
    }

    if (!_isLoginMode) {
      final wsUrl = _wsUrlController.text.trim();
      if (wsUrl.isEmpty) {
        _showError('注册时需要填写 WebSocket 地址');
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      if (_isLoginMode) {
        await _login(appId, secret);
      } else {
        await _register(appId, secret);
      }
    } catch (e) {
      _showError('操作失败: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _login(String appId, String secret) async {
    final response = await http.post(
      Uri.parse('$_backendUrl/api/login'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'appId': appId, 'secret': secret}),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        await _saveConfig();
        widget.onLoginSuccess(
          data['data']['token'],
          data['data']['userId'],
          data['data']['appId'],
        );
      } else {
        _showError(data['error'] ?? '登录失败');
      }
    } else {
      final data = json.decode(response.body);
      _showError(data['error'] ?? '登录失败');
    }
  }

  Future<void> _register(String appId, String secret) async {
    final wsUrl = _wsUrlController.text.trim();
    final intents = int.tryParse(_intentsController.text.trim()) ?? 33554431;

    final response = await http.post(
      Uri.parse('$_backendUrl/api/register'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'appId': appId,
        'secret': secret,
        'wsUrl': wsUrl,
        'intents': intents,
      }),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['success'] == true) {
        await _saveConfig();
        widget.onLoginSuccess(
          data['data']['token'],
          data['data']['userId'],
          data['data']['appId'],
        );
      } else {
        _showError(data['error'] ?? '注册失败');
      }
    } else {
      final data = json.decode(response.body);
      _showError(data['error'] ?? '注册失败');
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red.withOpacity(0.8)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassPage(
      background: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0C29),
              Color(0xFF302B63),
              Color(0xFF24243E),
            ],
          ),
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: GlassContainer(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.smart_toy,
                    size: 64,
                    color: Color(0xFF5677FC),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isLoginMode ? '登录 QQBot' : '注册 QQBot',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isLoginMode ? '使用 AppID 和 Secret 登录' : '配置您的 QQBot 连接',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 32),
                  GlassTextField(
                    controller: _appIdController,
                    placeholder: 'AppID',
                    prefixIcon: const Icon(Icons.key, color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  GlassTextField(
                    controller: _secretController,
                    placeholder: 'Secret',
                    obscureText: true,
                    prefixIcon: const Icon(Icons.lock, color: Colors.white70),
                  ),
                  if (!_isLoginMode) ...[
                    const SizedBox(height: 16),
                    GlassTextField(
                      controller: _wsUrlController,
                      placeholder: 'WebSocket 地址 (wss://...)',
                      prefixIcon: const Icon(Icons.link, color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    GlassTextField(
                      controller: _intentsController,
                      placeholder: 'Intents (默认: 33554431)',
                      prefixIcon: const Icon(Icons.tune, color: Colors.white70),
                      keyboardType: TextInputType.number,
                    ),
                  ],
                  const SizedBox(height: 24),
                  // 登录/注册按钮 - 圆角长方形
                  GestureDetector(
                    onTap: _isLoading ? null : () => _handleSubmit(),
                    child: Container(
                      width: double.infinity,
                      height: 52,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF5677FC), Color(0xFF7B68EE)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF5677FC).withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: _isLoading
                            ? const SizedBox(
                                height: 22,
                                width: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                _isLoginMode ? '登 录' : '注 册',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 2,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _isLoginMode = !_isLoginMode;
                      });
                    },
                    child: Text(
                      _isLoginMode ? '没有账号？点击注册' : '已有账号？点击登录',
                      style: const TextStyle(
                        color: Color(0xFF5677FC),
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GlassContainer(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '后端地址',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        const SizedBox(height: 4),
                        GlassTextField(
                          controller: TextEditingController(text: _backendUrl),
                          placeholder: 'http://localhost:3000',
                          prefixIcon: const Icon(Icons.dns, color: Colors.white70),
                          onChanged: (value) {
                            _backendUrl = value;
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
