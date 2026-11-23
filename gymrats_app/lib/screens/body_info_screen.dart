import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/body_info_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/auth_form.dart';
import '../widgets/grid_background.dart';

/// Right after a new account: height, weight and the consent box, with
/// 건너뛰기 and the lime 다음 at the bottom. Either one moves on to the
/// rules and home; GymRatsApp shows it while [AuthViewModel.needsBodyInfo].
class BodyInfoScreen extends StatefulWidget {
  const BodyInfoScreen({super.key, this.createViewModel});

  /// Builds the view model; replaces the default one in tests.
  final BodyInfoViewModel Function()? createViewModel;

  @override
  State<BodyInfoScreen> createState() => _BodyInfoScreenState();
}

class _BodyInfoScreenState extends State<BodyInfoScreen> {
  late final BodyInfoViewModel _viewModel;
  final _height = TextEditingController();
  final _weight = TextEditingController();
  bool _consent = false;

  static const _number = TextInputType.numberWithOptions(decimal: true);

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        BodyInfoViewModel(auth: context.read<AuthViewModel>());
  }

  @override
  void dispose() {
    _viewModel.dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  void _submit() {
    FocusScope.of(context).unfocus();
    _viewModel.submit(
      height: _height.text,
      weight: _weight.text,
      consent: _consent,
    );
  }

  void _toggleConsent(bool? value) {
    setState(() => _consent = value ?? false);
    _viewModel.edited();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ChangeNotifierProvider<BodyInfoViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        body: GridBackground(
          child: SafeArea(
            child: Consumer<BodyInfoViewModel>(
              builder: (context, vm, _) {
                final state = vm.state;
                final formError = state.formError;
                final consentError = state.consentError;
                return Column(
                  children: [
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.s20,
                          AppSpacing.s24,
                          AppSpacing.s20,
                          AppSpacing.s24,
                        ),
                        children: [
                          Text('키와 몸무게를\n알려주세요', style: text.headlineLarge),
                          const SizedBox(height: AppSpacing.s8),
                          Text(
                            '더 정확한 피드백 정보를 드리는 데 도움이 됩니다.',
                            style: text.bodyMedium?.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.s32),
                          AuthTextField(
                            controller: _height,
                            label: '키 (cm)',
                            error: state.heightError,
                            keyboardType: _number,
                            onChanged: (_) => vm.edited(),
                          ),
                          const SizedBox(height: AppSpacing.s12),
                          AuthTextField(
                            controller: _weight,
                            label: '몸무게 (kg)',
                            error: state.weightError,
                            keyboardType: _number,
                            textInputAction: TextInputAction.done,
                            onChanged: (_) => vm.edited(),
                          ),
                          const SizedBox(height: AppSpacing.s16),
                          CheckboxListTile(
                            value: _consent,
                            onChanged: state.submitting ? null : _toggleConsent,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            activeColor: AppColors.ink,
                            checkColor: AppColors.accent,
                            title: Text(
                              '개인정보(키·몸무게) 수집·이용 동의',
                              style: text.bodyLarge,
                            ),
                            subtitle: Text(
                              '내 계정에 저장되고 운동 피드백에 쓰여요. '
                              '동의하지 않으면 건너뛰기를 눌러 주세요.',
                              style: text.bodySmall?.copyWith(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ),
                          if (consentError != null)
                            Text(
                              consentError,
                              style: text.bodySmall?.copyWith(
                                color: AppColors.warning,
                              ),
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
                        AppSpacing.s16,
                      ),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: state.submitting ? null : vm.skip,
                            child: Text(
                              '건너뛰기',
                              style: text.bodyLarge?.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(width: AppSpacing.s12),
                          Expanded(
                            child: AccentButton(
                              title: '다음',
                              hint: state.submitting ? '저장하는 중…' : null,
                              onPressed: _submit,
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
