import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/ai.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/nav.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';

class AiChatScreen extends StatefulWidget {
  const AiChatScreen({super.key});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollDown() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (_scroll.hasClients) {
        _scroll.animateTo(_scroll.position.maxScrollExtent,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOut);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(t('aiChat')),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: t('clearChat'),
            onPressed: () async {
              if (await confirmDelete(context, message: t('clearChat'))) {
                await DB.chat.clear();
                if (context.mounted) {
                  showSnack(context, t('chatCleared'));
                }
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () => TabNav.go(4, more: 'settings'),
          ),
        ],
      ),
      body: AuroraBackground(
        child: ValueListenableBuilder(
          valueListenable: DB.kv.listenable(keys: ['aiKey']),
          builder: (_, __, ___) {
            if (!Settings.hasAiKey) return _noKey(context);
            return ValueListenableBuilder(
              valueListenable: DB.chat.listenable(),
              builder: (_, __, ___) => _chatBody(context),
            );
          },
        ),
      ),
    );
  }

  Widget _noKey(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [AppColors.violet, AppColors.primary]),
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 18),
            Text(t('noApiKey'),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 8),
            Text(t('noApiKeyMsg'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
            const SizedBox(height: 18),
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.key_rounded,
                          color: AppColors.warning),
                      const SizedBox(width: 8),
                      Text(t('getFreeKey'),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(t('freeKeySteps'),
                      style: const TextStyle(fontSize: 13, height: 1.7)),
                ],
              ),
            ),
            const SizedBox(height: 18),
            GlassButton(
              label: t('openSettings'),
              icon: Icons.settings_rounded,
              onPressed: () => TabNav.go(4, more: 'settings'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chatBody(BuildContext context) {
    final msgs = DB.chat.values.toList()
      ..sort((a, b) => a.createdMs.compareTo(b.createdMs));
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  size: 14, color: AppColors.warning),
              const SizedBox(width: 6),
              Expanded(
                child: Text(t('aiDisclaimer'),
                    style: TextStyle(
                        fontSize: 11,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurfaceVariant)),
              ),
            ],
          ),
        ),
        Expanded(
          child: msgs.isEmpty
              ? Center(
                  child: Text(t('askAnything'),
                      style: TextStyle(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurfaceVariant)))
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  itemCount: msgs.length + (_sending ? 1 : 0),
                  itemBuilder: (_, i) {
                    if (i == msgs.length) return _thinkingBubble();
                    return _bubble(msgs[i]);
                  },
                ),
        ),
        _inputBar(),
      ],
    );
  }

  Widget _thinkingBubble() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .surfaceContainerHighest
              .withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(18),
        ),
        child: const SizedBox(width: 120, child: StudyLoadingBar()),
      ),
    );
  }

  Widget _bubble(ChatMessage m) {
    final user = m.role == 0;
    return Align(
      alignment:
          user ? AlignmentDirectional.centerEnd : AlignmentDirectional.centerStart,
      child: GestureDetector(
        onLongPress: () {
          Clipboard.setData(ClipboardData(text: m.text));
          showSnack(context, t('copied'));
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.82),
          decoration: BoxDecoration(
            gradient: user
                ? const LinearGradient(
                    colors: [AppColors.primary, AppColors.violet])
                : null,
            color: user
                ? null
                : Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Text(
            m.text,
            style: TextStyle(
              color: user
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
              fontSize: 14.5,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }

  Widget _inputBar() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _input,
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: t('askAnything'),
                  suffixIcon: _sending
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2)),
                        )
                      : null,
                ),
                onSubmitted: (_) => _send(),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.violet]),
              ),
              child: IconButton(
                icon: const Icon(Icons.send_rounded, color: Colors.white),
                onPressed: _sending ? null : _send,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty || _sending) return;
    final provider = AiService.current();
    if (provider == null) return;
    _input.clear();
    final now = DateTime.now().millisecondsSinceEpoch;
    final uId = newId(), aId = newId();
    await DB.chat.put(
        uId, ChatMessage(id: uId, role: 0, text: text, createdMs: now));
    setState(() => _sending = true);
    _scrollDown();
    try {
      final history = DB.chat.values.toList()
        ..sort((a, b) => a.createdMs.compareTo(b.createdMs));
      final reply = await provider.chat(
        [
          for (final m in history.take(20))
            AiMsg(m.role == 0 ? 'user' : 'assistant', m.text),
        ],
        system: AiService.systemPrompt(),
      );
      await DB.chat.put(aId,
          ChatMessage(id: aId, role: 1, text: reply, createdMs: now + 1));
    } catch (e) {
      if (mounted) {
        showSnack(
            context, e is AiException ? e.message : t('sendFailed'),
            error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollDown();
    }
  }
}
