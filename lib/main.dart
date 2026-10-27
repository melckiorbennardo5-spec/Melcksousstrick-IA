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

// Trois accents graves, écrits en Unicode pour éviter de les taper à la main.
const String _fence = '\u0060\u0060\u0060';

class DemoAssistant {
  static String respond(String request) {
    final normalized = request.toLowerCase();
    if (normalized.contains('flutter') || normalized.contains('bouton')) {
      return 'Voici un petit exemple Flutter :\n\n'
          '${_fence}dart\n'
          'FilledButton(\n'
          '  onPressed: () {\n'
          '    debugPrint("Bonjour !");\n'
          '  },\n'
          '  child: const Text("Appuyer"),\n'
          ')\n'
          '$_fence\n\n'
          'Ce bouton exécute une action lorsqu\'on appuie dessus. Ceci est une réponse prédéfinie de démonstration, pas une réponse générée par un modèle d\'IA.';
    }
    if (normalized.contains('explique') || normalized.contains('comprendre')) {
      return '''Colle le morceau de code que tu veux comprendre et précise ce qui te pose question.

Pour le moment, je fonctionne en mode démonstration : je ne peux pas analyser automatiquement du code ni contacter un modèle d'IA.''';
    }
    if (normalized.contains('corrige') || normalized.contains('erreur')) {
      return '''Colle le code et le message d'erreur complet pour préparer une correction.

Attention : cette version est une démo locale. Elle ne lance pas et ne vérifie pas réellement le code.''';
    }
    return '''J'ai bien reçu ta demande. Dans cette version de démonstration, mes réponses sont locales et prédéfinies ; aucun véritable modèle d'IA n'est connecté.

Tu peux essayer : « Donne-moi un exemple Flutter » ou « Explique-moi une erreur ».''';
  }
}

class _BrandMark extends StatelessWidget {
  const _BrandMark();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 35,
      height: 35,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(11),
        color: const Color(0xFF12251A),
        border: Border.all(
            color: const Color(0xFF42F58D).withValues(alpha: .45)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF42F58D).withValues(alpha: .12),
            blurRadius: 16,
          ),
        ],
      ),
      child: const Icon(Icons.terminal, color: Color(0xFF42F58D), size: 20),
    );
  }
}

class _DemoNotice extends StatelessWidget {
  const _DemoNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      color: const Color(0xFF102017),
      child: const Row(
        children: [
          Icon(Icons.info_outline, color: Color(0xFF8DFAB3), size: 15),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'MODE DÉMO — aucune IA réelle n’est encore connectée.',
              style: TextStyle(color: Color(0xFFB4D7C0), fontSize: 11),
            ),
          ),
        ],
      ),
    );
  }
}

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({required this.onSuggestionTap});

  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    final suggestions = [
      ('Exemple Flutter', 'Donne-moi un exemple Flutter avec un bouton'),
      ('Comprendre du code', 'Explique-moi comment comprendre du code'),
      ('Corriger une erreur', 'Comment corriger une erreur dans mon code ?'),
    ];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF0D1A12),
                  border: Border.all(
                      color: const Color(0xFF42F58D).withValues(alpha: .4)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF42F58D).withValues(alpha: .13),
                      blurRadius: 36,
                    ),
                  ],
                ),
                child: const Icon(Icons.code,
                    color: Color(0xFF65F99D), size: 34),
              ),
              const SizedBox(height: 23),
              const Text(
                'Ton atelier de code.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -.7,
                ),
              ),
              const SizedBox(height: 9),
              const Text(
                'Pose une question, colle un extrait de code\nou demande une explication.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFF9AA99F),
                  height: 1.6,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 27),
              ...suggestions.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: _SuggestionCard(
                      title: item.$1,
                      onTap: () => onSuggestionTap(item.$2),
                    ),
                  )),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({required this.title, required this.onTap});

  final String title;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFF101713),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFF26362C)),
          ),
          child: Row(
            children: [
              const Icon(Icons.arrow_outward,
                  color: Color(0xFF65F99D), size: 17),
              const SizedBox(width: 12),
              Expanded(
                child: Text(title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ),
              const Icon(Icons.chevron_right,
                  color: Color(0xFF718078), size: 19),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final user = message.isUser;
    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 620),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: user ? const Color(0xFF173321) : const Color(0xFF101713),
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: user ? const Radius.circular(4) : null,
            bottomLeft: user ? null : const Radius.circular(4),
          ),
          border: Border.all(
            color: user
                ? const Color(0xFF42F58D).withValues(alpha: .25)
                : const Color(0xFF26362C),
          ),
        ),
        child: _RichMessage(text: message.text),
      ),
    );
  }
}

class _RichMessage extends StatelessWidget {
  const _RichMessage({required this.text});

  final String text;
  static final _codePattern =
      RegExp('$_fence([^\\n]*)\\n([\\s\\S]*?)$_fence');

  @override
  Widget build(BuildContext context) {
    final spans = <Widget>[];
    var cursor = 0;
    for (final match in _codePattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(_paragraph(text.substring(cursor, match.start)));
      }
      final lang = match.group(1)?.trim() ?? '';
      spans.add(_CodeCard(
        language: lang.isNotEmpty ? lang : 'code',
        code: match.group(2)!.trimRight(),
      ));
      cursor = match.end;
    }
    if (cursor < text.length) spans.add(_paragraph(text.substring(cursor)));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: spans,
    );
  }

  Widget _paragraph(String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: SelectableText(
          value.trim(),
          style: const TextStyle(
            fontFamily: 'sans-serif',
            color: Color(0xFFE0E9E3),
            height: 1.5,
            fontSize: 13,
          ),
        ),
      );
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.language, required this.code});

  final String language;
  final String code;

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Code copié dans le presse-papiers'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF080C09),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFF2B4132)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 7, 7),
            child: Row(
              children: [
                Text(language.toUpperCase(),
                    style: const TextStyle(
                      color: Color(0xFF8BA996),
                      fontSize: 9,
                      letterSpacing: 1,
                    )),
                const Spacer(),
                TextButton.icon(
                  onPressed: () => _copy(context),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF78F5A5),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(Icons.copy, size: 13),
                  label: const Text('Copier', style: TextStyle(fontSize: 11)),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFF26362C)),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.all(12),
            child: SelectableText(
              code,
              style: const TextStyle(
                color: Color(0xFFB9F7CC),
                fontSize: 12,
                height: 1.55,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 14),
        child: Row(
          children: [
            SizedBox(
              width: 15,
              height: 15,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: Color(0xFF42F58D)),
            ),
            SizedBox(width: 10),
            Text('Préparation de la réponse…',
                style: TextStyle(color: Color(0xFF91A197), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
        decoration: const BoxDecoration(
          color: Color(0xFF090E0B),
          border: Border(top: BorderSide(color: Color(0xFF1E2A22))),
        ),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: onSend,
                    decoration: InputDecoration(
                      hintText: 'Écris ou colle ton code…',
                      hintStyle: const TextStyle(
                          color: Color(0xFF718078), fontSize: 13),
                      filled: true,
                      fillColor: const Color(0xFF101713),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 15, vertical: 13),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF29382E)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFF29382E)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                            color: Color(0xFF42F58D), width: 1.2),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                SizedBox(
                  height: 48,
                  width: 48,
                  child: FilledButton(
                    onPressed: () => onSend(controller.text),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF42F58D),
                      foregroundColor: const Color(0xFF061008),
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    child: const Icon(Icons.arrow_upward_rounded, size: 21),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
