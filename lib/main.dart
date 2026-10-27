import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

const String _model = 'gemini-3.8-flash';
const String _prefsKey = 'gemini_api_key';

// Trois accents graves, écrits en Unicode pour éviter de les taper à la main.
const String _fence = '\u0060\u0060\u0060';

final String _systemPrompt =
    'Tu es Melcksousstrick, un assistant de programmation. '
    'Réponds en français, de façon claire et concise. '
    'Mets tout code dans des blocs ${_fence}langage ... $_fence. '
    'N\'utilise pas d\'autre mise en forme markdown (pas de gras, pas de titres).';

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
  const ChatMessage({
    required this.text,
    required this.isUser,
    this.isError = false,
  });

  final String text;
  final bool isUser;
  final bool isError;
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
  String _apiKey = '';

  @override
  void initState() {
    super.initState();
    _loadKey();
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadKey() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _apiKey = prefs.getString(_prefsKey) ?? '');
  }

  Future<void> _editKey() async {
    final keyController = TextEditingController(text: _apiKey);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101713),
        title: const Text('Clé API Google Gemini', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Colle ta clé gratuite (aistudio.google.com). Elle reste uniquement sur ce téléphone.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9AA99F)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: keyController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(
                hintText: 'Ta clé API',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, keyController.text.trim()),
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
    if (result == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, result);
    if (!mounted) return;
    setState(() => _apiKey = result);
  }

  Future<String> _askClaude(List<ChatMessage> history) async {
    // Gemini veut des tours qui alternent : on fusionne les messages
    // consécutifs du même rôle (par ex. après une erreur).
    final contents = <Map<String, dynamic>>[];
    for (final m in history) {
      final role = m.isUser ? 'user' : 'model';
      if (contents.isNotEmpty && contents.last['role'] == role) {
        final parts = contents.last['parts'] as List;
        parts[0]['text'] = '${parts[0]['text']}\n\n${m.text}';
      } else {
        contents.add({
          'role': role,
          'parts': [
            {'text': m.text},
          ],
        });
      }
    }

    final response = await http
        .post(
          Uri.parse(
              'https://generativelanguage.googleapis.com/v1beta/models/$_model:generateContent'),
          headers: {
            'content-type': 'application/json',
            'x-goog-api-key': _apiKey,
          },
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': _systemPrompt},
              ],
            },
            'contents': contents,
          }),
        )
        .timeout(const Duration(seconds: 90));

    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      final message = (data is Map && data['error'] is Map)
          ? data['error']['message']
          : 'Erreur ${response.statusCode}';
      if (response.statusCode == 400 || response.statusCode == 403) {
        throw 'Clé refusée ou requête invalide ($message). '
            'Vérifie la clé avec l\'icône clé.';
      }
      if (response.statusCode == 429) {
        throw 'Limite gratuite atteinte. Réessaie dans une minute ou demain.';
      }
      throw '$message';
    }
    final candidates = (data['candidates'] as List?) ?? [];
    if (candidates.isEmpty) return '(réponse vide ou bloquée)';
    final parts = (candidates[0]['content']?['parts'] as List?) ?? [];
    final text = parts
        .where((p) => p is Map && p['text'] is String)
        .map((p) => p['text'] as String)
        .join('\n');
    return text.isEmpty ? '(réponse vide)' : text;
  }

  Future<void> _send([String? suggestion]) async {
    final text = (suggestion ?? _controller.text).trim();
    if (text.isEmpty || _isThinking) return;

    if (_apiKey.isEmpty) {
      await _editKey();
      if (_apiKey.isEmpty) return;
    }

    setState(() {
      _messages.add(ChatMessage(text: text, isUser: true));
      _isThinking = true;
      _controller.clear();
    });
    _focusNode.requestFocus();
    _scrollToBottom();

    final history = _messages.where((m) => !m.isError).toList();
    ChatMessage reply;
    try {
      reply = ChatMessage(text: await _askClaude(history), isUser: false);
    } catch (e) {
      reply = ChatMessage(
        text: 'Erreur : $e',
        isUser: false,
        isError: true,
      );
    }
    if (!mounted) return;
    setState(() {
      _messages.add(reply);
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
                Text('ASSISTANT DE CODE · IA',
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
            tooltip: 'Clé API',
            onPressed: _editKey,
            icon: const Icon(Icons.vpn_key_outlined),
          ),
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
          _KeyNotice(hasKey: _apiKey.isNotEmpty, onTap: _editKey),
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

class _KeyNotice extends StatelessWidget {
  const _KeyNotice({required this.hasKey, required this.onTap});

  final bool hasKey;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        color: hasKey ? const Color(0xFF102017) : const Color(0xFF2A2210),
        child: Row(
          children: [
            Icon(
              hasKey ? Icons.check_circle_outline : Icons.vpn_key_outlined,
              color: hasKey
                  ? const Color(0xFF8DFAB3)
                  : const Color(0xFFFFD27A),
              size: 15,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasKey
                    ? 'IA connectée · $_model'
                    : 'Aucune clé API : touche ici pour l\'ajouter.',
                style: TextStyle(
                  color: hasKey
                      ? const Color(0xFFB4D7C0)
                      : const Color(0xFFFFE2A8),
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
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
    final error = message.isError;
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
            color: error
                ? const Color(0xFFFF6B6B).withValues(alpha: .6)
                : user
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
            Text('Réflexion en cours…',
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
