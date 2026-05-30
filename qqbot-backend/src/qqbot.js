import { QQBotClient, SessionEvents, QQEvent } from './qqbot-client.js';
import { userOps, sessionOps, conversationOps, insertMessageWithAttachments } from './database.js';
import { broadcastToUser } from './websocket.js';

// Store active bot connections
const activeClients = new Map();

export function getActiveClient(userId) {
  return activeClients.get(userId);
}

export async function connectBot(user) {
  const userId = user.id;
  const appId = user.app_id;
  const secret = user.secret;
  const wsUrl = user.ws_url;
  const intents = user.intents || 0x7FFFFFFF;

  // Close existing connection if any
  if (activeClients.has(userId)) {
    const existing = activeClients.get(userId);
    await existing.stop();
    activeClients.delete(userId);
  }

  console.log(`[Bot ${appId}] Starting client...`);

  const client = new QQBotClient({
    appId,
    secret,
    wsUrl,
    intents,
    sandbox: wsUrl.includes('sandbox'),
    shard: [0, 1],
  });

  // Setup event handlers
  client.on(SessionEvents.READY, (data) => {
    console.log(`[Bot ${appId}] Ready! User: ${data.user?.username || data.user?.id}`);
    sessionOps.create(userId, data.session_id, 0);
  });

  client.on(SessionEvents.CLOSE, (code) => {
    console.log(`[Bot ${appId}] Connection closed: ${code}`);
  });

  client.on(SessionEvents.ERROR, (err) => {
    console.error(`[Bot ${appId}] Error:`, err.message);
  });

  client.on(SessionEvents.RECONNECTING, (count) => {
    console.log(`[Bot ${appId}] Reconnecting... attempt ${count}`);
  });

  client.on(SessionEvents.DEAD, () => {
    console.log(`[Bot ${appId}] Connection dead, max retries exceeded`);
    activeClients.delete(userId);
  });

  // Message events
  client.on('message.private.friend', (data) => handleIncomingMessage(client, userId, appId, 'C2C_MESSAGE_CREATE', data));
  client.on('message.group', (data) => handleIncomingMessage(client, userId, appId, 'GROUP_MESSAGE_CREATE', data));
  client.on('message.group.at', (data) => handleIncomingMessage(client, userId, appId, 'GROUP_AT_MESSAGE_CREATE', data));
  client.on('message.private.direct', (data) => handleIncomingMessage(client, userId, appId, 'DIRECT_MESSAGE_CREATE', data));
  client.on('message.guild', (data) => handleIncomingMessage(client, userId, appId, 'AT_MESSAGE_CREATE', data));

  // Forum events
  client.on('forum.post.create', (data) => handleForumEvent(client, userId, appId, 'FORUM_POST_CREATE', data));
  client.on('forum.reply.create', (data) => handleForumEvent(client, userId, appId, 'FORUM_REPLY_CREATE', data));

  // Group member events
  client.on('group.add', (data) => handleGroupEvent(client, userId, appId, 'GROUP_ADD_ROBOT', data));
  client.on('group.del', (data) => handleGroupEvent(client, userId, appId, 'GROUP_DEL_ROBOT', data));

  // Raw events for debugging
  client.on('raw', (event) => {
    if (!['HEARTBEAT_ACK'].includes(event.type)) {
      console.log(`[Bot ${appId}] Raw event: ${event.type}`);
    }
  });

  activeClients.set(userId, client);

  try {
    const botInfo = await client.start();
    console.log(`[Bot ${appId}] Connected successfully`);
    return { client, botInfo };
  } catch (err) {
    console.error(`[Bot ${appId}] Failed to start:`, err.message);
    activeClients.delete(userId);
    throw err;
  }
}

