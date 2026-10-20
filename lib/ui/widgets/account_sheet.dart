import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../services/cloud_sync.dart';
import '../../state/app_state.dart';

/// 계정 로그인/회원가입 시트. 이메일 + 비밀번호.
class AccountSheet extends StatefulWidget {
  const AccountSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const AccountSheet(),
      );

  @override
  State<AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<AccountSheet> {
  final _email = TextEditingController();
  final _pw = TextEditingController();
  bool _create = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pw.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await state.cloudSignIn(_email.text, _pw.text, create: _create);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on CloudException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '오류: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reset() async {
    if (_email.text.trim().isEmpty) {
      setState(() => _error = '이메일을 먼저 입력하세요.');
      return;
    }
    try {
      await context.read<AppState>().cloudResetPassword(_email.text);
      if (mounted) setState(() => _error = '비밀번호 재설정 메일을 보냈어요.');
    } on CloudException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_create ? '계정 만들기' : '계정 로그인', style: text.titleLarge),
          const SizedBox(height: 4),
          Text('계정에 로그인하면 폰·노트북 어디서 열어도 같은 데이터를 봅니다.',
              style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 16),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(labelText: '이메일', prefixIcon: Icon(Icons.mail_outline)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pw,
            obscureText: true,
            decoration: const InputDecoration(labelText: '비밀번호 (6자 이상)', prefixIcon: Icon(Icons.lock_outline)),
            onSubmitted: (_) => _busy ? null : _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: cs.error)),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            child: _busy
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_create ? '가입하고 동기화 시작' : '로그인'),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: () => setState(() => _create = !_create),
                child: Text(_create ? '이미 계정이 있어요' : '계정이 없어요 (가입)'),
              ),
              if (!_create) TextButton(onPressed: _reset, child: const Text('비밀번호 찾기')),
            ],
          ),
        ],
      ),
    );
  }
}

/// 내 정보 화면의 계정/동기화 섹션.
class AccountSection extends StatelessWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    if (!state.cloudAvailable) {
      return const ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.cloud_off),
        title: Text('계정 동기화'),
        subtitle: Text('아직 설정되지 않음 (이 기기에만 저장)'),
      );
    }
    if (!state.cloudSignedIn) {
      return ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.cloud_outlined, color: cs.primary),
        title: const Text('계정 로그인 / 가입'),
        subtitle: const Text('어느 기기에서든 같은 데이터 보기'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => AccountSheet.show(context),
      );
    }
    final last = state.lastSyncedAt;
    final status = state.syncError ??
        (state.syncing
            ? '동기화 중…'
            : last == null
                ? '로그인됨 · 변경 시 자동 동기화'
                : '마지막 동기화 ${last.hour.toString().padLeft(2, '0')}:${last.minute.toString().padLeft(2, '0')}');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: Icon(state.syncing ? Icons.cloud_sync : Icons.cloud_done, color: cs.primary),
          title: Text(state.cloudEmail ?? '계정'),
          subtitle: Text(status,
              style: text.bodySmall?.copyWith(color: state.syncError != null ? cs.error : cs.onSurfaceVariant)),
          trailing: IconButton(
            tooltip: '지금 동기화',
            icon: const Icon(Icons.sync),
            onPressed: state.syncing
                ? null
                : () async {
                    final msg = await state.syncNow();
                    if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  },
          ),
        ),
        TextButton.icon(
          onPressed: () async {
            final ok = await showDialog<bool>(
              context: context,
              builder: (c) => AlertDialog(
                title: const Text('계정에서 로그아웃'),
                content: const Text('이 기기의 데이터는 그대로 남고, 자동 동기화만 멈춥니다.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('취소')),
                  FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('로그아웃')),
                ],
              ),
            );
            if (ok == true) await state.cloudSignOut();
          },
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('계정 로그아웃'),
        ),
      ],
    );
  }
}
