import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ignore: constant_identifier_names
const WS_IP_PORT = 'ws://192.168.112.145:3000';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chat Client with Riverpod',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const WebSocketClient(),
    );
  }
}

// Input text controllers providers
final channelIdProvider = StateProvider((ref) => TextEditingController());
final channelPasswordProvider = StateProvider((ref) => TextEditingController());
final userIdProvider = StateProvider((ref) => TextEditingController());
final messageProvider = StateProvider((ref) => TextEditingController());

// Define a ChatMessage class to hold user ID and message
class ChatMessage {
  final String userId;
  final String message;

  ChatMessage({required this.userId, required this.message});
}

// WebSocket state provider
final webSocketProvider =
    StateNotifierProvider<WebSocketController, WebSocketState>((ref) {
  return WebSocketController(ref);
});

// State class for WebSocket
class WebSocketState {
  final bool isConnected;
  final List<ChatMessage> messages; // Store chat messages with user IDs
  final String? error;
  final bool isCreator; // Whether the user is the creator of the channel

  WebSocketState({
    required this.isConnected,
    required this.messages,
    this.error,
    required this.isCreator,
  });

  WebSocketState copyWith({
    bool? isConnected,
    List<ChatMessage>? messages,
    String? error,
    bool? isCreator,
  }) {
    return WebSocketState(
      isConnected: isConnected ?? this.isConnected,
      messages: messages ?? this.messages,
      error: error,
      isCreator: isCreator ?? this.isCreator,
    );
  }
}

// StateNotifier for managing WebSocket connection
class WebSocketController extends StateNotifier<WebSocketState> {
  final Ref ref;
  WebSocketChannel? channel;

  WebSocketController(this.ref)
      : super(WebSocketState(
          isConnected: false,
          messages: [],
          error: null,
          isCreator: false,
        ));

