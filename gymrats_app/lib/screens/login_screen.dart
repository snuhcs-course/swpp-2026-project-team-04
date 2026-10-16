import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/login_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/auth_form.dart';
import '../widgets/grid_background.dart';

/// Shown while nobody is logged in: login id and password, the lime 로그인
/// button at the bottom, and a link to sign up. On success GymRatsApp
/// switches to home by itself.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.createViewModel});

  /// Builds the view model; replaces the default one in tests.
  final LoginViewModel Function()? createViewModel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginViewModel _viewModel;
  final _loginId = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        LoginViewModel(auth: context.read<AuthViewModel>());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _loginId.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    _viewModel.submit(loginId: _loginId.text, password: _password.text);
  }

  void _openSignup() => Navigator.pushNamed(context, GymRatsApp.signupRoute);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ChangeNotifierProvider<LoginViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        body: GridBackground(
          child: SafeArea(
            child: Consumer<LoginViewModel>(
              builder: (context, vm, _) {
                final state = vm.state;
                final formError = state.formError;
                return Column(
                  children: [
                    Expanded(
                      child: AutofillGroup(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.s20,
                            AppSpacing.s24,
                            AppSpacing.s20,
                            AppSpacing.s24,
                          ),
                          children: [
                            Text(
                              'GYMRATS',
                              style: text.titleLarge?.copyWith(
                                color: AppColors.accent,
                              ),
                            ),
                            const SizedBox(height: AppSpacing.s8),
                            // Line break set by hand: Flutter may break
                            // Korean inside a word.
                            Text(
                              '로그인하고\n한 판 붙어볼까요?',
                              style: text.headlineLarge,
                            ),
                            const SizedBox(height: AppSpacing.s32),
                            AuthTextField(
                              controller: _loginId,
                              label: '아이디',
                              error: state.loginIdError,
                              autofillHints: const [AutofillHints.username],
                              keyboardType: TextInputType.visiblePassword,
                              onChanged: (_) => vm.edited(),
                            ),
                            const SizedBox(height: AppSpacing.s12),
                            AuthTextField(
                              controller: _password,
                              label: '비밀번호',
                              error: state.passwordError,
                              obscure: true,
                              autofillHints: const [AutofillHints.password],
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
                        AppSpacing.s16,
                      ),
                      child: Column(
                        children: [
                          AccentButton(
                            title: '로그인',
                            hint: state.submitting ? '로그인하는 중…' : null,
                            onPressed: _submit,
                          ),
                          const SizedBox(height: AppSpacing.s8),
                          TextButton(
                            onPressed: state.submitting ? null : _openSignup,
                            child: Text(
                              '처음이신가요? 회원가입',
                              style: text.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
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
