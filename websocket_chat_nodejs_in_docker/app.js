const express = require('express');
const WebSocket = require('ws');
const http = require('http');

const app = express();
const server = http.createServer(app);
const wss = new WebSocket.Server({ server });

const PORT = process.env.PORT || 3000;

app.use(express.json());

// Channels data structure
const channels = {}; // Map of channelId to channel info

// Each channel info:
// {
//   channelPassword: 'password',
//   creatorUserId: 'userId',
//   clients: [ws1, ws2, ...],
//   userIds: new Map([[ws1, 'user1'], [ws2, 'user2']]) // Map clients to user IDs
// }

wss.on('connection', (ws) => {
  ws.on('message', async (message) => {
    try {
      const data = JSON.parse(message);
      const action = data.action;

      if (action === 'createChat') {
        const { channelId, channelPassword, userId } = data;
        if (!channelId || !channelPassword || !userId) {
          ws.send(JSON.stringify({ error: 'Missing channelId, channelPassword, or userId' }));
          return;
        }

        if (channels[channelId]) {
          ws.send(JSON.stringify({ error: 'Channel ID already exists' }));
          return;
        }

        // Check if user is already connected to another channel
        if (isUserConnected(ws)) {
          ws.send(JSON.stringify({ error: 'You are already connected to another channel. Disconnect first.' }));
          return;
        }

        // Create new channel
        channels[channelId] = {
          channelPassword: channelPassword,
          creatorUserId: userId,
          clients: [ws],
          userIds: new Map([[ws, userId]]),
        };

        ws.send(JSON.stringify({ action: 'channelCreated' }));
      } else 
      //
      if (action === 'connect') {
        const { channelId, channelPassword, userId } = data;
        if (!channelId || !channelPassword || !userId) {
          ws.send(JSON.stringify({ error: 'Missing channelId, channelPassword, or userId' }));
          return;
        }

        const channel = channels[channelId];
        if (!channel) {
          ws.send(JSON.stringify({ error: 'Channel does not exist' }));
          return;
        }

        if (channel.channelPassword !== channelPassword) {
          ws.send(JSON.stringify({ error: 'Incorrect channel password' }));
          return;
        }

        // Check if user is already connected to another channel
        if (isUserConnected(ws)) {
          ws.send(JSON.stringify({ error: 'You are already connected to another channel. Disconnect first.' }));
          return;
        }

        // Add user to channel
        channel.clients.push(ws);
        channel.userIds.set(ws, userId);

        ws.send(JSON.stringify({ action: 'connected' }));

        // Broadcast to other clients that user connected
        broadcastToChannel(channelId, {
          action: 'message',
          message: `${userId} connected`,
        }, ws);
      } else 
      //
      if (action === 'sendMessage') {
        const { channelId, userId, message: messageText } = data;
        if (!channelId || !userId || !messageText) {
          ws.send(JSON.stringify({ error: 'Missing channelId, userId, or message' }));
          return;
        }
      
        const channel = channels[channelId];
        if (!channel) {
          ws.send(JSON.stringify({ error: 'Channel does not exist' }));
          return;
        }
      
        if (!channel.clients.includes(ws)) {
          ws.send(JSON.stringify({ error: 'You are not connected to this channel' }));
          return;
        }
      
        // Broadcast message to all clients in channel
        broadcastToChannel(channelId, {
          action: 'message',
          userId: userId,
          message: messageText,
        });
      }
      //
      else if (action === 'disconnect') {
        const { channelId, userId } = data;
        if (!channelId || !userId) {
          ws.send(JSON.stringify({ error: 'Missing channelId or userId' }));
          return;
        }

        const channel = channels[channelId];
        if (!channel) {
          ws.send(JSON.stringify({ error: 'Channel does not exist' }));
          return;
        }

        if (!channel.clients.includes(ws)) {
          ws.send(JSON.stringify({ error: 'You are not connected to this channel' }));
          return;
        }

        // Remove client from channel
        channel.clients = channel.clients.filter(client => client !== ws);
        channel.userIds.delete(ws);

        // Notify others that user disconnected
        broadcastToChannel(channelId, {
          action: 'userDisconnected',
          message: `${userId} disconnected`,
        }, ws);

        ws.send(JSON.stringify({ action: 'disconnected' }));

        // Close WebSocket
        ws.close();

        // If no more clients, delete channel
        if (channel.clients.length === 0) {
          delete channels[channelId];
        }
      } else if (action === 'deleteChannel') {
        const { channelId, channelPassword, userId } = data;
        if (!channelId || !channelPassword || !userId) {
          ws.send(JSON.stringify({ error: 'Missing channelId, channelPassword, or userId' }));
          return;
        }

        const channel = channels[channelId];
        if (!channel) {
          ws.send(JSON.stringify({ error: 'Channel does not exist' }));
          return;
        }

        if (channel.channelPassword !== channelPassword) {
          ws.send(JSON.stringify({ error: 'Incorrect channel password' }));
          return;
        }

        if (channel.creatorUserId !== userId) {
          ws.send(JSON.stringify({ error: 'Only the creator can delete the channel' }));
          return;
        }

        // Notify all clients in channel
        broadcastToChannel(channelId, {
          action: 'channelDeleted',
          message: 'Channel has been deleted by the creator',
        });

        // Close all client connections
        channel.clients.forEach(client => {
          client.close();
        });

        // Delete channel
        delete channels[channelId];
      } else {
        ws.send(JSON.stringify({ error: 'Unknown action' }));
      }
    } catch (error) {
      console.error('Error processing message:', error.message);
      ws.send(JSON.stringify({ error: 'An error occurred while processing your request.' }));
    }
  });

  ws.on('close', () => {
    // Handle user disconnect
    for (const channelId in channels) {
      const channel = channels[channelId];
      if (channel.clients.includes(ws)) {
        const userId = channel.userIds.get(ws);
        channel.clients = channel.clients.filter(client => client !== ws);
        channel.userIds.delete(ws);

        // Notify others that user disconnected
        broadcastToChannel(channelId, {
          action: 'userDisconnected',
          message: `${userId} disconnected`,
        }, ws);

        // If no more clients, delete channel
        if (channel.clients.length === 0) {
          delete channels[channelId];
        }
        break;
      }
    }
  });
});

// Helper functions
function broadcastToChannel(channelId, data, excludeWs = null) {
  const channel = channels[channelId];
  if (!channel) return;

  channel.clients.forEach(client => {
    if (client.readyState === WebSocket.OPEN && client !== excludeWs) {
      client.send(JSON.stringify(data));
    }
  });
}

function isUserConnected(ws) {
  for (const channelId in channels) {
    const channel = channels[channelId];
    if (channel.clients.includes(ws)) {
      return true;
    }
  }
  return false;
}

// Start the server
server.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
