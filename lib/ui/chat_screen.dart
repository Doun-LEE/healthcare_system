import 'dart:math';

import 'package:flutter/material.dart';

import '../services/chat.dart';
import '../services/cloud_sync.dart';
import '../services/partner.dart';
import '../state/app_state.dart';
import 'package:provider/provider.dart';

/// 파트너와의 채팅. 후보 멘트 고르기, 이모티콘 폭탄, 직접 입력.
class PartnerChatScreen extends StatefulWidget {
  const PartnerChatScreen({super.key, required this.partner, required this.myName});
  final PartnerLink partner;
  final String myName;

  static Future<void> open(BuildContext context, PartnerLink partner) {
    if (!CloudSync.instance.signedIn) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('계정에 로그인해야 채팅할 수 있어요.')));
      return Future.value();
    }
    final myName = context.read<AppState>().currentUser?.name ?? '';
    return Navigator.of(context).push(MaterialPageRoute(builder: (_) => PartnerChatScreen(partner: partner, myName: myName)));
  }

  @override
  State<PartnerChatScreen> createState() => _PartnerChatScreenState();
}

class _PartnerChatScreenState extends State<PartnerChatScreen> with TickerProviderStateMixin {
  late final String _me = CloudSync.instance.user!.uid;
  late final String _pair = chatPairId(_me, widget.partner.uid);
  final _text = TextEditingController();
  final _seen = <String>{};
  bool _first = true;
  String _presetTab = chatPresets.keys.first;
  final _bursts = <_BurstRun>[];

  @override
  void dispose() {
    _text.dispose();
    for (final b in _bursts) {
      b.ctrl.dispose();
    }
    super.dispose();
  }

