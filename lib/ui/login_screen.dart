import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/cloud_sync.dart';
import '../state/app_state.dart';
import 'widgets/account_sheet.dart';

/// 로그인.
/// - 기본: Google 또는 이메일 계정 (어느 기기에서든 같은 데이터).
/// - 보조: 계정 없이 이 기기에서만 쓰기 (이름 + 접근 코드).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;
  String? _error;

  Future<void> _google() async {
    final state = context.read<AppState>();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final msg = await state.cloudSignInWithGoogle();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } on CloudException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = '구글 로그인 오류: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final cloud = state.cloudAvailable;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.fitness_center, size: 64, color: cs.primary),
                  const SizedBox(height: 12),
                  Text('FitRoutine',
                      textAlign: TextAlign.center,
                      style: text.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  Text('내 헬스장 기구로 자동 생성되는 운동 루틴',
                      textAlign: TextAlign.center,
                      style: text.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                  const SizedBox(height: 32),
                  if (cloud) ...[
                    FilledButton.icon(
                      onPressed: _busy ? null : _google,
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                      icon: _busy
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.g_mobiledata, size: 28),
                      label: const Text('Google 계정으로 시작'),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : () => AccountSheet.show(context),
                      style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                      icon: const Icon(Icons.mail_outline),
                      label: const Text('이메일로 로그인 / 가입'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: cs.error)),
                    ],
                    const SizedBox(height: 8),
                    Text('계정으로 로그인하면 폰·노트북 어디서든 같은 데이터를 봅니다.',
                        textAlign: TextAlign.center,
                        style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: () => _LocalOnlySheet.show(context),
                      child: const Text('계정 없이 이 기기에서만 사용'),
                    ),
                  ] else
                    const _LocalOnlyForm(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 계정 없이 쓰는 경우: 프로필 선택/생성 + 접근 코드.
class _LocalOnlySheet extends StatelessWidget {
  const _LocalOnlySheet();

  static Future<void> show(BuildContext context) => showModalBottomSheet(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (_) => const _LocalOnlySheet(),
      );

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
        child: const _LocalOnlyForm(),
      );
}

class _LocalOnlyForm extends StatefulWidget {
  const _LocalOnlyForm();

  @override
  State<_LocalOnlyForm> createState() => _LocalOnlyFormState();
}

class _LocalOnlyFormState extends State<_LocalOnlyForm> {
  final _code = TextEditingController();
  final _name = TextEditingController();
  String? _selectedId;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final state = context.read<AppState>();
    setState(() => _error = null);
    if (!state.checkCode(_code.text)) {
      setState(() => _error = '접근 코드가 올바르지 않습니다.');
      return;
    }
    if (_creating || state.profiles.isEmpty) {
      final p = await state.createProfile(_name.text, _code.text);
      if (p == null) {
        setState(() => _error = '이름을 입력하세요.');
        return;
      }
      _closeSheet();
      return;
    }
    final id = _selectedId ?? state.profiles.first.id;
    final ok = await state.login(id, _code.text);
    if (!ok) {
      setState(() => _error = '로그인 실패');
      return;
    }
    _closeSheet();
  }

  /// 바텀시트 안에서 열렸으면 로그인 뒤 시트를 닫는다.
  void _closeSheet() {
    if (!mounted) return;
    final nav = Navigator.of(context);
    if (nav.canPop()) nav.pop();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final showCreate = _creating || state.profiles.isEmpty;
    _selectedId ??= state.profiles.firstOrNull?.id;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('이 기기에서만 사용', style: text.titleMedium),
        Text('데이터가 이 기기에만 저장되고 다른 기기와 공유되지 않습니다.',
            style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        const SizedBox(height: 14),
        if (showCreate)
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '이름', prefixIcon: Icon(Icons.person_outline)),
            textInputAction: TextInputAction.next,
          )
        else
          DropdownButtonFormField<String>(
            initialValue: _selectedId,
            decoration: const InputDecoration(labelText: '프로필', prefixIcon: Icon(Icons.person_outline)),
            items: state.profiles.map((p) => DropdownMenuItem(value: p.id, child: Text(p.name))).toList(),
            onChanged: (v) => setState(() => _selectedId = v),
          ),
        const SizedBox(height: 10),
        TextField(
          controller: _code,
          obscureText: true,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '접근 코드', prefixIcon: Icon(Icons.lock_outline)),
          onSubmitted: (_) => _submit(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(_error!, style: TextStyle(color: cs.error)),
        ],
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
          child: Text(showCreate ? '프로필 만들고 시작' : '시작'),
        ),
        if (state.profiles.isNotEmpty)
          TextButton(
            onPressed: () => setState(() => _creating = !_creating),
            child: Text(_creating ? '기존 프로필 선택' : '새 프로필 만들기'),
          ),
      ],
    );
  }
}