  void createChat() {
    final channelId = ref.read(channelIdProvider).text;
    final channelPassword = ref.read(channelPasswordProvider).text;
    final userId = ref.read(userIdProvider).text;

    if (channelId.isEmpty || channelPassword.isEmpty || userId.isEmpty) {
      state = state.copyWith(
          error: 'Please enter channel ID, password, and user ID.');
      return;
    }

    if (state.isConnected) {
      state = state.copyWith(
          error: 'You are already connected to a channel. Disconnect first.');
      return;
    }

    if (WS_IP_PORT.isEmpty) {
      state = state.copyWith(error: 'WebSocket URL not configured properly.');
      return;
    }

    channel = WebSocketChannel.connect(Uri.parse(WS_IP_PORT));

    // Send createChat message
    channel!.sink.add(jsonEncode({
      'action': 'createChat',
      'channelId': channelId,
      'channelPassword': channelPassword,
      'userId': userId,
    }));

    // Listen for responses
    channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        //
        if (data['error'] != null) {
          state = state.copyWith(error: data['error']);
        } else
        //
        if (data['action'] == 'message') {
          // Append new message with user ID
          final chatMessage = ChatMessage(
            userId: data['userId'] ?? 'Unknown',
            message: data['message'],
          );
          state = state.copyWith(messages: [...state.messages, chatMessage]);
        } else
        //
        if (data['action'] == 'channelCreated') {
          state = WebSocketState(
            isConnected: true,
            messages: [],
            error: null,
            isCreator: true,
          );
        } else
        //
        if (data['action'] == 'channelDeleted') {
          disconnect();
        } else
        //
        if (data['action'] == 'userDisconnected') {
          final chatMessage = ChatMessage(
            userId: 'System',
            message: data['message'],
          );
          state = state.copyWith(messages: [...state.messages, chatMessage]);
        }
      },
      onDone: () {
        disconnect();
      },
      onError: (error) {
        state = state.copyWith(error: 'Connection error: $error');
      },
    );
  }

  void deleteChannel() {
    if (!state.isConnected || !state.isCreator || channel == null) {
      state = state.copyWith(
          error: 'You are not connected as creator to delete the channel.');
      return;
    }

    final channelId = ref.read(channelIdProvider).text;
    final channelPassword = ref.read(channelPasswordProvider).text;
    final userId = ref.read(userIdProvider).text;

    channel!.sink.add(jsonEncode({
      'action': 'deleteChannel',
      'channelId': channelId,
      'channelPassword': channelPassword,
      'userId': userId,
    }));
  }

  void connect() {
    final channelId = ref.read(channelIdProvider).text;
    final channelPassword = ref.read(channelPasswordProvider).text;
    final userId = ref.read(userIdProvider).text;

    if (channelId.isEmpty || channelPassword.isEmpty || userId.isEmpty) {
      state = state.copyWith(
          error: 'Please enter channel ID, password, and user ID.');
      return;
    }

    if (state.isConnected) {
      state = state.copyWith(
          error: 'You are already connected to a channel. Disconnect first.');
      return;
    }

    if (WS_IP_PORT.isEmpty) {
      state = state.copyWith(error: 'WebSocket URL not configured properly.');
      return;
    }

    channel = WebSocketChannel.connect(Uri.parse(WS_IP_PORT));

    // Send connect message
    channel!.sink.add(jsonEncode({
      'action': 'connect',
      'channelId': channelId,
      'channelPassword': channelPassword,
      'userId': userId,
    }));

    // Listen for responses
    channel!.stream.listen(
      (message) {
        final data = jsonDecode(message);
        //
        if (data['error'] != null) {
          state = state.copyWith(error: data['error']);
        } else
        //
        if (data['action'] == 'message') {
          // Append new message with user ID
          final chatMessage = ChatMessage(
            userId: data['userId'] ?? 'Unknown',
            message: data['message'],
          );
          state = state.copyWith(messages: [...state.messages, chatMessage]);
        } else
        //
        if (data['action'] == 'connected') {
          state = WebSocketState(
            isConnected: true,
            messages: [],
            error: null,
            isCreator: false,
          );
        } else
        //
        if (data['action'] == 'channelDeleted') {
          disconnect();
        } else
        //
        if (data['action'] == 'userDisconnected') {
          final chatMessage = ChatMessage(
            userId: 'System',
            message: data['message'],
          );
          state = state.copyWith(messages: [...state.messages, chatMessage]);
        }
      },
      onDone: () {
        disconnect();
      },
      onError: (error) {
        state = state.copyWith(error: 'Connection error: $error');
      },
    );
  }

  void disconnect() {
    if (state.isConnected && channel != null) {
      final channelId = ref.read(channelIdProvider).text;
      final userId = ref.read(userIdProvider).text;
      channel!.sink.add(jsonEncode({
        'action': 'disconnect',
        'channelId': channelId,
        'userId': userId,
      }));
      channel!.sink.close();
      state = WebSocketState(
        isConnected: false,
        messages: [],
        error: null,
        isCreator: false,
      );
    }
  }

  void sendMessage() {
    if (state.isConnected && channel != null) {
      final messageText = ref.read(messageProvider).text;
      final channelId = ref.read(channelIdProvider).text;
      final userId = ref.read(userIdProvider).text;

      if (messageText.isEmpty) {
        return;
      }

      channel!.sink.add(jsonEncode({
        'action': 'sendMessage',
        'channelId': channelId,
        'userId': userId,
        'message': messageText,
      }));

      // Clear the message input field
      ref.read(messageProvider).text = '';
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

class WebSocketClient extends ConsumerStatefulWidget {
  const WebSocketClient({super.key});

  @override
  ConsumerState<WebSocketClient> createState() => _WebSocketClientState();
}

class _WebSocketClientState extends ConsumerState<WebSocketClient> {
  late final ScrollController _scrollController;
  int _previousMessageCount = 0; // Keep track of previous message count

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final channelIdController = ref.watch(channelIdProvider);
    final channelPasswordController = ref.watch(channelPasswordProvider);
    final userIdController = ref.watch(userIdProvider);
    final messageController = ref.watch(messageProvider);
    final webSocketState = ref.watch(webSocketProvider);

    // Scroll to bottom if new messages are added
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (webSocketState.messages.length > _previousMessageCount) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        _previousMessageCount = webSocketState.messages.length;
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Chat Client with Riverpod')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            // User Data Section
            ExpansionTile(
              title: const Text('User Data'),
              initiallyExpanded: true,
              children: [
                TextFormField(
                  controller: channelIdController,
                  decoration: const InputDecoration(labelText: 'Channel ID'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: channelPasswordController,
                  decoration:
                      const InputDecoration(labelText: 'Channel Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: userIdController,
                  decoration: const InputDecoration(labelText: 'User ID'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // User Actions Section
            ExpansionTile(
              title: const Text('User Actions'),
              initiallyExpanded: true,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: webSocketState.isConnected
                          ? null
                          : () =>
                              ref.read(webSocketProvider.notifier).createChat(),
                      child: const Text('Create Chat'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed:
                          webSocketState.isConnected && webSocketState.isCreator
                              ? () => ref
                                  .read(webSocketProvider.notifier)
                                  .deleteChannel()
                              : null,
                      child: const Text('Delete Channel'),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton(
                      onPressed: webSocketState.isConnected
                          ? null
                          : () =>
                              ref.read(webSocketProvider.notifier).connect(),
                      child: const Text('Connect'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: webSocketState.isConnected
                          ? () =>
                              ref.read(webSocketProvider.notifier).disconnect()
                          : null,
                      child: const Text('Disconnect'),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),
            if (webSocketState.error != null)
              Text(
                'Error: ${webSocketState.error}',
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 16),
            if (webSocketState.isConnected) ...[
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: webSocketState.messages.length,
                  itemBuilder: (context, index) {
                    final chatMessage = webSocketState.messages[index];
                    return ListTile(
                      title: Text(
                        '${chatMessage.userId}: ${chatMessage.message}',
                        style: TextStyle(
                          fontWeight: chatMessage.userId ==
                                  ref.read(userIdProvider).text
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    );
                  },
                ),
              ),
              TextFormField(
                controller: messageController,
                decoration: const InputDecoration(labelText: 'Message'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () =>
                    ref.read(webSocketProvider.notifier).sendMessage(),
                child: const Text('Send Message'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
