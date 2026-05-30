import initSqlJs from 'sql.js';
import path from 'path';
import { fileURLToPath } from 'url';
import fs from 'fs';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const dbPath = path.join(__dirname, '..', 'data', 'qqbot.db');

// Ensure data directory exists
const dataDir = path.dirname(dbPath);
if (!fs.existsSync(dataDir)) {
  fs.mkdirSync(dataDir, { recursive: true });
}

let db = null;

export async function initDatabase() {
  const SQL = await initSqlJs();

  // Load existing database or create new one
  if (fs.existsSync(dbPath)) {
    const fileBuffer = fs.readFileSync(dbPath);
    db = new SQL.Database(fileBuffer);
  } else {
    db = new SQL.Database();
  }

  // Enable WAL mode
  db.run('PRAGMA journal_mode = WAL');

  // Create tables
  db.run(`
    CREATE TABLE IF NOT EXISTS users (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      app_id TEXT UNIQUE NOT NULL,
      secret TEXT NOT NULL,
      ws_url TEXT NOT NULL,
      intents INTEGER DEFAULT 33554431,
      token TEXT,
      created_at DATETIME DEFAULT CURRENT_TIMESTAMP,
      updated_at DATETIME DEFAULT CURRENT_TIMESTAMP
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS sessions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      session_id TEXT,
      last_seq INTEGER DEFAULT 0,
      connected_at DATETIME,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `);

  db.run(`
    CREATE TABLE IF NOT EXISTS conversations (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      conversation_id TEXT NOT NULL,
      name TEXT,
      type TEXT DEFAULT 'private',
      last_message TEXT,
      last_message_time DATETIME,
      unread_count INTEGER DEFAULT 0,
      FOREIGN KEY (user_id) REFERENCES users(id),
      UNIQUE(user_id, conversation_id)
    )
  `);

  // Migration: Add custom_name and custom_id columns if not exists
  try {
    const tableInfo = getAll("PRAGMA table_info(conversations)");
    const columns = tableInfo.map(col => col.name);
    
    if (!columns.includes('custom_name')) {
      runQuery('ALTER TABLE conversations ADD COLUMN custom_name TEXT');
      console.log('[DB] Added custom_name column');
    }
    if (!columns.includes('custom_id')) {
      runQuery('ALTER TABLE conversations ADD COLUMN custom_id TEXT');
      console.log('[DB] Added custom_id column');
    }
  } catch (err) {
    console.log('[DB] Migration check:', err.message);
  }

  db.run(`
    CREATE TABLE IF NOT EXISTS messages (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      user_id INTEGER NOT NULL,
      message_id TEXT,
      reference_message_id TEXT,
      event_type TEXT NOT NULL,
      content TEXT,
      author_name TEXT,
      author_id TEXT,
      author_avatar TEXT,
      author_bot INTEGER DEFAULT 0,
      conversation_id TEXT,
      is_incoming INTEGER DEFAULT 1,
      face_text TEXT,
      timestamp DATETIME DEFAULT CURRENT_TIMESTAMP,
      FOREIGN KEY (user_id) REFERENCES users(id)
    )
  `);

  // Migration: Add missing columns if not exists
  try {
    const tableInfo = getAll("PRAGMA table_info(messages)");
    const columns = tableInfo.map(col => col.name);
    
    if (!columns.includes('author_bot')) {
      runQuery('ALTER TABLE messages ADD COLUMN author_bot INTEGER DEFAULT 0');
      console.log('[DB] Added author_bot column');
    }
    if (!columns.includes('reference_message_id')) {
      runQuery('ALTER TABLE messages ADD COLUMN reference_message_id TEXT');
      console.log('[DB] Added reference_message_id column');
    }
  } catch (err) {
    console.log('[DB] Migration check:', err.message);
  }

  db.run(`
    CREATE TABLE IF NOT EXISTS message_attachments (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      message_id INTEGER NOT NULL,
      url TEXT,
      content_type TEXT,
      filename TEXT,
      width INTEGER,
      height INTEGER,
      FOREIGN KEY (message_id) REFERENCES messages(id) ON DELETE CASCADE
    )
  `);

  // Create indexes
  db.run('CREATE INDEX IF NOT EXISTS idx_messages_user_id ON messages(user_id)');
  db.run('CREATE INDEX IF NOT EXISTS idx_messages_conversation_id ON messages(conversation_id)');
  db.run('CREATE INDEX IF NOT EXISTS idx_messages_timestamp ON messages(timestamp)');
  db.run('CREATE INDEX IF NOT EXISTS idx_conversations_user_id ON conversations(user_id)');

  // Save database
  saveDatabase();

  console.log('Database initialized');
  return db;
}

