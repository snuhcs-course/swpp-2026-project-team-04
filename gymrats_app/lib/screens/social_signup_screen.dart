import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/signup_viewmodel.dart';
import '../viewmodels/social_signup_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/auth_form.dart';
import '../widgets/grid_background.dart';

/// The nickname of a new Google account, with the lime 가입하기
/// at the bottom. Opened from login; back returns there and creates nothing.
/// On success the user is logged in and GymRatsApp moves on by itself.
class SocialSignupScreen extends StatefulWidget {
  const SocialSignupScreen({super.key, required this.createViewModel});

  final SocialSignupViewModel Function() createViewModel;

  @override
  State<SocialSignupScreen> createState() => _SocialSignupScreenState();
}

class _SocialSignupScreenState extends State<SocialSignupScreen> {
  late final SocialSignupViewModel _viewModel;
  final _nickname = TextEditingController();

  @override
  void initState() {
    super.initState();
    _viewModel = widget.createViewModel();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _nickname.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    _viewModel.submit(_nickname.text);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ChangeNotifierProvider<SocialSignupViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        body: GridBackground(
          child: SafeArea(
            child: Consumer<SocialSignupViewModel>(
              builder: (context, vm, _) {
                final state = vm.state;
                final formError = state.formError;
                return Column(
                  children: [
                    const TopBar(title: '회원가입'),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s20,
                          AppSpacing.s16,
                          AppSpacing.s20,
                          AppSpacing.s24,
                        ),
                        children: [
                          Text('닉네임을\n정해 주세요', style: text.headlineLarge),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            '${vm.provider.label} 계정으로 가입해요.',
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
