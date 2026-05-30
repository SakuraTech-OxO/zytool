import express from 'express';
import crypto from 'crypto';
import multer from 'multer';
import {
  userOps,
  conversationOps,
  messageOps,
  attachmentOps,
  insertMessageWithAttachments
} from './database.js';
import {
  connectBot,
  disconnectBot,
  getActiveClient,
  sendPrivateMessage,
  sendGroupMessage,
  sendGuildMessage,
  sendDirectMessage,
  recallMessage,
  sendMarkdown,
  sendKeyboard,
  sendMedia
} from './qqbot.js';

const router = express.Router();

// Configure multer for file upload
const upload = multer({
  storage: multer.memoryStorage(),
  limits: {
    fileSize: 50 * 1024 * 1024, // 50MB limit
  },
});

// Generate simple token
function generateToken() {
  return crypto.randomBytes(32).toString('hex');
}

// Auth middleware
function authMiddleware(req, res, next) {
  const token = req.headers.authorization?.replace('Bearer ', '');
  if (!token) {
    return res.status(401).json({ error: 'No token provided' });
  }

  // Find user by token
  const users = userOps.getAll();
  let user = null;
  for (const u of users) {
    const fullUser = userOps.getById(u.id);
    if (fullUser && fullUser.token === token) {
      user = fullUser;
      break;
    }
  }

  if (!user) {
    return res.status(401).json({ error: 'Invalid token' });
  }

  req.user = user;
  next();
}