  Future<void> _send({String text = '', String emoji = '', int burst = 0}) async {
    if (text.trim().isEmpty && emoji.isEmpty) return;
    try {
      await CloudSync.instance.sendChat(_pair, text: text.trim(), emoji: emoji, burst: burst, fromName: widget.myName);
      _text.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('전송 실패: $e')));
    }
  }

  void _playBurst(String emoji, int count) {
    final ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));
    final run = _BurstRun(emoji: emoji, count: count.clamp(1, 60), ctrl: ctrl, seed: Random().nextInt(1 << 30));
    setState(() => _bursts.add(run));
    ctrl.forward().whenComplete(() {
      if (mounted) setState(() => _bursts.remove(run));
      ctrl.dispose();
    });
  }

  @override
  void initState() {
    super.initState();
    // 열자마자 읽음 처리(친구 목록의 안 읽음 배지가 사라진다).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().markChatRead(widget.partner);
    });
  }

  void _onMessages(List<ChatMessage> msgs) {
    // 처음 열 때는 과거 폭탄을 재생하지 않는다. 그 뒤 새로 온 폭탄만.
    var fresh = false;
    for (final m in msgs) {
      if (_seen.add(m.id) && !_first) {
        if (m.fromUid != _me) fresh = true;
        if (m.isEmoji && m.burst > 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _playBurst(m.emoji, m.burst));
        }
      }
    }
    _first = false;
    // 보고 있는 동안 온 메시지도 읽은 것으로.
    if (fresh) WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? context.read<AppState>().markChatRead(widget.partner) : null);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.partner.display)),
      body: Stack(children: [
        Column(children: [
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: CloudSync.instance.chatStream(_pair),
              builder: (c, snap) {
                if (snap.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('채팅을 불러오지 못했어요.\n${snap.error}', textAlign: TextAlign.center),
                    ),
                  );
                }
                final msgs = snap.data ?? const [];
                _onMessages(msgs);
                if (msgs.isEmpty) {
                  return Center(
                    child: Text('아직 메시지가 없어요.\n아래 멘트를 고르거나 이모티콘을 날려보세요.',
                        textAlign: TextAlign.center, style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  );
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                  itemCount: msgs.length,
                  itemBuilder: (c, i) => _Bubble(m: msgs[i], mine: msgs[i].fromUid == _me),
                );
              },
            ),
          ),
          _Composer(
            text: _text,
            presetTab: _presetTab,
            onTab: (t) => setState(() => _presetTab = t),
            onPreset: (s) => _send(text: s),
            onEmoji: (e) => _send(emoji: e, burst: 1),
            onBomb: (e) {
              _playBurst(e, 24);
              _send(emoji: e, burst: 24);
            },
            onSend: () => _send(text: _text.text),
          ),
        ]),
        for (final b in _bursts) Positioned.fill(child: IgnorePointer(child: _BurstView(run: b))),
      ]),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.m, required this.mine});
  final ChatMessage m;
  final bool mine;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final time = '${m.at.hour.toString().padLeft(2, '0')}:${m.at.minute.toString().padLeft(2, '0')}';
    final body = m.isEmoji
        ? Text(m.burst > 1 ? '${m.emoji} ×${m.burst}' : m.emoji, style: TextStyle(fontSize: m.burst > 1 ? 30 : 36))
        : Text(m.text, style: text.bodyLarge?.copyWith(color: mine ? cs.onPrimary : cs.onSurface));
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine) Padding(padding: const EdgeInsets.only(left: 6, top: 6), child: Text(m.fromName, style: text.labelSmall)),
          Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (mine) Padding(padding: const EdgeInsets.only(right: 4, bottom: 4), child: Text(time, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant))),
              Container(
                constraints: const BoxConstraints(maxWidth: 260),
                margin: const EdgeInsets.symmetric(vertical: 3),
                padding: m.isEmoji ? const EdgeInsets.symmetric(horizontal: 8, vertical: 2) : const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: m.isEmoji ? Colors.transparent : (mine ? cs.primary : cs.surfaceContainerHigh),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: body,
              ),
              if (!mine) Padding(padding: const EdgeInsets.only(left: 4, bottom: 4), child: Text(time, style: text.labelSmall?.copyWith(color: cs.onSurfaceVariant))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.text,
    required this.presetTab,
    required this.onTab,
    required this.onPreset,
    required this.onEmoji,
    required this.onBomb,
    required this.onSend,
  });
  final TextEditingController text;
  final String presetTab;
  final void Function(String) onTab, onPreset, onEmoji, onBomb;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Material(
      color: cs.surfaceContainerLow,
      child: SafeArea(
        top: false,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // 이모티콘: 탭 = 하나, 길게 = 폭탄
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final e in chatEmojis)
                  Tooltip(
                    message: '탭: 하나 · 길게: 폭탄',
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onEmoji(e),
                      onLongPress: () => onBomb(e),
                      child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), child: Text(e, style: const TextStyle(fontSize: 28))),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12, bottom: 2),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('길게 누르면 이모티콘 폭탄 💣', style: t.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ),
          ),
          // 후보 멘트
          SizedBox(
            height: 36,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8), children: [
              for (final k in chatPresets.keys)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(label: Text(k), selected: presetTab == k, onSelected: (_) => onTab(k), visualDensity: VisualDensity.compact),
                ),
            ]),
          ),
          SizedBox(
            height: 44,
            child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), children: [
              for (final s in chatPresets[presetTab]!)
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(label: Text(s), onPressed: () => onPreset(s), backgroundColor: cs.secondaryContainer, side: BorderSide.none),
                ),
            ]),
          ),
          // 직접 입력
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
            child: Row(children: [
              Expanded(
                child: TextField(
                  controller: text,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  decoration: InputDecoration(
                    hintText: '직접 입력',
                    isDense: true,
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filled(onPressed: onSend, icon: const Icon(Icons.send)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BurstRun {
  _BurstRun({required this.emoji, required this.count, required this.ctrl, required this.seed});
  final String emoji;
  final int count;
  final AnimationController ctrl;
  final int seed;
}

/// 이모티콘이 위에서 쏟아지는 연출.
class _BurstView extends StatelessWidget {
  const _BurstView({required this.run});
  final _BurstRun run;

  @override
  Widget build(BuildContext context) {
    final rnd = Random(run.seed);
    final parts = List.generate(run.count, (_) => (rnd.nextDouble(), rnd.nextDouble() * 0.5, 22 + rnd.nextDouble() * 26, rnd.nextDouble() * 2 - 1));
    return AnimatedBuilder(
      animation: run.ctrl,
      builder: (c, _) => LayoutBuilder(builder: (c, box) {
        final t = run.ctrl.value;
        return Stack(children: [
          for (final (x, delay, size, drift) in parts)
            if (t > delay)
              Positioned(
                left: x * box.maxWidth + drift * 40 * (t - delay),
                top: -40 + (box.maxHeight + 80) * Curves.easeIn.transform(((t - delay) / (1 - delay)).clamp(0, 1)),
                child: Opacity(
                  opacity: (1 - ((t - delay) / (1 - delay))).clamp(0.15, 1).toDouble(),
                  child: Text(run.emoji, style: TextStyle(fontSize: size)),
                ),
              ),
        ]);
      }),
    );
  }
}
