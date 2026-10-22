import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/signup_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/auth_form.dart';
import '../widgets/grid_background.dart';

/// Creates an account: nickname, login id, password and its confirmation,
/// with the lime 가입하기 button at the bottom. Opened from login; back
/// returns there. On success the user is logged in and GymRatsApp shows
/// home.
class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key, this.createViewModel});

  /// Builds the view model; replaces the default one in tests.
  final SignupViewModel Function()? createViewModel;

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  late final SignupViewModel _viewModel;
  final _nickname = TextEditingController();
  final _loginId = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        SignupViewModel(auth: context.read<AuthViewModel>());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _nickname.dispose();
    _loginId.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    _viewModel.submit(
      nickname: _nickname.text,
      loginId: _loginId.text,
      password: _password.text,
      confirm: _confirm.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ChangeNotifierProvider<SignupViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        body: GridBackground(
          child: SafeArea(
            child: Consumer<SignupViewModel>(
              builder: (context, vm, _) {
                final state = vm.state;
                final formError = state.formError;
                return Column(
                  children: [
                    const TopBar(title: '회원가입'),
                    Expanded(
                      child: AutofillGroup(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.s20,
                            AppSpacing.s16,
                            AppSpacing.s20,
                            AppSpacing.s24,
                          ),
                          children: [
                            Text('계정을 만들고\n기록을 남겨요', style: text.headlineLarge),
                            const SizedBox(height: AppSpacing.s8),
                            Text(
                              '경기 기록은 서버에 저장돼서 기기를 바꿔도 남아요.',
                              style: text.bodyMedium?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s32),
                            AuthTextField(
                              controller: _nickname,
                              label: '닉네임',
                              error: state.nicknameError,
                              helper:
                                  '대결 화면에 보이는 이름, '
                                  '${SignupRules.nicknameMax}자 이하',
                              autofillHints: const [AutofillHints.nickname],
                              onChanged: (_) => vm.edited(),
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            AuthTextField(
                              controller: _loginId,
                              label: '아이디',
                              error: state.loginIdError,
                              helper: '영문 소문자, 숫자, _ 4~20자',
                              autofillHints: const [AutofillHints.newUsername],
                              keyboardType: TextInputType.visiblePassword,
                              onChanged: (_) => vm.edited(),
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            AuthTextField(
                              controller: _password,
                              label: '비밀번호',
                              error: state.passwordError,
                              helper: '${SignupRules.passwordMin}자 이상',
                              obscure: true,
                              autofillHints: const [AutofillHints.newPassword],
                              onChanged: (_) => vm.edited(),
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            AuthTextField(
                              controller: _confirm,
                              label: '비밀번호 확인',
                              error: state.confirmError,
                              obscure: true,
                              textInputAction: TextInputAction.done,
                              onChanged: (_) => vm.edited(),
                              onSubmitted: (_) => _submit(),
                            ),
                            if (formError != null) ...[
                              const SizedBox(height: AppSpacing.s16),
                              FormErrorMessage(formError),
                            ],
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.s20,
                        0,
                        AppSpacing.s20,
                        AppSpacing.s24,
                      ),
                      child: AccentButton(
                        title: '가입하기',
                        hint: state.submitting ? '계정을 만드는 중…' : null,
                        onPressed: _submit,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