// Register new bot
router.post('/register', (req, res) => {
  try {
    const { appId, secret, wsUrl, intents } = req.body;

    if (!appId || !secret || !wsUrl) {
      return res.status(400).json({ error: 'Missing required fields: appId, secret, wsUrl' });
    }

    // Check if already registered
    const existing = userOps.getByAppId(appId);
    if (existing) {
      return res.status(409).json({ error: 'Bot already registered' });
    }

    // Create user
    const userId = userOps.create(appId, secret, wsUrl, intents || 0x7FFFFFFF);

    const token = generateToken();
    userOps.updateToken(token, userId);

    // Connect bot
    const user = userOps.getById(userId);
    connectBot(user).catch(err => {
      console.error('Connect bot error:', err.message);
    });

    res.json({
      success: true,
      data: {
        userId,
        token,
        appId
      }
    });
  } catch (err) {
    console.error('Register error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Login
router.post('/login', (req, res) => {
  try {
    const { appId, secret } = req.body;

    if (!appId || !secret) {
      return res.status(400).json({ error: 'Missing required fields: appId, secret' });
    }

    const user = userOps.getByAppId(appId);
    if (!user) {
      return res.status(404).json({ error: 'Bot not found' });
    }

    if (user.secret !== secret) {
      return res.status(401).json({ error: 'Invalid secret' });
    }

    // Generate new token
    const token = generateToken();
    userOps.updateToken(token, user.id);

    // Check bot connection status
    const client = getActiveClient(user.id);
    const isConnected = client?.connection?.alive || false;

    res.json({
      success: true,
      data: {
        userId: user.id,
        token,
        appId: user.app_id,
        isConnected
      }
    });
  } catch (err) {
    console.error('Login error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get user profile
router.get('/profile', authMiddleware, (req, res) => {
  const user = req.user;
  const client = getActiveClient(user.id);

  res.json({
    success: true,
    data: {
      userId: user.id,
      appId: user.app_id,
      wsUrl: user.ws_url,
      intents: user.intents,
      isConnected: client?.connection?.alive || false,
      botInfo: client?.self || null,
      createdAt: user.created_at
    }
  });
});

// Update bot config
router.put('/config', authMiddleware, (req, res) => {
  try {
    const { wsUrl } = req.body;
    const user = req.user;

    if (wsUrl) {
      userOps.updateWsUrl(wsUrl, user.id);
    }

    res.json({ success: true, message: 'Config updated' });
  } catch (err) {
    console.error('Update config error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Reconnect bot
router.post('/reconnect', authMiddleware, async (req, res) => {
  try {
    const user = req.user;
    disconnectBot(user.id);

    const freshUser = userOps.getById(user.id);
    connectBot(freshUser).catch(err => {
      console.error('Reconnect error:', err.message);
    });

    res.json({ success: true, message: 'Reconnecting...' });
  } catch (err) {
    console.error('Reconnect error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get conversations
router.get('/conversations', authMiddleware, (req, res) => {
  try {
    const conversations = conversationOps.getByUserId(req.user.id);
    res.json({
      success: true,
      data: conversations
    });
  } catch (err) {
    console.error('Get conversations error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Update conversation custom info (name and id)
router.put('/conversations/:conversationId/custom', authMiddleware, (req, res) => {
  try {
    const { conversationId } = req.params;
    const { customName, customId } = req.body;

    console.log(`[API DEBUG] PUT /api/conversations/${conversationId}/custom`);
    console.log(`[API DEBUG] customName: ${customName}, customId: ${customId}`);

    conversationOps.updateCustomInfo(req.user.id, conversationId, customName, customId);

    res.json({
      success: true,
      message: 'Custom info updated'
    });
  } catch (err) {
    console.error('Update custom info error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get conversation custom info
router.get('/conversations/:conversationId/custom', authMiddleware, (req, res) => {
  try {
    const { conversationId } = req.params;
    const customInfo = conversationOps.getCustomInfo(req.user.id, conversationId);

    res.json({
      success: true,
      data: customInfo
    });
  } catch (err) {
    console.error('Get custom info error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get messages by conversation
router.get('/messages/:conversationId', authMiddleware, (req, res) => {
  try {
    const { conversationId } = req.params;
    const { limit = 50, offset = 0 } = req.query;

    const messages = messageOps.getByConversationId(
      req.user.id,
      conversationId,
      parseInt(limit),
      parseInt(offset)
    );

    // Get attachments for each message
    const messagesWithAttachments = messages.map(msg => {
      const attachments = attachmentOps.getByMessageId(msg.id);
      return {
        ...msg,
        attachments: attachments || []
      };
    });

    // Reset unread count
    conversationOps.resetUnread(req.user.id, conversationId);

    res.json({
      success: true,
      data: messagesWithAttachments.reverse()
    });
  } catch (err) {
    console.error('Get messages error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Get latest messages
router.get('/messages', authMiddleware, (req, res) => {
  try {
    const { limit = 50 } = req.query;

    const messages = messageOps.getLatest(
      req.user.id,
      parseInt(limit)
    );

    const messagesWithAttachments = messages.map(msg => {
      const attachments = attachmentOps.getByMessageId(msg.id);
      return {
        ...msg,
        attachments: attachments || []
      };
    });

    res.json({
      success: true,
      data: messagesWithAttachments.reverse()
    });
  } catch (err) {
    console.error('Get messages error:', err);
    res.status(500).json({ error: err.message });
  }
});

// ========== Message Sending APIs ==========

// Send text message
router.post('/messages/send', authMiddleware, async (req, res) => {
  try {
    const { conversationId, content, type = 'private', msgType = 0, message_reference } = req.body;

    console.log(`[API DEBUG] POST /api/messages/send`);
    console.log(`[API DEBUG] Request body:`, JSON.stringify(req.body, null, 2));
    console.log(`[API DEBUG] User ID: ${req.user.id}, Conversation: ${conversationId}, Type: ${type}`);
    console.log(`[API DEBUG] Message reference:`, message_reference);

    if (!conversationId || !content) {
      return res.status(400).json({ error: 'Missing required fields: conversationId, content' });
    }

    const options = { msgType };
    if (message_reference) {
      options.messageReference = message_reference;
    }

    let result;
    if (type === 'group') {
      result = await sendGroupMessage(req.user.id, conversationId, content, options);
    } else if (type === 'guild') {
      result = await sendGuildMessage(req.user.id, conversationId, content);
    } else if (type === 'direct') {
      result = await sendDirectMessage(req.user.id, conversationId, content);
    } else {
      result = await sendPrivateMessage(req.user.id, conversationId, content, options);
    }

    console.log(`[API DEBUG] Send result:`, JSON.stringify(result, null, 2));

    // Save outgoing message to database
    try {
      const user = userOps.getById(req.user.id);
      insertMessageWithAttachments({
        userId: req.user.id,
        messageId: result?.id || null,
        referenceMessageId: message_reference?.message_id || null,
        eventType: 'OUTGOING',
        content: content,
        authorName: '我',
        authorId: user?.app_id || '',
        authorAvatar: '',
        authorBot: false,
        conversationId: conversationId,
        isIncoming: false,
        faceText: null,
        timestamp: new Date().toISOString(),
      }, []);
      
      // Update conversation
      conversationOps.upsert(
        req.user.id,
        conversationId,
        content.substring(0, 100),
        type,
        content.substring(0, 100),
        new Date().toISOString()
      );
    } catch (saveErr) {
      console.error('[API DEBUG] Save outgoing message error:', saveErr);
    }

    res.json({
      success: true,
      data: result
    });
  } catch (err) {
    console.error('[API DEBUG] Send message error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Send markdown message
router.post('/messages/markdown', authMiddleware, async (req, res) => {
  try {
    const { conversationId, markdown, type = 'private' } = req.body;

    console.log(`[API DEBUG] POST /api/messages/markdown`);
    console.log(`[API DEBUG] Request body:`, JSON.stringify(req.body, null, 2));
    console.log(`[API DEBUG] User ID: ${req.user.id}, Conversation: ${conversationId}, Type: ${type}`);
    console.log(`[API DEBUG] Markdown content:`, markdown);

    if (!conversationId || !markdown) {
      return res.status(400).json({ error: 'Missing required fields: conversationId, markdown' });
    }

    const result = await sendMarkdown(req.user.id, conversationId, markdown, type);

    console.log(`[API DEBUG] Send markdown result:`, JSON.stringify(result, null, 2));

    // Save outgoing message to database
    try {
      const user = userOps.getById(req.user.id);
      insertMessageWithAttachments({
        userId: req.user.id,
        messageId: result?.id || null,
        referenceMessageId: null,
        eventType: 'OUTGOING',
        content: markdown,
        authorName: '我',
        authorId: user?.app_id || '',
        authorAvatar: '',
        authorBot: false,
        conversationId: conversationId,
        isIncoming: false,
        faceText: null,
        timestamp: new Date().toISOString(),
      }, []);
      
      // Update conversation
      conversationOps.upsert(
        req.user.id,
        conversationId,
        markdown.substring(0, 100),
        type,
        markdown.substring(0, 100),
        new Date().toISOString()
      );
    } catch (saveErr) {
      console.error('[API DEBUG] Save outgoing message error:', saveErr);
    }

    res.json({
      success: true,
      data: result
    });
  } catch (err) {
    console.error('[API DEBUG] Send markdown error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Send keyboard message
router.post('/messages/keyboard', authMiddleware, async (req, res) => {
  try {
    const { conversationId, keyboard, content = '', type = 'private' } = req.body;

    if (!conversationId || !keyboard) {
      return res.status(400).json({ error: 'Missing required fields: conversationId, keyboard' });
    }

    const result = await sendKeyboard(req.user.id, conversationId, keyboard, content, type);

    res.json({
      success: true,
      data: result
    });
  } catch (err) {
    console.error('Send keyboard error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Send media message (upload URL and send)
router.post('/messages/media', authMiddleware, async (req, res) => {
  try {
    const { conversationId, fileUrl, fileType = 1, fileName, type = 'private' } = req.body;

    console.log(`[API DEBUG] POST /api/messages/media`);
    console.log(`[API DEBUG] Request body:`, JSON.stringify(req.body, null, 2));

    if (!conversationId || !fileUrl) {
      return res.status(400).json({ error: 'Missing required fields: conversationId, fileUrl' });
    }

    const client = getActiveClient(req.user.id);
    if (!client) {
      return res.status(400).json({ error: 'Bot not connected' });
    }

    let result;
    if (type === 'group') {
      // Upload file first
      const uploadResult = await client.uploadGroupFile(conversationId, {
        fileType,
        url: fileUrl,
        fileName,
      });
      // Send media message with file_info
      result = await client.sendGroupMediaMessage(conversationId, uploadResult.file_info);
    } else {
      // Upload file first
      const uploadResult = await client.uploadPrivateFile(conversationId, {
        fileType,
        url: fileUrl,
        fileName,
      });
      // Send media message with file_info
      result = await client.sendPrivateMediaMessage(conversationId, uploadResult.file_info);
    }

    console.log(`[API DEBUG] Send media result:`, JSON.stringify(result, null, 2));

    res.json({
      success: true,
      data: result
    });
  } catch (err) {
    console.error('[API DEBUG] Send media error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Upload file only (without sending)
router.post('/upload', authMiddleware, async (req, res) => {
  try {
    const { conversationId, fileUrl, fileType = 1, fileName, type = 'private' } = req.body;

    console.log(`[API DEBUG] POST /api/upload`);
    console.log(`[API DEBUG] Request body:`, JSON.stringify(req.body, null, 2));

    if (!conversationId || !fileUrl) {
      return res.status(400).json({ error: 'Missing required fields: conversationId, fileUrl' });
    }

    const client = getActiveClient(req.user.id);
    if (!client) {
      return res.status(400).json({ error: 'Bot not connected' });
    }

    let result;
    if (type === 'group') {
      result = await client.uploadGroupFile(conversationId, {
        fileType,
        url: fileUrl,
        fileName,
      });
    } else {
      result = await client.uploadPrivateFile(conversationId, {
        fileType,
        url: fileUrl,
        fileName,
      });
    }

    console.log(`[API DEBUG] Upload result:`, JSON.stringify(result, null, 2));

    res.json({
      success: true,
      data: result
    });
  } catch (err) {
    console.error('[API DEBUG] Upload error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Upload file from local and send
router.post('/upload/file', authMiddleware, upload.single('file'), async (req, res) => {
  try {
    const { conversationId, type = 'private' } = req.body;
    const file = req.file;

    console.log(`[API DEBUG] POST /api/upload/file`);
    console.log(`[API DEBUG] Conversation: ${conversationId}, Type: ${type}`);
    console.log(`[API DEBUG] File: ${file?.originalname}, Size: ${file?.size}, Mimetype: ${file?.mimetype}`);

    if (!conversationId || !file) {
      return res.status(400).json({ error: 'Missing required fields: conversationId, file' });
    }

    const client = getActiveClient(req.user.id);
    if (!client) {
      return res.status(400).json({ error: 'Bot not connected' });
    }

    // Determine file type based on mimetype
    let fileType = 4; // default: file
    if (file.mimetype.startsWith('image/')) {
      fileType = 1;
    } else if (file.mimetype.startsWith('video/')) {
      fileType = 2;
    } else if (file.mimetype.startsWith('audio/')) {
      fileType = 3;
    }

    // Convert file buffer to base64
    const fileData = file.buffer.toString('base64');

    // Upload file
    let uploadResult;
    if (type === 'group') {
      uploadResult = await client.uploadGroupFile(conversationId, {
        fileType,
        fileData,
        fileName: file.originalname,
      });
    } else {
      uploadResult = await client.uploadPrivateFile(conversationId, {
        fileType,
        fileData,
        fileName: file.originalname,
      });
    }

    console.log(`[API DEBUG] Upload result:`, JSON.stringify(uploadResult, null, 2));

    // Send media message with file_info
    let sendResult;
    if (type === 'group') {
      sendResult = await client.sendGroupMediaMessage(conversationId, uploadResult.file_info);
    } else {
      sendResult = await client.sendPrivateMediaMessage(conversationId, uploadResult.file_info);
    }

    console.log(`[API DEBUG] Send result:`, JSON.stringify(sendResult, null, 2));

    res.json({
      success: true,
      data: sendResult
    });
  } catch (err) {
    console.error('[API DEBUG] Upload and send error:', err);
    res.status(500).json({ error: err.message });
  }
});

// Recall message
router.delete('/messages/:conversationId/:msgId', authMiddleware, async (req, res) => {
  try {
    const { conversationId, msgId } = req.params;
    const { type = 'private' } = req.query;

    await recallMessage(req.user.id, conversationId, msgId, type);

    res.json({
      success: true,
      message: 'Message recalled'
    });
  } catch (err) {
    console.error('Recall message error:', err);
    res.status(500).json({ error: err.message });
  }
});

export default router;