function handleIncomingMessage(client, userId, appId, eventType, data) {
  console.log(`\n${'='.repeat(60)}`);
  console.log(`[Bot ${appId}] Message event: ${eventType}`);
  console.log(`[Bot ${appId}] Raw message data:`, JSON.stringify(data, null, 2));
  console.log(`[Bot ${appId}] Raw author data:`, JSON.stringify(data.author, null, 2));
  console.log(`[Bot ${appId}] Raw member data:`, JSON.stringify(data.member, null, 2));

  const content = data.content || '';
  const authorName = data.author?.username || data.member?.nick || 'Unknown';
  const authorBot = data.author?.bot || false;
  
  // 获取作者 ID - 群消息和私聊消息使用不同的字段
  let authorId = '';
  if (eventType.startsWith('GROUP_')) {
    // 群消息使用 member_openid
    authorId = data.author?.member_openid || data.author?.user_openid || data.author?.openid || '';
  } else {
    // 私聊消息使用 user_openid
    authorId = data.author?.user_openid || data.author?.openid || '';
  }
  
  // 构建头像 URL
  let authorAvatar = data.author?.avatar || '';
  console.log(`[Bot ${appId}] Original avatar from API: "${authorAvatar}"`);
  console.log(`[Bot ${appId}] Author ID for avatar: "${authorId}"`);
  
  if (!authorAvatar && authorId && appId) {
    // QQ Bot API 的头像 URL 格式
    authorAvatar = `https://q.qlogo.cn/qqapp/${appId}/${authorId}/0`;
    console.log(`[Bot ${appId}] Generated avatar URL: "${authorAvatar}"`);
  }

  console.log(`[Bot ${appId}] Author: ${authorName} (${authorId}), Avatar: ${authorAvatar}`);
  console.log(`[Bot ${appId}] Content: "${content}"`);
  console.log(`[Bot ${appId}] Message ID: ${data.id || 'N/A'}`);

  // 解析引用消息
  let referenceMessageId = null;
  let referenceContent = null;
  let referenceAuthor = null;
  let referenceAttachments = [];
  
  // 检查 message_reference 字段
  if (data.message_reference) {
    referenceMessageId = data.message_reference.message_id;
    console.log(`[Bot ${appId}] Reference message ID from message_reference: ${referenceMessageId}`);
  }
  
  // 检查 message_scene.ext 中的引用信息
  if (data.message_scene && data.message_scene.ext) {
    console.log(`[Bot ${appId}] message_scene.ext:`, JSON.stringify(data.message_scene.ext, null, 2));
    for (const extItem of data.message_scene.ext) {
      if (typeof extItem === 'string') {
        // 解析 ref_msg_idx（被引用的消息 ID）
        if (extItem.includes('ref_msg_idx=')) {
          const match = extItem.match(/ref_msg_idx=(REFIDX_[A-Za-z0-9+/=]+)/);
          if (match) {
            referenceMessageId = match[1];
            console.log(`[Bot ${appId}] Reference message ID from ref_msg_idx: ${referenceMessageId}`);
          }
        }
        // 如果没有 ref_msg_idx，检查 msg_idx（某些情况下 msg_idx 就是引用 ID）
        if (!referenceMessageId && extItem.includes('msg_idx=')) {
          const match = extItem.match(/msg_idx=(REFIDX_[A-Za-z0-9+/=]+)/);
          if (match) {
            referenceMessageId = match[1];
            console.log(`[Bot ${appId}] Reference message ID from msg_idx: ${referenceMessageId}`);
          }
        }
      }
    }
  }
  
  // 从 msg_elements 中获取引用消息内容和附件
  if (data.msg_elements && data.msg_elements.length > 0) {
    for (const element of data.msg_elements) {
      if (element.msg_idx === referenceMessageId) {
        referenceContent = element.content || '';
        referenceAuthor = element.author?.username || '';
        
        // 解析引用消息的附件
        if (element.attachments && element.attachments.length > 0) {
          for (const att of element.attachments) {
            referenceAttachments.push({
              url: att.url || '',
              content_type: att.content_type || '',
              filename: att.filename || '',
              width: att.width || null,
              height: att.height || null,
            });
          }
        }
        
        console.log(`[Bot ${appId}] Reference content: "${referenceContent}", author: "${referenceAuthor}", attachments: ${referenceAttachments.length}`);
        break;
      }
    }
  }
  
  console.log(`[Bot ${appId}] Final reference message ID: ${referenceMessageId}`);
  console.log(`[Bot ${appId}] Reference content: "${referenceContent}"`);
  console.log(`${'='.repeat(60)}\n`);

  // Determine conversation ID
  let conversationId = '';
  let conversationName = authorName;
  let conversationType = 'private';

  if (eventType.startsWith('GROUP_')) {
    conversationId = data.group_openid || '';
    conversationType = 'group';
    conversationName = data.group_name || `群聊 ${conversationId}`;
  } else if (eventType === 'DIRECT_MESSAGE_CREATE') {
    conversationId = data.guild_id || '';
    conversationType = 'direct';
  } else {
    conversationId = data.author?.user_openid || '';
  }

  // Parse face text
  let faceText = null;
  if (data.embeds && data.embeds.length > 0) {
    faceText = data.embeds[0]?.title || null;
  }

  // Parse attachments
  const attachments = [];
  if (data.attachments && data.attachments.length > 0) {
    for (const att of data.attachments) {
      attachments.push({
        url: att.url || '',
        content_type: att.content_type || '',
        filename: att.filename || '',
        width: att.width || null,
        height: att.height || null,
      });
    }
  }

  // Save message to database
  try {
    insertMessageWithAttachments({
      userId,
      eventType,
      content,
      authorName,
      authorId,
      authorAvatar,
      authorBot,
      conversationId,
      isIncoming: true,
      faceText,
      timestamp: new Date().toISOString(),
      messageId: data.id || null,
      referenceMessageId: referenceMessageId || null,
    }, attachments);
  } catch (err) {
    console.error(`[Bot ${appId}] Error saving message:`, err);
  }

  // Update conversation
  try {
    conversationOps.upsert(
      userId,
      conversationId,
      conversationName,
      conversationType,
      content.substring(0, 100),
      new Date().toISOString()
    );
  } catch (err) {
    console.error(`[Bot ${appId}] Error updating conversation:`, err);
  }

  // Broadcast to connected frontend clients
  broadcastToUser(userId, {
    type: 'new_message',
    data: {
      eventType,
      content,
      authorName,
      authorId,
      authorAvatar,
      authorBot,
      conversationId,
      isIncoming: true,
      faceText,
      attachments,
      messageId: data.id || null,
      referenceMessageId: referenceMessageId || null,
      referenceContent: referenceContent || null,
      referenceAuthor: referenceAuthor || null,
      referenceAttachments: referenceAttachments,
      message_scene: data.message_scene || null,
      timestamp: new Date().toISOString(),
    },
  });
}

