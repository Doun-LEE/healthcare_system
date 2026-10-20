import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import 'widgets/account_sheet.dart';

/// 로그인: 프로필 선택(또는 새로 만들기) + 접근 코드.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
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
      if (p == null) setState(() => _error = '이름을 입력하세요.');
      return;
    }
    final id = _selectedId ?? state.profiles.first.id;
    final ok = await state.login(id, _code.text);
    if (!ok) setState(() => _error = '로그인 실패');
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final showCreate = _creating || state.profiles.isEmpty;
    _selectedId ??= state.profiles.firstOrNull?.id;

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
                  if (showCreate)
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(
                        labelText: '이름',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textInputAction: TextInputAction.next,
                    )
                  else
                    DropdownButtonFormField<String>(
                      initialValue: _selectedId,
                      decoration: const InputDecoration(
                        labelText: '프로필',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      items: state.profiles
                          .map((p) => DropdownMenuItem(value: p.id, child: Text(p.name)))
                          .toList(),
                      onChanged: (v) => setState(() => _selectedId = v),
                    ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _code,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: '접근 코드',
                      prefixIcon: Icon(Icons.lock_outline),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(color: cs.error)),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _submit,
                    style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: Text(showCreate ? '프로필 만들고 시작' : '로그인'),
                  ),
                  if (state.profiles.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(() => _creating = !_creating),
                      child: Text(_creating ? '기존 프로필로 로그인' : '새 프로필 만들기'),
                    ),
                  if (state.cloudAvailable && !state.cloudSignedIn) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => AccountSheet.show(context),
                      icon: const Icon(Icons.cloud_outlined),
                      label: const Text('다른 기기에서 쓰던 계정으로 불러오기'),
                    ),
                  ],
                  if (state.cloudSignedIn)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('계정 ${state.cloudEmail} 동기화 중',
                          textAlign: TextAlign.center,
                          style: text.bodySmall?.copyWith(color: cs.primary)),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
