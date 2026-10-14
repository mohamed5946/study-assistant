import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/ai.dart';
import '../core/book_loader.dart';
import '../core/code_text.dart';
import '../core/glass_sheet.dart';
import '../core/l10n.dart';
import '../core/models.dart';
import '../core/nav.dart';
import '../core/store.dart';
import '../core/theme.dart';
import '../core/widgets.dart';
import 'library_screen.dart';

/// AI Assistant chat — light design per mockup:
/// header back+title+menu, pale user bubbles right, AI bubbles left with
/// blue avatar, suggestion chips, input bar with + button, Deep Think
/// dropdown and blue send button.
class AiChatScreen extends StatefulWidget {
  final String initialPrompt;
  const AiChatScreen({super.key, this.initialPrompt = ''});
  @override
  State<AiChatScreen> createState() => _AiChatScreenState();
}

class _AiChatScreenState extends State<AiChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  bool _sending = false;
  bool _deepThink = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialPrompt.isNotEmpty) {
      _input.text = widget.initialPrompt;
    }
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () {
            // When pushed (e.g. "ask about subject"), pop back; when tabbed,
            // go to the home tab.
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            } else {
              TabNav.go(0);
            }
          },
        ),
        title: Text(t('aiChat')),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: _menu,
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

  Future<void> _menu() async {
    await showGlassSheet(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.psychology_rounded,
                color: AppColors.primary),
            title: Text(t('aiStatus')),
            subtitle: Text(t('aiReady')),
          ),
          ListTile(
            leading: Icon(Icons.settings_rounded,
                color:
                    Theme.of(context).colorScheme.onSurfaceVariant),
            title: Text(t('openSettings')),
            onTap: () {
              Navigator.pop(context);
              TabNav.go(4, more: 'settings');
            },
          ),
          ListTile(
            leading:
                const Icon(Icons.delete_sweep_rounded, color: AppColors.error),
            title: Text(t('clearChat'),
                style: const TextStyle(color: AppColors.error)),
            onTap: () async {
              Navigator.pop(context);
              final confirmed = await confirmDelete(context);
              if (confirmed) {
                await DB.chat.clear();
                if (mounted) showSnack(context, t('chatCleared'));
              }
            },
          ),
        ],
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
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary]),
                boxShadow: [
                  BoxShadow(
                      color:
                          AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 24)
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 44),
            ),
            const SizedBox(height: 18),
            Text(t('noApiKey'),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 8),
            Text(t('noApiKeyMsg'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant)),
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
        Expanded(
          child: msgs.isEmpty
              ? _emptyState()
              : ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [
                  AppColors.primary,
                  AppColors.primaryDark
                ]),
                boxShadow: [
                  BoxShadow(
                      color:
                          AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 20)
                ],
              ),
              child: const Icon(Icons.auto_awesome_rounded,
                  color: Colors.white, size: 36),
            ),
            const SizedBox(height: 16),
            Text(t('aiChat'),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 20)),
            const SizedBox(height: 6),
            Text(t('aiDisclaimer'),
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 13)),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _csSuggestion(
                    t('explainThisCode'), '${t('explainThisCode')}:\n'),
                _csSuggestion(
                    t('helpMeDebug'), '${t('helpMeDebug')}:\n'),
                _csSuggestion(
                    t('practicalExample'), '${t('practicalExample')}: '),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// CS suggestion chip: fills the input with the prompt and focuses it
  /// so the user can paste his code / topic, then hit send.
  Widget _csSuggestion(String label, String prefix) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () {
        _input.text = prefix;
        _input.selection = TextSelection.fromPosition(
            TextPosition(offset: _input.text.length));
        _focus.requestFocus();
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? Colors.white.withValues(alpha: 0.10)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25)),
          boxShadow: [
            BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3)),
          ],
        ),
        child: Text(label,
            style: TextStyle(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white
                    : AppColors.primaryDark,
                fontWeight: FontWeight.w600,
                fontSize: 13)),
      ),
    );
  }

  Widget _thinkingBubble() {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _aiAvatar(),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                    color:
                        AppColors.primary.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: const SizedBox(
                width: 110, child: Center(child: BookLoader(size: 56))),
          ),
        ],
      ),
    );
  }

  Widget _aiAvatar() {
    return Container(
      width: 34,
      height: 34,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primaryDark]),
      ),
      child: const Icon(Icons.auto_awesome_rounded,
          color: Colors.white, size: 18),
    );
  }

  Widget _bubble(ChatMessage m) {
    final user = m.role == 0;
    if (user) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: GestureDetector(
          onLongPress: () {
            Clipboard.setData(ClipboardData(text: m.text));
            showSnack(context, t('copied'));
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width * 0.78),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.10),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(18),
                bottomRight: Radius.circular(4),
              ),
            ),
            child: Text(m.text,
                style: const TextStyle(
                    fontSize: 14.5, height: 1.6)),
          ),
        ),
      );
    }
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _aiAvatar(),
          const SizedBox(width: 8),
          Flexible(
            child: GestureDetector(
              onLongPress: () {
                Clipboard.setData(ClipboardData(text: m.text));
                showSnack(context, t('copied'));
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(18),
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                  boxShadow: [
                    BoxShadow(
                        color: AppColors.primary
                            .withValues(alpha: 0.08),
                        blurRadius: 10,
                        offset: const Offset(0, 4)),
                  ],
                ),
                child: CodeAwareText(
                    text: m.text,
                    style: const TextStyle(
                        fontSize: 14.5, height: 1.6)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _inputBar() {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final deepBlue =
        dark ? AppColors.pink : AppColors.primaryDark; // readable in both
    return SafeArea(
      top: false,
      // Reserve shell nav-bar space only when tabbed; when pushed there is
      // no bottom nav and the dead space looks broken.
      child: Padding(
        padding: EdgeInsets.fromLTRB(
            16, 4, 16, Navigator.canPop(context) ? 16 : 84),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Deep Think dropdown row
            Row(
              children: [
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () =>
                      setState(() => _deepThink = !_deepThink),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: _deepThink
                          ? AppColors.primary.withValues(alpha: 0.14)
                          : Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppColors.primary
                              .withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                            _deepThink
                                ? Icons.psychology_rounded
                                : Icons.psychology_outlined,
                            size: 16,
                            color: deepBlue),
                        const SizedBox(width: 6),
                        Text(t('deepThink'),
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: deepBlue)),
                        Icon(
                            _deepThink
                                ? Icons.check_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 16,
                            color: deepBlue),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).brightness ==
                              Brightness.dark
                          ? Colors.white.withValues(alpha: 0.10)
                          : Colors.white),
                  child: IconButton(
                    icon: Icon(Icons.add_rounded,
                        color: Theme.of(context).brightness ==
                                Brightness.dark
                            ? Colors.white
                            : AppColors.primaryDark),
                    tooltip: t('askAboutPdf'),
                    onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) =>
                                const LibraryScreen())),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary
                                .withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4)),
                      ],
                    ),
                    child: TextField(
                      controller: _input,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: t('askAnything'),
                        border: InputBorder.none,
                        contentPadding:
                            const EdgeInsets.symmetric(
                                horizontal: 18, vertical: 12),
                        suffixIcon: _sending
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: BookLoader(size: 22),
                              )
                            : null,
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [
                      AppColors.primary,
                      AppColors.primaryDark
                    ]),
                    boxShadow: [
                      BoxShadow(
                          color: AppColors.primary
                              .withValues(alpha: 0.4),
                          blurRadius: 12)
                    ],
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded,
                        color: Colors.white),
                    onPressed: _sending ? null : _send,
                  ),
                ),
              ],
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
      final sys = AiService.systemPrompt() +
          (_deepThink
              ? (Settings.lang == 'ar'
                  ? '\nوضع التفكير العميق: فكّر بعمق خطوة بخطوة واشرح استدلالك قبل الإجابة النهائية.'
                  : '\nDeep Think mode: reason deeply step by step and explain your reasoning before the final answer.')
              : '');
      final reply = await provider.chat(
        [
          for (final m in history.take(20))
            AiMsg(m.role == 0 ? 'user' : 'assistant', m.text),
        ],
        system: sys,
      );
      await DB.chat.put(aId,
          ChatMessage(id: aId, role: 1, text: reply, createdMs: now + 1));
    } catch (e) {
      if (mounted) {
        // Surface the real failure (API status/message or network detail)
        // after the friendly prefix — diagnostic, not just "failed".
        final detail = e is AiException ? e.message : e.toString();
        showSnack(context, '${t('sendFailed')}\n$detail', error: true);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollDown();
    }
  }
}
