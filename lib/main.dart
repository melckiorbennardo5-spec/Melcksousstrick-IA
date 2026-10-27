import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MelcksousstrickApp());
}

class MelcksousstrickApp extends StatelessWidget {
  const MelcksousstrickApp({super.key});

  @override
  Widget build(BuildContext context) {
    const neon = Color(0xFF42F58D);
    return MaterialApp(
      title: 'Melcksousstrick',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF070B09),
        colorScheme: const ColorScheme.dark(
          primary: neon,
          secondary: Color(0xFF9CFFC2),
          surface: Color(0xFF101713),
        ),
        useMaterial3: true,
        fontFamily: 'monospace',
      ),
      home: const CodeAssistantScreen(),
    );
  }
}

class ChatMessage {
  const ChatMessage({required this.text, required this.isUser});

  final String text;
  final bool isUser;
}

class CodeAssistantScreen extends StatefulWidget {
  const CodeAssistantScreen({super.key});

  @override
  State<CodeAssistantScreen> createState() => _CodeAssistantScreenState();
}

class _CodeAssistantScreenState extends State<CodeAssistantScreen> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isThinking = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? _controller.text).trim();
    if (text.isEmpty || _isThinking) return;

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isThinking = true;
      _controller.clear();
    });
    _focusNode.requestFocus();
    _scrollToBottom();

    // Réponses locales de démonstration : aucun modèle d'IA n'est connecté.
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      _messages.add(ChatMessage(
        text: DemoAssistant.respond(text),
        isUser: false,
      ));
      _isThinking = false;
    });
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  void _newConversation() {
    setState(() {
      _messages.clear();
      _isThinking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF090E0B),
        surfaceTintColor: Colors.transparent,
        titleSpacing: 18,
        title: const Row(
          children: [
            _BrandMark(),
            SizedBox(width: 11),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('MELCKSOUSSTRICK',
                    style: TextStyle(
                      fontSize: 14,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800,
                    )),
                SizedBox(height: 3),
                Text('ASSISTANT DE CODE · DÉMO',
                    style: TextStyle(
                      color: Color(0xFF8A9B90),
                      fontSize: 9,
                      letterSpacing: 1.1,
                    )),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Nouvelle conversation',
            onPressed: _newConversation,
            icon: const Icon(Icons.add_comment_outlined),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          const _DemoNotice(),
          Expanded(
            child: _messages.isEmpty
                ? _WelcomeView(onSuggestionTap: _send)
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 20, 16, 18),
                    itemCount: _messages.length + (_isThinking ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index == _messages.length) {
                        return const _ThinkingIndicator();
                      }
                      return _MessageBubble(message: _messages[index]);
                    },
                  ),
          ),
          _Composer(
            controller: _controller,
            focusNode: _focusNode,
            onSend: _send,
          ),
        ],
      ),
    );
  }
}

class DemoAssistant {
  static String respond(String request) {
    final normalized = request.toLowerCase();
    if (normalized.contains('flutter') || normalized.contains('bouton')) {
      return '''Voici un petit exemple Flutter :

```dart
FilledButton(
  onPressed: () {
    debugPrint('Bonjour !');
  },
  child: const Text('Appuyer'),
)