export function saveDatabase() {
  if (db) {
    const data = db.export();
    const buffer = Buffer.from(data);
    fs.writeFileSync(dbPath, buffer);
  }
}

// Auto-save every 30 seconds
setInterval(saveDatabase, 30000);

export function getDb() {
  return db;
}

// Helper function to run queries
export function runQuery(sql, params = []) {
  db.run(sql, params);
  return db;
}

// Helper function to get all rows
export function getAll(sql, params = []) {
  const stmt = db.prepare(sql);
  stmt.bind(params);
  const results = [];
  while (stmt.step()) {
    results.push(stmt.getAsObject());
  }
  stmt.free();
  return results;
}

// Helper function to get single row
export function getOne(sql, params = []) {
  const results = getAll(sql, params);
  return results.length > 0 ? results[0] : null;
}

// Helper function to run insert and return last ID
export function insert(sql, params = []) {
  db.run(sql, params);
  const result = getOne('SELECT last_insert_rowid() as id');
  return result ? result.id : null;
}

// User operations
export const userOps = {
  create(appId, secret, wsUrl, intents) {
    return insert(
      'INSERT INTO users (app_id, secret, ws_url, intents) VALUES (?, ?, ?, ?)',
      [appId, secret, wsUrl, intents || 33554431]
    );
  },

  getByAppId(appId) {
    return getOne('SELECT * FROM users WHERE app_id = ?', [appId]);
  },

  getById(id) {
    return getOne('SELECT * FROM users WHERE id = ?', [id]);
  },

  updateToken(token, userId) {
    runQuery('UPDATE users SET token = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [token, userId]);
  },

  updateWsUrl(wsUrl, userId) {
    runQuery('UPDATE users SET ws_url = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?', [wsUrl, userId]);
  },

  getAll() {
    return getAll('SELECT id, app_id, ws_url, intents, created_at FROM users');
  }
};

// Session operations
export const sessionOps = {
  create(userId, sessionId, lastSeq) {
    return insert(
      'INSERT INTO sessions (user_id, session_id, last_seq, connected_at) VALUES (?, ?, ?, CURRENT_TIMESTAMP)',
      [userId, sessionId, lastSeq || 0]
    );
  },

  getByUserId(userId) {
    return getOne('SELECT * FROM sessions WHERE user_id = ? ORDER BY id DESC LIMIT 1', [userId]);
  },

  updateSeq(lastSeq, userId, sessionId) {
    runQuery('UPDATE sessions SET last_seq = ? WHERE user_id = ? AND session_id = ?', [lastSeq, userId, sessionId]);
  }
};

// Conversation operations
export const conversationOps = {
  upsert(userId, conversationId, name, type, lastMessage, lastMessageTime) {
    const existing = getOne(
      'SELECT * FROM conversations WHERE user_id = ? AND conversation_id = ?',
      [userId, conversationId]
    );

    if (existing) {
      runQuery(
        'UPDATE conversations SET name = COALESCE(?, name), last_message = ?, last_message_time = ?, unread_count = unread_count + 1 WHERE user_id = ? AND conversation_id = ?',
        [name, lastMessage, lastMessageTime, userId, conversationId]
      );
    } else {
      insert(
        'INSERT INTO conversations (user_id, conversation_id, name, type, last_message, last_message_time) VALUES (?, ?, ?, ?, ?, ?)',
        [userId, conversationId, name, type, lastMessage, lastMessageTime]
      );
    }
  },

  getByUserId(userId) {
    return getAll('SELECT * FROM conversations WHERE user_id = ? ORDER BY last_message_time DESC', [userId]);
  },

  getByConversationId(userId, conversationId) {
    return getOne('SELECT * FROM conversations WHERE user_id = ? AND conversation_id = ?', [userId, conversationId]);
  },

  resetUnread(userId, conversationId) {
    runQuery('UPDATE conversations SET unread_count = 0 WHERE user_id = ? AND conversation_id = ?', [userId, conversationId]);
  },

  updateCustomInfo(userId, conversationId, customName, customId) {
    const existing = getOne(
      'SELECT * FROM conversations WHERE user_id = ? AND conversation_id = ?',
      [userId, conversationId]
    );

    if (existing) {
      runQuery(
        'UPDATE conversations SET custom_name = ?, custom_id = ? WHERE user_id = ? AND conversation_id = ?',
        [customName, customId, userId, conversationId]
      );
    } else {
      // Insert with minimal info if not exists
      insert(
        'INSERT INTO conversations (user_id, conversation_id, name, type, custom_name, custom_id) VALUES (?, ?, ?, ?, ?, ?)',
        [userId, conversationId, customName || conversationId, 'private', customName, customId]
      );
    }
  },

  getCustomInfo(userId, conversationId) {
    const result = getOne(
      'SELECT custom_name, custom_id FROM conversations WHERE user_id = ? AND conversation_id = ?',
      [userId, conversationId]
    );
    return result || { custom_name: null, custom_id: null };
  }
};

// Message operations
export const messageOps = {
  insert(userId, messageId, referenceMessageId, eventType, content, authorName, authorId, authorAvatar, authorBot, conversationId, isIncoming, faceText, timestamp) {
    return insert(
      'INSERT INTO messages (user_id, message_id, reference_message_id, event_type, content, author_name, author_id, author_avatar, author_bot, conversation_id, is_incoming, face_text, timestamp) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
      [userId, messageId, referenceMessageId, eventType, content, authorName, authorId, authorAvatar, authorBot ? 1 : 0, conversationId, isIncoming ? 1 : 0, faceText, timestamp]
    );
  },

  getByConversationId(userId, conversationId, limit, offset) {
    return getAll(
      'SELECT * FROM messages WHERE user_id = ? AND conversation_id = ? ORDER BY timestamp DESC LIMIT ? OFFSET ?',
      [userId, conversationId, limit, offset]
    );
  },

  getByUserId(userId, limit, offset) {
    return getAll(
      'SELECT * FROM messages WHERE user_id = ? ORDER BY timestamp DESC LIMIT ? OFFSET ?',
      [userId, limit, offset]
    );
  },

  getLatest(userId, limit) {
    return getAll(
      'SELECT * FROM messages WHERE user_id = ? ORDER BY timestamp DESC LIMIT ?',
      [userId, limit]
    );
  }
};

// Attachment operations
export const attachmentOps = {
  insert(messageId, url, contentType, filename, width, height) {
    return insert(
      'INSERT INTO message_attachments (message_id, url, content_type, filename, width, height) VALUES (?, ?, ?, ?, ?, ?)',
      [messageId, url, contentType, filename, width, height]
    );
  },

  getByMessageId(messageId) {
    return getAll('SELECT * FROM message_attachments WHERE message_id = ?', [messageId]);
  }
};

// Transaction for inserting message with attachments
export function insertMessageWithAttachments(messageData, attachments) {
  const dbMessageId = messageOps.insert(
    messageData.userId,
    messageData.messageId || null,
    messageData.referenceMessageId || null,
    messageData.eventType,
    messageData.content,
    messageData.authorName,
    messageData.authorId,
    messageData.authorAvatar,
    messageData.authorBot || false,
    messageData.conversationId,
    messageData.isIncoming,
    messageData.faceText,
    messageData.timestamp
  );

  if (attachments && attachments.length > 0) {
    for (const attachment of attachments) {
      attachmentOps.insert(
        dbMessageId,
        attachment.url,
        attachment.content_type || attachment.contentType,
        attachment.filename,
        attachment.width,
        attachment.height
      );
    }
  }

  return dbMessageId;
}

export default db;
