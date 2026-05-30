import { WebSocketServer } from 'ws';
import { v4 as uuidv4 } from 'uuid';

// Store connected frontend clients by userId
const userClients = new Map();

let wss = null;

export function initWebSocket(server) {
  wss = new WebSocketServer({ server, path: '/ws' });

  wss.on('connection', (ws, req) => {
    const clientId = uuidv4();
    let userId = null;

    console.log(`[WS] Client connected: ${clientId}`);

    ws.on('message', (data) => {
      try {
        const message = JSON.parse(data.toString());
        handleClientMessage(ws, clientId, message);
      } catch (err) {
        console.error(`[WS] Error parsing message from ${clientId}:`, err);
      }
    });

    ws.on('close', () => {
      console.log(`[WS] Client disconnected: ${clientId}`);
      if (userId && userClients.has(userId)) {
        const clients = userClients.get(userId);
        clients.delete(clientId);
        if (clients.size === 0) {
          userClients.delete(userId);
        }
      }
    });

    ws.on('error', (err) => {
      console.error(`[WS] Client error ${clientId}:`, err.message);
    });

    // Send welcome message
    ws.send(JSON.stringify({
      type: 'connected',
      data: { clientId }
    }));
  });

  console.log('[WS] WebSocket server initialized');
  return wss;
}

function handleClientMessage(ws, clientId, message) {
  switch (message.type) {
    case 'auth': {
      const userId = message.data?.userId;
      if (userId) {
        // Register client for this user
        if (!userClients.has(userId)) {
          userClients.set(userId, new Map());
        }
        userClients.get(userId).set(clientId, ws);

        ws.send(JSON.stringify({
          type: 'auth_success',
          data: { userId }
        }));
        console.log(`[WS] Client ${clientId} authenticated for user ${userId}`);
      }
      break;
    }

    case 'ping': {
      ws.send(JSON.stringify({
        type: 'pong',
        data: { timestamp: Date.now() }
      }));
      break;
    }

    default:
      console.log(`[WS] Unknown message type: ${message.type}`);
  }
}

export function broadcastToUser(userId, message) {
  if (!userClients.has(userId)) {
    return;
  }

  const clients = userClients.get(userId);
  const messageStr = JSON.stringify(message);

  for (const [clientId, ws] of clients) {
    if (ws.readyState === ws.OPEN) {
      try {
        ws.send(messageStr);
      } catch (err) {
        console.error(`[WS] Error sending to client ${clientId}:`, err);
      }
    }
  }
}

export function getUserClientCount(userId) {
  if (!userClients.has(userId)) {
    return 0;
  }
  return userClients.get(userId).size;
}

export function closeAllConnections() {
  if (wss) {
    wss.close();
  }
}
