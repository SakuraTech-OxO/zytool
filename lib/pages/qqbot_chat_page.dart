import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_math_fork/flutter_math.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../main.dart' show kFallbackHead;

class _ContentPart {
  final String content;
  final bool isLatex;
  
  _ContentPart.plain(this.content) : isLatex = false;
  _ContentPart.math(this.content) : isLatex = true;
}

class _MessageAttachment {
  final String? url;
  final String? contentType;
  final String? filename;
  final int? width;
  final int? height;

  _MessageAttachment({
    this.url,
    this.contentType,
    this.filename,
    this.width,
    this.height,
  });

  factory _MessageAttachment.fromJson(Map<String, dynamic> json) {
    return _MessageAttachment(
      url: json['url'] as String?,
      contentType: json['content_type'] as String?,
      filename: json['filename'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
    );
  }
}

class _BotMessage {
  final bool isIncoming;
  final String type;
  final String content;
  final String? authorName;
  final String? authorId;
  final String? authorAvatar;
  final bool authorBot;
  final String? conversationId;
  final DateTime timestamp;
  final List<_MessageAttachment> attachments;
  final String? faceText;
  final String? messageId;
  final String? referenceMessageId;
  final String? referenceContent;
  final List<_MessageAttachment> referenceAttachments;

  _BotMessage({
    required this.isIncoming,
    required this.type,
    required this.content,
    this.authorName,
    this.authorId,
    this.authorAvatar,
    this.authorBot = false,
    this.conversationId,
    DateTime? timestamp,
    this.attachments = const [],
    this.faceText,
    this.messageId,
    this.referenceMessageId,
    this.referenceContent,
    this.referenceAttachments = const [],
  }) : timestamp = timestamp ?? DateTime.now();

  factory _BotMessage.fromJson(Map<String, dynamic> json) {
    final attachments = (json['attachments'] as List<dynamic>?)
        ?.map((a) => _MessageAttachment.fromJson(a as Map<String, dynamic>))
        .toList() ?? [];

    return _BotMessage(
      isIncoming: json['is_incoming'] == 1,
      type: json['event_type'] as String? ?? '',
      content: json['content'] as String? ?? '',
      authorName: json['author_name'] as String?,
      authorId: json['author_id'] as String?,
      authorAvatar: json['author_avatar'] as String?,
      authorBot: json['author_bot'] == 1 || json['author_bot'] == true,
      conversationId: json['conversation_id'] as String?,
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ?? DateTime.now(),
      attachments: attachments,
      faceText: json['face_text'] as String?,
      messageId: json['message_id'] as String?,
      referenceMessageId: json['reference_message_id'] as String?,
      referenceContent: json['reference_content'] as String?,
    );
  }
}

class _ConversationInfo {
  final String id;
  final String name;
  final String type;
  final String? customName;
  final String? customId;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;

  _ConversationInfo({
    required this.id,
    required this.name,
    required this.type,
    this.customName,
    this.customId,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
  });

  String get displayName => customName ?? name;
  
  String get displayId => customId ?? id;
  
  String? get displayAvatar {
    // 根据类型生成头像链接
    if (type == 'group') {
      return 'https://p.qlogo.cn/gh/$displayId/$displayId/0';
    } else {
      return 'https://q1.qlogo.cn/g?b=qq&s=0&nk=$displayId';
    }
  }

  factory _ConversationInfo.fromJson(Map<String, dynamic> json) {
    return _ConversationInfo(
      id: json['conversation_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? 'private',
      customName: json['custom_name'] as String?,
      customId: json['custom_id'] as String?,
      lastMessage: json['last_message'] as String?,
      lastMessageTime: DateTime.tryParse(json['last_message_time'] as String? ?? ''),
      unreadCount: json['unread_count'] as int? ?? 0,
    );
  }

  _ConversationInfo copyWith({
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    String? customName,
    String? customId,
  }) {
    return _ConversationInfo(
      id: id,
      name: name,
      type: type,
      customName: customName ?? this.customName,
      customId: customId ?? this.customId,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
    );
  }
}

class QQBotChatPage extends StatefulWidget {
  final String? token;
  final int? userId;
  final String? appId;
  final String? backendUrl;
  final VoidCallback? onLogout;

  const QQBotChatPage({
    super.key,
    this.token,
    this.userId,
    this.appId,
    this.backendUrl = 'http://localhost:3000',
    this.onLogout,
  });

  @override
  State<QQBotChatPage> createState() => _QQBotChatPageState();
}

class _QQBotChatPageState extends State<QQBotChatPage> {
  WebSocketChannel? _wsChannel;
  bool _isConnected = false;
  bool _isConnecting = false;
  String _connectionStatus = '未连接';
  Timer? _pingTimer;

  final Map<String, List<_BotMessage>> _conversationMessages = {};
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<_ConversationInfo> _conversations = [];
  String? _activeConversationId;
  bool _isLoadingHistory = false;
  String? _selfAvatarUrl;
  String? _selfNickname;
  bool _showScrollToBottom = false;
  _BotMessage? _replyToMessage;

  @override
  void initState() {
    super.initState();
    _connectWebSocket();
    _loadConversations();
    _loadProfile();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _disconnectWebSocket();
    _messageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      final isAtBottom = (maxScroll - currentScroll) < 100;
      if (isAtBottom != !_showScrollToBottom) {
        setState(() {
          _showScrollToBottom = !isAtBottom;
        });
      }
    }
  }