function handleForumEvent(client, userId, appId, eventType, data) {
  console.log(`[Bot ${appId}] Forum event: ${eventType}`);
  broadcastToUser(userId, {
    type: 'forum_event',
    data: { eventType, ...data },
  });
}

function handleGroupEvent(client, userId, appId, eventType, data) {
  console.log(`[Bot ${appId}] Group event: ${eventType}`);
  broadcastToUser(userId, {
    type: 'group_event',
    data: { eventType, ...data },
  });
}

// Send message functions
export async function sendPrivateMessage(userId, openId, content, options = {}) {
  const client = activeClients.get(userId);
  if (!client) throw new Error('Bot not connected');

  const { msgType = 0, msgId, markdown, keyboard, media, fileUuid, messageReference } = options;
  console.log(`[QQBot DEBUG] sendPrivateMessage options:`, JSON.stringify(options, null, 2));
  return client.sendPrivateMessage(openId, content, msgType, msgId, markdown, keyboard, media, fileUuid, messageReference);
}

export async function sendGroupMessage(userId, openId, content, options = {}) {
  const client = activeClients.get(userId);
  if (!client) throw new Error('Bot not connected');

  const { msgType = 0, msgId, markdown, keyboard, media, fileUuid, messageReference } = options;
  console.log(`[QQBot DEBUG] sendGroupMessage options:`, JSON.stringify(options, null, 2));
  return client.sendGroupMessage(openId, content, msgType, msgId, markdown, keyboard, media, fileUuid, messageReference);
}

export async function sendGuildMessage(userId, channelId, content, options = {}) {
  const client = activeClients.get(userId);
  if (!client) throw new Error('Bot not connected');

  const { embed, image, msgId, markdown } = options;
  return client.sendGuildMessage(channelId, content, embed, image, msgId, markdown);
}

export async function sendDirectMessage(userId, guildId, content, options = {}) {
  const client = activeClients.get(userId);
  if (!client) throw new Error('Bot not connected');

  const { embed, image, msgId } = options;
  return client.sendDirectMessage(guildId, content, embed, image, msgId);
}

export async function recallMessage(userId, conversationId, msgId, type = 'private') {
  const client = activeClients.get(userId);
  if (!client) throw new Error('Bot not connected');

  if (type === 'group') {
    return client.recallGroupMessage(conversationId, msgId);
  }
  return client.recallPrivateMessage(conversationId, msgId);
}

export async function sendMarkdown(userId, conversationId, markdown, type = 'private') {
  const client = activeClients.get(userId);
  if (!client) throw new Error('Bot not connected');

  console.log(`[QQBot DEBUG] sendMarkdown called`);
  console.log(`[QQBot DEBUG] userId: ${userId}, conversationId: ${conversationId}, type: ${type}`);
  console.log(`[QQBot DEBUG] markdown:`, markdown);

  let result;
  if (type === 'group') {
    result = await client.sendGroupMarkdown(conversationId, markdown);
  } else {
    result = await client.sendPrivateMarkdown(conversationId, markdown);
  }

  console.log(`[QQBot DEBUG] sendMarkdown result:`, JSON.stringify(result, null, 2));
  return result;
}

export async function sendKeyboard(userId, conversationId, keyboard, content = '', type = 'private') {
  const client = activeClients.get(userId);
  if (!client) throw new Error('Bot not connected');

  if (type === 'group') {
    return client.sendGroupKeyboard(conversationId, keyboard, content);
  }
  return client.sendPrivateKeyboard(conversationId, keyboard, content);
}

export async function sendMedia(userId, conversationId, fileUrl, type = 'private') {
  const client = activeClients.get(userId);
  if (!client) throw new Error('Bot not connected');

  if (type === 'group') {
    return client.sendGroupMedia(conversationId, fileUrl);
  }
  return client.sendPrivateMedia(conversationId, fileUrl);
}

export function disconnectBot(userId) {
  if (activeClients.has(userId)) {
    const client = activeClients.get(userId);
    client.stop();
    activeClients.delete(userId);
    return true;
  }
  return false;
}

export async function disconnectAllBots() {
  for (const [userId, client] of activeClients) {
    await client.stop();
  }
  activeClients.clear();
}

// Reconnect all bots from database on startup
export function reconnectAllBots() {
  const users = userOps.getAll();
  console.log(`Reconnecting ${users.length} bots...`);

  for (const user of users) {
    try {
      const fullUser = userOps.getById(user.id);
      if (fullUser) {
        connectBot(fullUser).catch(err => {
          console.error(`Error reconnecting bot ${user.app_id}:`, err.message);
        });
      }
    } catch (err) {
      console.error(`Error reconnecting bot ${user.app_id}:`, err);
    }
  }
}