  String get _apiBaseUrl => widget.backendUrl ?? 'http://localhost:3000';
  String get _wsBaseUrl => _apiBaseUrl.replaceFirst('http', 'ws');

  Map<String, String> get _authHeaders => {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer ${widget.token}',
  };

  void _connectWebSocket() {
    if (widget.token == null || widget.userId == null) return;

    setState(() {
      _isConnecting = true;
      _connectionStatus = '连接中...';
    });

    try {
      _wsChannel = WebSocketChannel.connect(
        Uri.parse('$_wsBaseUrl/ws'),
      );

      _wsChannel!.stream.listen(
        (data) => _handleWebSocketMessage(data as String),
        onError: (error) {
          debugPrint('WS error: $error');
          _setDisconnected();
        },
        onDone: () {
          _setDisconnected();
          // Auto reconnect after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted && !_isConnected) {
              _connectWebSocket();
            }
          });
        },
      );

      // Send auth message after connection
      Future.delayed(const Duration(milliseconds: 500), () {
        if (_wsChannel != null) {
          _wsChannel!.sink.add(json.encode({
            'type': 'auth',
            'data': {'userId': widget.userId}
          }));
        }
      });

      // Start ping timer
      _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        if (_wsChannel != null && _isConnected) {
          _wsChannel!.sink.add(json.encode({'type': 'ping'}));
        }
      });
    } catch (e) {
      setState(() {
        _isConnecting = false;
        _connectionStatus = '连接失败';
      });
    }
  }

  void _disconnectWebSocket() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _wsChannel?.sink.close();
    _wsChannel = null;
  }

  void _setDisconnected() {
    if (mounted) {
      setState(() {
        _isConnected = false;
        _isConnecting = false;
        _connectionStatus = '未连接';
      });
    }
  }

  void _handleWebSocketMessage(String data) {
    try {
      final message = json.decode(data) as Map<String, dynamic>;
      final type = message['type'] as String?;

      switch (type) {
        case 'connected':
          debugPrint('WS connected: ${message['data']}');
          break;
        case 'auth_success':
          setState(() {
            _isConnected = true;
            _isConnecting = false;
            _connectionStatus = '已连接';
          });
          break;
        case 'pong':
          // Heartbeat response
          break;
        case 'new_message':
          _handleNewMessage(message['data'] as Map<String, dynamic>);
          break;
      }
    } catch (e) {
      debugPrint('Parse WS message error: $e');
    }
  }

  void _handleNewMessage(Map<String, dynamic> data) {
    final eventType = data['eventType'] as String? ?? '';
    var content = data['content'] as String? ?? '';
    final authorName = data['authorName'] as String? ?? '';
    final authorId = data['authorId'] as String? ?? '';
    final authorAvatar = data['authorAvatar'] as String? ?? '';
    final authorBot = data['authorBot'] as bool? ?? false;
    final conversationId = data['conversationId'] as String? ?? '';
    final isIncoming = data['isIncoming'] as bool? ?? true;
    final faceText = data['faceText'] as String?;
    final messageId = data['messageId'] as String?;
    
    // 获取引用消息信息（从后端返回）
    final referenceMessageId = data['referenceMessageId'] as String?;
    final referenceContent = data['referenceContent'] as String?;
    final referenceAuthor = data['referenceAuthor'] as String?;
    final referenceAttachments = (data['referenceAttachments'] as List<dynamic>?)
        ?.map((a) => _MessageAttachment.fromJson(a as Map<String, dynamic>))
        .toList() ?? [];
    
    // 过滤掉引用消息标志内容（REFIDX...）
    content = content.replaceAll(RegExp(r'REFIDX_[A-Za-z0-9+/=]+'), '').trim();
    
    // 过滤掉表情标签 <faceType=...,faceId="...",ext="...">
    content = content.replaceAll(RegExp(r'<faceType=\d+,faceId="[^"]*",ext="[^"]*">'), '').trim();
    
    // 过滤掉 @标签 <@xxx>
    content = content.replaceAll(RegExp(r'<@[A-F0-9]+>'), '').trim();
    
    // 清理多余的空白和换行
    content = content.replaceAll(RegExp(r'\n\s*\n'), '\n').trim();

    final attachments = (data['attachments'] as List<dynamic>?)
        ?.map((a) => _MessageAttachment.fromJson(a as Map<String, dynamic>))
        .toList() ?? [];

    if (conversationId.isEmpty) return;

    // 如果内容为空且有附件，显示为 [图片] 或 [表情]
    String displayContent = content;
    if (displayContent.isEmpty && attachments.isNotEmpty) {
      final firstAtt = attachments.first;
      debugPrint('[Message] Attachment contentType: ${firstAtt.contentType}');
      if (firstAtt.contentType?.contains('image') == true) {
        displayContent = '[图片]';
      } else if (firstAtt.contentType?.contains('video') == true) {
        displayContent = '[视频]';
      } else {
        displayContent = '[文件]';
      }
    }

    final msg = _BotMessage(
      isIncoming: isIncoming,
      type: eventType,
      content: displayContent,
      authorName: authorName,
      authorId: authorId,
      authorAvatar: authorAvatar,
      authorBot: authorBot,
      conversationId: conversationId,
      attachments: attachments,
      faceText: faceText,
      messageId: messageId,
      referenceMessageId: referenceMessageId,
      referenceContent: referenceContent,
      referenceAttachments: referenceAttachments,
    );

    if (mounted) {
      setState(() {
        _conversationMessages.putIfAbsent(conversationId, () => []);
        _conversationMessages[conversationId]!.add(msg);

        final existIndex = _conversations.indexWhere((c) => c.id == conversationId);
        if (existIndex >= 0) {
          _conversations[existIndex] = _conversations[existIndex].copyWith(
            lastMessage: content,
            lastMessageTime: msg.timestamp,
            unreadCount: _activeConversationId == conversationId
                ? 0
                : _conversations[existIndex].unreadCount + 1,
          );
          final conv = _conversations.removeAt(existIndex);
          _conversations.insert(0, conv);
        } else {
          _conversations.insert(0, _ConversationInfo(
            id: conversationId,
            name: authorName,
            type: eventType.contains('GROUP') ? 'group' : 'private',
            lastMessage: content,
            lastMessageTime: msg.timestamp,
            unreadCount: _activeConversationId == conversationId ? 0 : 1,
          ));
        }
      });

      if (_activeConversationId == conversationId) {
        _scrollToBottom();
      }
    }
  }

  Future<void> _loadProfile() async {
    if (widget.token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/profile'),
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final botInfo = data['data']['botInfo'];
          if (botInfo != null && mounted) {
            final appId = data['data']['appId'] ?? widget.appId;
            final botId = botInfo['id'];
            final nickname = botInfo['username'] as String?;
            String? avatarUrl = botInfo['avatar'];
            
            if (avatarUrl == null || avatarUrl.isEmpty) {
              if (botId != null && appId != null) {
                avatarUrl = 'https://q.qlogo.cn/qqapp/$appId/$botId/0';
              }
            }
            
            setState(() {
              _selfAvatarUrl = avatarUrl;
              _selfNickname = nickname;
            });
            debugPrint('[Profile] Bot nickname: $_selfNickname, avatar: $_selfAvatarUrl');
          }
        }
      }
    } catch (e) {
      debugPrint('Load profile error: $e');
    }
  }

  Future<void> _loadConversations() async {
    if (widget.token == null) return;

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/conversations'),
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final conversations = (data['data'] as List<dynamic>)
              .map((c) => _ConversationInfo.fromJson(c as Map<String, dynamic>))
              .toList();

          setState(() {
            _conversations = conversations;
          });
        }
      }
    } catch (e) {
      debugPrint('Load conversations error: $e');
    }
  }

  Future<void> _loadMessages(String conversationId) async {
    if (widget.token == null) return;

    setState(() => _isLoadingHistory = true);

    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/api/messages/$conversationId?limit=100'),
        headers: _authHeaders,
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          final messages = (data['data'] as List<dynamic>)
              .map((m) => _BotMessage.fromJson(m as Map<String, dynamic>))
              .toList();

          setState(() {
            _conversationMessages[conversationId] = messages;
            _isLoadingHistory = false;
          });

          _scrollToBottom();
        }
      }
    } catch (e) {
      debugPrint('Load messages error: $e');
      setState(() => _isLoadingHistory = false);
    }
  }

  Future<void> _sendMessage({String type = 'text'}) async {
    final content = _messageController.text.trim();
    if (content.isEmpty || _activeConversationId == null || widget.token == null) return;
    _messageController.clear();

    // Determine conversation type
    final conv = _conversations.firstWhere(
      (c) => c.id == _activeConversationId,
      orElse: () => _ConversationInfo(id: '', name: '', type: 'private'),
    );
    final convType = conv.type == 'group' ? 'group' : 'private';

    // Add message to local UI immediately
    final msg = _BotMessage(
      isIncoming: false,
      type: 'OUTGOING',
      content: content,
      authorName: '我',
      referenceMessageId: _replyToMessage?.messageId,
      referenceContent: _replyToMessage?.content,
    );

    if (mounted) {
      setState(() {
        _conversationMessages.putIfAbsent(_activeConversationId!, () => []);
        _conversationMessages[_activeConversationId]!.add(msg);

        final idx = _conversations.indexWhere((c) => c.id == _activeConversationId);
        if (idx >= 0) {
          _conversations[idx] = _conversations[idx].copyWith(
            lastMessage: content,
            lastMessageTime: msg.timestamp,
          );
          final conv = _conversations.removeAt(idx);
          _conversations.insert(0, conv);
        }
      });
      _scrollToBottom();
    }

    // Send to backend API
    try {
      String endpoint;
      Map<String, dynamic> body;

      // 获取引用消息 ID（只使用 referenceMessageId，即从 msg_idx 解析的 REFIDX_...）
      final referenceId = _replyToMessage?.referenceMessageId;
      final hasReference = referenceId != null && referenceId.isNotEmpty;

      debugPrint('[Send] Reply message referenceMessageId: ${_replyToMessage?.referenceMessageId}');
      debugPrint('[Send] Using referenceId: $referenceId');

      if (hasReference && type == 'markdown') {
        // Markdown 模式发送引用消息：使用引用块格式
        final referenceContent = _replyToMessage?.content ?? '';
        final markdownContent = '> $referenceContent\n\n$content';
        
        endpoint = '$_apiBaseUrl/api/messages/markdown';
        body = {
          'conversationId': _activeConversationId,
          'markdown': markdownContent,
          'type': convType,
        };
      } else if (hasReference) {
        // 文本模式发送引用消息
        endpoint = '$_apiBaseUrl/api/messages/send';
        body = {
          'conversationId': _activeConversationId,
          'content': content,
          'type': convType,
          'msgType': 0,
          'message_reference': {
            'message_id': referenceId,
          },
        };
        debugPrint('[Send] Adding reference to message: $referenceId');
      } else if (type == 'markdown') {
        // 无引用的 Markdown 消息
        endpoint = '$_apiBaseUrl/api/messages/markdown';
        body = {
          'conversationId': _activeConversationId,
          'markdown': content,
          'type': convType,
        };
      } else {
        // 普通文本消息
        endpoint = '$_apiBaseUrl/api/messages/send';
        body = {
          'conversationId': _activeConversationId,
          'content': content,
          'type': convType,
          'msgType': 0,
        };
      }
      
      // 清除引用状态
      setState(() {
        _replyToMessage = null;
      });

      final response = await http.post(
        Uri.parse(endpoint),
        headers: _authHeaders,
        body: json.encode(body),
      );

      if (response.statusCode != 200) {
        debugPrint('Send message failed: ${response.body}');
      }
    } catch (e) {
      debugPrint('Send message error: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _openConversation(String conversationId) {
    setState(() {
      _activeConversationId = conversationId;
      final idx = _conversations.indexWhere((c) => c.id == conversationId);
      if (idx >= 0) {
        _conversations[idx] = _conversations[idx].copyWith(unreadCount: 0);
      }
    });

    // Load messages if not cached
    if (!_conversationMessages.containsKey(conversationId) ||
        _conversationMessages[conversationId]!.isEmpty) {
      _loadMessages(conversationId);
    } else {
      _scrollToBottom();
    }
  }

  void _closeConversation() {
    setState(() {
      _activeConversationId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent,
      child: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _activeConversationId != null
                  ? _buildChatView()
                  : _buildConversationList(),
            ),
            if (_activeConversationId != null) _buildInputArea(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final activeConv = _activeConversationId != null
        ? _conversations.firstWhere(
            (c) => c.id == _activeConversationId,
            orElse: () => _ConversationInfo(id: '', name: '', type: ''),
          )
        : null;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          if (_activeConversationId != null)
            GestureDetector(
              onTap: _closeConversation,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
              ),
            )
          else
            _buildSelfAvatar(),
          const SizedBox(width: 10),
          if (_activeConversationId != null)
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeConv?.name ?? '',
                    style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    _isConnected ? '在线' : '离线',
                    style: TextStyle(
                      color: _isConnected ? Colors.green : Colors.white30,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selfNickname ?? 'QQBot Chat',
                  style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
                ),
                if (_selfNickname != null && widget.appId != null)
                  Text(
                    'AppID: ${widget.appId}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
              ],
            ),
            const Spacer(),
          ],
          if (_activeConversationId == null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _isConnected ? Colors.green : (_isConnecting ? Colors.orange : Colors.red),
              ),
            ),
            const SizedBox(width: 6),
            Text(_connectionStatus, style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(width: 12),
            if (widget.onLogout != null)
              GestureDetector(
                onTap: widget.onLogout,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('退出', style: TextStyle(color: Colors.white, fontSize: 13)),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Widget _buildSelfAvatar() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
        image: _selfAvatarUrl != null && _selfAvatarUrl!.isNotEmpty
            ? DecorationImage(
                image: NetworkImage(_selfAvatarUrl!),
                fit: BoxFit.cover,
                onError: (exception, stackTrace) {
                  debugPrint('[Avatar] Load error: $exception');
                },
              )
            : const DecorationImage(
                image: AssetImage(kFallbackHead),
                fit: BoxFit.cover,
              ),
      ),
    );
  }

  Widget _buildConversationList() {
    if (_conversations.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isConnected ? Icons.chat_bubble_outline : Icons.cloud_off,
              color: Colors.white24,
              size: 64,
            ),
            const SizedBox(height: 20),
            Text(
              _isConnected ? '暂无消息' : '未连接',
              style: const TextStyle(color: Colors.white30, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              _isConnected ? '等待接收消息...' : '正在连接中...',
              style: const TextStyle(color: Colors.white24, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _conversations.length,
      itemBuilder: (context, index) {
        final conv = _conversations[index];
        return _buildConversationItem(conv);
      },
    );
  }

  Widget _buildConversationItem(_ConversationInfo conv) {
    final timeStr = conv.lastMessageTime != null
        ? '${conv.lastMessageTime!.hour.toString().padLeft(2, '0')}:${conv.lastMessageTime!.minute.toString().padLeft(2, '0')}'
        : '';

    return GestureDetector(
      onTap: () => _openConversation(conv.id),
      onLongPress: () => _showConversationSettings(conv),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(color: Colors.white.withOpacity(0.05)),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF1E2A4A),
                image: conv.displayAvatar != null
                    ? DecorationImage(
                        image: NetworkImage(conv.displayAvatar!),
                        fit: BoxFit.cover,
                        onError: (exception, stackTrace) {
                          debugPrint('[Avatar] Load error: $exception');
                        },
                      )
                    : null,
              ),
              child: conv.displayAvatar == null
                  ? Icon(
                      conv.type == 'group' ? Icons.group : Icons.person,
                      color: conv.type == 'group' ? const Color(0xFF5677FC) : const Color(0xFF4ECDC4),
                      size: 24,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (timeStr.isNotEmpty)
                        Text(
                          timeStr,
                          style: const TextStyle(color: Colors.white24, fontSize: 12),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conv.lastMessage ?? '',
                          style: const TextStyle(color: Colors.white38, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      if (conv.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF5677FC),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${conv.unreadCount}',
                            style: const TextStyle(color: Colors.white, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConversationSettings(_ConversationInfo conv) {
    final nameController = TextEditingController(text: conv.customName ?? '');
    final idController = TextEditingController(text: conv.customId ?? '');
    
    // 生成提示文本
    String idHint = '';
    if (conv.type == 'group') {
      idHint = '输入群号，留空使用默认: ${conv.id}';
    } else {
      idHint = '输入QQ号，留空使用默认: ${conv.id}';
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E2A4A),
        title: Text('设置 ${conv.displayName}', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: '自定义昵称',
                labelStyle: TextStyle(color: Colors.white70),
                hintText: '留空使用默认昵称',
                hintStyle: TextStyle(color: Colors.white30),
                enabledBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF5677FC)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: idController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: conv.type == 'group' ? '群号' : 'QQ号',
                labelStyle: const TextStyle(color: Colors.white70),
                hintText: idHint,
                hintStyle: const TextStyle(color: Colors.white30),
                enabledBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Colors.white24),
                ),
                focusedBorder: const UnderlineInputBorder(
                  borderSide: BorderSide(color: Color(0xFF5677FC)),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '当前ID: ${conv.id}',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateConversationCustomInfo(conv.id, nameController.text.trim(), idController.text.trim());
            },
            child: const Text('保存', style: TextStyle(color: Color(0xFF5677FC))),
          ),
        ],
      ),
    );
  }

  Future<void> _updateConversationCustomInfo(String conversationId, String customName, String customId) async {
    try {
      final response = await http.put(
        Uri.parse('$_apiBaseUrl/api/conversations/$conversationId/custom'),
        headers: _authHeaders,
        body: json.encode({
          'customName': customName.isEmpty ? null : customName,
          'customId': customId.isEmpty ? null : customId,
        }),
      );

      if (response.statusCode == 200) {
        // Update local state
        setState(() {
          final idx = _conversations.indexWhere((c) => c.id == conversationId);
          if (idx >= 0) {
            _conversations[idx] = _conversations[idx].copyWith(
              customName: customName.isEmpty ? null : customName,
              customId: customId.isEmpty ? null : customId,
            );
          }
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('设置已保存'), duration: Duration(seconds: 1)),
          );
        }
      }
    } catch (e) {
      debugPrint('Update custom info error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('保存失败: $e')),
        );
      }
    }
  }

  Widget _buildChatView() {
    final messages = _conversationMessages[_activeConversationId] ?? [];

    if (_isLoadingHistory) {
      return const Center(
        child: CircularProgressIndicator(color: Color(0xFF5677FC)),
      );
    }

    if (messages.isEmpty) {
      return const Center(
        child: Text('暂无消息', style: TextStyle(color: Colors.white24, fontSize: 14)),
      );
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          itemCount: messages.length,
          itemBuilder: (context, index) => _buildMessageItem(messages[index]),
        ),
        if (_showScrollToBottom)
          Positioned(
            right: 16,
            bottom: 16,
            child: GestureDetector(
              onTap: _scrollToBottom,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF5677FC).withOpacity(0.8),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildMessageItem(_BotMessage msg) {
    final isIncoming = msg.isIncoming;
    final timeStr = '${msg.timestamp.hour.toString().padLeft(2, '0')}:${msg.timestamp.minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onSecondaryTapUp: (details) => _showMessageContextMenu(msg, details.globalPosition),
      onLongPressStart: (details) => _showMessageContextMenu(msg, details.globalPosition),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: isIncoming
            ? _buildIncomingMessage(msg, timeStr)
            : _buildOutgoingMessage(msg, timeStr),
      ),
    );
  }

  void _showMessageContextMenu(_BotMessage msg, Offset position) {
    final RenderBox overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    
    showMenu(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        overlay.size.width - position.dx,
        overlay.size.height - position.dy,
      ),
      color: const Color(0xFF1E2A4A),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      items: [
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.copy, color: Colors.white70, size: 18),
              const SizedBox(width: 12),
              const Text('复制内容', style: TextStyle(color: Colors.white)),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              Clipboard.setData(ClipboardData(text: msg.content));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('已复制到剪贴板'), duration: Duration(seconds: 1)),
              );
            });
          },
        ),
        PopupMenuItem(
          child: Row(
            children: [
              const Icon(Icons.reply, color: Colors.white70, size: 18),
              const SizedBox(width: 12),
              const Text('引用回复', style: TextStyle(color: Colors.white)),
            ],
          ),
          onTap: () {
            Future.delayed(const Duration(milliseconds: 100), () {
              setState(() {
                _replyToMessage = msg;
              });
              _messageController.text = '';
              FocusScope.of(context).requestFocus();
            });
          },
        ),
        if (msg.attachments.isNotEmpty && msg.attachments.any((a) => a.url?.isNotEmpty == true))
          PopupMenuItem(
            child: Row(
              children: [
                const Icon(Icons.open_in_new, color: Colors.white70, size: 18),
                const SizedBox(width: 12),
                const Text('打开链接', style: TextStyle(color: Colors.white)),
              ],
            ),
            onTap: () {
              final url = msg.attachments.first.url;
              if (url != null && url.isNotEmpty) {
                // 可以使用 url_launcher 打开链接
                debugPrint('[Open] URL: $url');
              }
            },
          ),
      ],
    );
  }

  Widget _buildIncomingMessage(_BotMessage msg, String timeStr) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFF1E2A4A),
            image: msg.authorAvatar != null && msg.authorAvatar!.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(msg.authorAvatar!),
                    fit: BoxFit.cover,
                    onError: (exception, stackTrace) {
                      debugPrint('[Message] Avatar load error: $exception');
                    },
                  )
                : null,
          ),
          child: msg.authorAvatar == null || msg.authorAvatar!.isEmpty
              ? const Icon(Icons.person, color: Colors.white54, size: 20)
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                msg.authorName ?? '未知用户',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                padding: msg.attachments.isNotEmpty
                    ? const EdgeInsets.all(6)
                    : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2A4A),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (msg.referenceMessageId != null)
                      _buildReferenceQuote(msg.referenceMessageId!, msg.referenceContent, referenceAttachments: msg.referenceAttachments),
                    if (msg.faceText != null)
                      Text(
                        '[${msg.faceText}]',
                        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
                      )
                    else if (msg.content.isNotEmpty && msg.content != '[图片]' && msg.content != '[表情]')
                      _buildMessageContent(msg.content, isBot: msg.authorBot),
                    ...msg.attachments.where((a) => a.contentType?.startsWith('image/') == true).map((att) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: GestureDetector(
                          onTap: () => _openMediaPreview(att.url!, 'image'),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240, maxHeight: 280),
                              child: Image.network(
                                att.url!,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    padding: const EdgeInsets.all(16),
                                    child: const Icon(Icons.broken_image, color: Colors.white30, size: 40),
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    ...msg.attachments.where((a) => a.contentType?.startsWith('video/') == true).map((att) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: GestureDetector(
                          onTap: () => _openMediaPreview(att.url!, 'video'),
                          child: Container(
                            width: 240,
                            height: 160,
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                const Icon(Icons.videocam, color: Colors.white54, size: 48),
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  right: 8,
                                  child: Text(
                                    att.filename ?? '视频',
                                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
              const SizedBox(height: 2),
              Text(
                timeStr,
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildReferenceQuote(String referenceId, String? referenceContent, {List<_MessageAttachment>? referenceAttachments}) {
    if ((referenceContent == null || referenceContent.isEmpty) && 
        (referenceAttachments == null || referenceAttachments.isEmpty)) {
      return const SizedBox.shrink();
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(color: const Color(0xFF5677FC), width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (referenceContent != null && referenceContent.isNotEmpty)
            Text(
              referenceContent,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          if (referenceAttachments != null)
            ...referenceAttachments.where((a) => a.contentType?.contains('image') == true).map((att) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 120, maxHeight: 120),
                    child: Image.network(
                      att.url!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox(
                          width: 60,
                          height: 60,
                          child: Icon(Icons.broken_image, color: Colors.white30, size: 20),
                        );
                      },
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  void _openMediaPreview(String url, String type) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _MediaPreviewPage(url: url, type: type),
      ),
    );
  }

  Widget _buildMessageContent(String content, {bool isBot = false}) {
    // 只有 bot 消息才进行 markdown 渲染
    if (!isBot) {
      return SelectableText(
        content,
        style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        toolbarOptions: const ToolbarOptions(
          copy: true,
          selectAll: true,
        ),
      );
    }
    
    // 检查是否包含 latex 语法
    final hasLatex = content.contains(r'$$') || 
                     content.contains(r'\(') || 
                     content.contains(r'\[') ||
                     (content.contains(r'$') && !content.contains(r'$$'));
    
    // 检查是否包含 markdown 语法
    final hasMarkdown = content.contains('#') || 
                        content.contains('*') || 
                        content.contains('`') ||
                        content.contains('[') ||
                        content.contains('>') ||
                        content.contains('-') ||
                        content.contains('```');
    
    if (hasLatex) {
      // 处理 latex 内容
      return _buildLatexContent(content);
    }
    
    if (hasMarkdown) {
      return MarkdownBody(
        data: content,
        styleSheet: MarkdownStyleSheet(
          p: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
          h1: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
          h2: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          h3: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          code: TextStyle(
            color: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.1),
            fontSize: 13,
            fontFamily: 'monospace',
          ),
          codeblockDecoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          blockquote: const TextStyle(color: Colors.white70, fontSize: 14),
          listBullet: const TextStyle(color: Colors.white, fontSize: 14),
          a: const TextStyle(color: Color(0xFF5677FC)),
        ),
      );
    }
    
    return Text(
      content,
      style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
    );
  }

  Widget _buildLatexContent(String content) {
    // 分割文本和 latex 公式
    final parts = <_ContentPart>[];
    final regex = RegExp(r'(\$\$[\s\S]*?\$\$|\$[^\$]+?\$|\\\[[\s\S]*?\\\]|\\\([\s\S]*?\\\))');
    int lastEnd = 0;
    
    for (final match in regex.allMatches(content)) {
      if (match.start > lastEnd) {
        parts.add(_ContentPart.plain(content.substring(lastEnd, match.start)));
      }
      parts.add(_ContentPart.math(match.group(0)!));
      lastEnd = match.end;
    }
    
    if (lastEnd < content.length) {
      parts.add(_ContentPart.plain(content.substring(lastEnd)));
    }
    
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      children: parts.map((part) {
        if (part.isLatex) {
          return _buildLatexWidget(part.content);
        }
        return Text(
          part.content,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        );
      }).toList(),
    );
  }

  Widget _buildLatexWidget(String latex) {
    // 清理 latex 公式
    String cleaned = latex;
    if (cleaned.startsWith(r'$$') && cleaned.endsWith(r'$$')) {
      cleaned = cleaned.substring(2, cleaned.length - 2);
    } else if (cleaned.startsWith(r'$') && cleaned.endsWith(r'$')) {
      cleaned = cleaned.substring(1, cleaned.length - 1);
    } else if (cleaned.startsWith(r'\[') && cleaned.endsWith(r'\]')) {
      cleaned = cleaned.substring(2, cleaned.length - 2);
    } else if (cleaned.startsWith(r'\(') && cleaned.endsWith(r'\)')) {
      cleaned = cleaned.substring(2, cleaned.length - 2);
    }
    
    try {
      return Math.tex(
        cleaned,
        textStyle: const TextStyle(color: Colors.white, fontSize: 14),
      );
    } catch (e) {
      return Text(
        latex,
        style: const TextStyle(color: Colors.white, fontSize: 14, fontStyle: FontStyle.italic),
      );
    }
  }

  Widget _buildOutgoingMessage(_BotMessage msg, String timeStr) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                msg.authorName ?? '我',
                style: const TextStyle(color: Colors.white54, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF5677FC),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (msg.referenceMessageId != null)
                      _buildReferenceQuote(msg.referenceMessageId!, msg.referenceContent, referenceAttachments: msg.referenceAttachments),
                    _buildMessageContent(msg.content),
                  ],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                timeStr,
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            image: _selfAvatarUrl != null
                ? DecorationImage(
                    image: NetworkImage(_selfAvatarUrl!),
                    fit: BoxFit.cover,
                  )
                : const DecorationImage(
                    image: AssetImage(kFallbackHead),
                    fit: BoxFit.cover,
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 引用消息提示
          if (_replyToMessage != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              margin: const EdgeInsets.only(bottom: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.white54),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '回复 ${_replyToMessage!.authorName ?? "消息"}',
                          style: const TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                        Text(
                          _replyToMessage!.content,
                          style: const TextStyle(color: Colors.white54, fontSize: 11),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _replyToMessage = null;
                      });
                    },
                    child: const Icon(Icons.close, size: 16, color: Colors.white54),
                  ),
                ],
              ),
            ),
          // Message type selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                _buildMessageTypeChip('文本', Icons.text_fields, 'text'),
                const SizedBox(width: 8),
                _buildMessageTypeChip('Markdown', Icons.code, 'markdown'),
              ],
            ),
          ),
          const SizedBox(height: 4),
          // Input area
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.42),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _showAttachmentOptions,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white70, size: 20),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Focus(
                    onKeyEvent: (node, event) {
                      if (event is KeyDownEvent) {
                        // 检测回车键
                        if (event.logicalKey == LogicalKeyboardKey.enter) {
                          // 检测是否按下了 Shift
                          if (HardwareKeyboard.instance.isShiftPressed) {
                            // Shift + Enter: 换行
                            return KeyEventResult.ignored;
                          } else {
                            // Enter: 发送消息并阻止默认行为
                            _sendMessage(type: _selectedMessageType);
                            return KeyEventResult.handled;
                          }
                        }
                      }
                      return KeyEventResult.ignored;
                    },
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white, fontSize: 14),
                      maxLines: 4,
                      minLines: 1,
                      decoration: InputDecoration(
                        hintText: _selectedMessageType == 'markdown' ? '输入 Markdown...' : '输入消息...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => _sendMessage(type: _selectedMessageType),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: Color(0xFF5677FC),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.send, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _selectedMessageType = 'text';

  Widget _buildMessageTypeChip(String label, IconData icon, String type) {
    final isSelected = _selectedMessageType == type;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMessageType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5677FC).withOpacity(0.3) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF5677FC) : Colors.white24,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? Colors.white : Colors.white54),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFF1E2A4A),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              '发送附件',
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildAttachmentOption(Icons.image, '图片', () {
                  Navigator.pop(context);
                  _sendMediaMessage('image');
                }),
                _buildAttachmentOption(Icons.videocam, '视频', () {
                  Navigator.pop(context);
                  _sendMediaMessage('video');
                }),
                _buildAttachmentOption(Icons.insert_drive_file, '文件', () {
                  Navigator.pop(context);
                  _sendMediaMessage('file');
                }),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentOption(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF5677FC).withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: const Color(0xFF5677FC), size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }

  Future<void> _sendMediaMessage(String mediaType) async {
    if (_activeConversationId == null || widget.token == null) return;

    // Determine conversation type
    final conv = _conversations.firstWhere(
      (c) => c.id == _activeConversationId,
      orElse: () => _ConversationInfo(id: '', name: '', type: 'private'),
    );
    final convType = conv.type == 'group' ? 'group' : 'private';

    try {
      FileType fileType;
      List<String>? allowedExtensions;
      String displayContent;

      switch (mediaType) {
        case 'image':
          fileType = FileType.image;
          displayContent = '[图片]';
          break;
        case 'video':
          fileType = FileType.video;
          displayContent = '[视频]';
          break;
        default:
          fileType = FileType.any;
          allowedExtensions = null;
          displayContent = '[文件]';
      }

      // Pick file from local
      final result = await FilePicker.pickFiles(
        type: fileType,
        allowedExtensions: allowedExtensions,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      final fileName = file.name;
      final fileBytes = file.bytes;
      final filePath = file.path;

      if (fileBytes == null && filePath == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法读取文件')),
        );
        return;
      }

      // Add message to local UI immediately
      final msg = _BotMessage(
        isIncoming: false,
        type: 'OUTGOING',
        content: displayContent,
        authorName: '我',
        attachments: [_MessageAttachment(url: '', contentType: '$mediaType/*', filename: fileName)],
      );

      if (mounted) {
        setState(() {
          _conversationMessages.putIfAbsent(_activeConversationId!, () => []);
          _conversationMessages[_activeConversationId]!.add(msg);
        });
        _scrollToBottom();
      }

      // Upload file using multipart request
      final uri = Uri.parse('$_apiBaseUrl/api/upload/file');
      final request = http.MultipartRequest('POST', uri);
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.fields['conversationId'] = _activeConversationId!;
      request.fields['type'] = convType;

      // Determine correct MIME type
      String mimeMainType = 'application';
      String mimeSubType = 'octet-stream';
      if (mediaType == 'image') {
        mimeMainType = 'image';
        // Determine subtype from file extension
        final ext = fileName.toLowerCase().split('.').last;
        switch (ext) {
          case 'png': mimeSubType = 'png'; break;
          case 'jpg':
          case 'jpeg': mimeSubType = 'jpeg'; break;
          case 'gif': mimeSubType = 'gif'; break;
          case 'webp': mimeSubType = 'webp'; break;
          case 'bmp': mimeSubType = 'bmp'; break;
          default: mimeSubType = 'png';
        }
      } else if (mediaType == 'video') {
        mimeMainType = 'video';
        final ext = fileName.toLowerCase().split('.').last;
        switch (ext) {
          case 'mp4': mimeSubType = 'mp4'; break;
          case 'avi': mimeSubType = 'x-msvideo'; break;
          case 'mov': mimeSubType = 'quicktime'; break;
          case 'mkv': mimeSubType = 'x-matroska'; break;
          default: mimeSubType = 'mp4';
        }
      }

      if (kIsWeb) {
        // Web platform - use bytes
        request.files.add(http.MultipartFile.fromBytes(
          'file',
          fileBytes!,
          filename: fileName,
          contentType: MediaType(mimeMainType, mimeSubType),
        ));
      } else {
        // Mobile/Desktop platform - use file path
        request.files.add(await http.MultipartFile.fromPath(
          'file',
          filePath!,
          filename: fileName,
          contentType: MediaType(mimeMainType, mimeSubType),
        ));
      }

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        debugPrint('[Upload] Success: $responseData');
      } else {
        debugPrint('[Upload] Failed: ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('上传失败: ${json.decode(response.body)['error'] ?? '未知错误'}')),
          );
        }
      }
    } catch (e) {
      debugPrint('Send media error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('发送失败: $e')),
        );
      }
    }
  }
}

class _MediaPreviewPage extends StatelessWidget {
  final String url;
  final String type;

  const _MediaPreviewPage({required this.url, required this.type});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Center(
        child: type == 'image'
            ? _buildImagePreview(context)
            : _buildVideoPreview(context),
      ),
    );
  }

  Widget _buildImagePreview(BuildContext context) {
    return InteractiveViewer(
      minScale: 0.5,
      maxScale: 4.0,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Center(
            child: CircularProgressIndicator(
              value: loadingProgress.expectedTotalBytes != null
                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                  : null,
              color: Colors.white,
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image, color: Colors.white54, size: 64),
                SizedBox(height: 16),
                Text('图片加载失败', style: TextStyle(color: Colors.white54)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildVideoPreview(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.videocam, color: Colors.white54, size: 80),
        const SizedBox(height: 16),
        const Text(
          '视频预览',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        const SizedBox(height: 8),
        Text(
          'URL: ${url.length > 50 ? '${url.substring(0, 50)}...' : url}',
          style: const TextStyle(color: Colors.white54, fontSize: 12),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () {
            // 可以使用 url_launcher 打开视频链接
          },
          icon: const Icon(Icons.open_in_new),
          label: const Text('在浏览器中打开'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF5677FC),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}
