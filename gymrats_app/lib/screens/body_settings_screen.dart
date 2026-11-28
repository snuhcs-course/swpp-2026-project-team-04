import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/user/user_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/body_settings_viewmodel.dart';
import '../widgets/accent_button.dart';
import '../widgets/auth_form.dart';
import '../widgets/lobby_parts.dart';

/// 키·몸무게, from 환경설정 (PM, 2026-11-29): the height and weight given at
/// sign-up, filled in, to change with the same consent as at sign-up, and
/// 저장. It draws [BodySettingsViewModel] and forwards the input.
class BodySettingsScreen extends StatefulWidget {
  const BodySettingsScreen({super.key, this.createViewModel});

  /// Builds the page's view model; the app's account and profile by default.
  final BodySettingsViewModel Function()? createViewModel;

  @override
  State<BodySettingsScreen> createState() => _BodySettingsScreenState();
}

class _BodySettingsScreenState extends State<BodySettingsScreen> {
  late final BodySettingsViewModel _viewModel;
  final _height = TextEditingController();
  final _weight = TextEditingController();
  bool _consent = false;
  bool _filled = false;

  static const _number = TextInputType.numberWithOptions(decimal: true);

  @override
  void initState() {
    super.initState();
    _viewModel =
        widget.createViewModel?.call() ??
        BodySettingsViewModel(
          profiles: context.read<UserRepository>(),
          auth: context.read<AuthViewModel>(),
        );
    _viewModel
      ..addListener(_fillOnce)
      ..load();
  }

  /// Puts the saved values in the fields once they are read. The consent
  /// box starts unticked: each change is saved with the user's own tick.
  void _fillOnce() {
    final state = _viewModel.state;
    if (_filled || state.loading || state.loadFailed) return;
    _filled = true;
    _height.text = BodySettingsViewModel.textOf(state.heightCm);
    _weight.text = BodySettingsViewModel.textOf(state.weightKg);
  }

  @override
  void dispose() {
    _viewModel
      ..removeListener(_fillOnce)
      ..dispose();
    _height.dispose();
    _weight.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final saved = await _viewModel.save(
      height: _height.text,
      weight: _weight.text,
      consent: _consent,
    );
    if (!saved || !mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('키·몸무게를 저장했어요')));
  }

  void _toggleConsent(bool? value) {
    setState(() => _consent = value ?? false);
    _viewModel.edited();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ChangeNotifierProvider<BodySettingsViewModel>.value(
      value: _viewModel,
      child: Consumer<BodySettingsViewModel>(
        builder: (context, vm, _) {
          final state = vm.state;
          final formError = state.formError;
          final consentError = state.consentError;
          final busy = state.loading || state.saving || state.loadFailed;
          return LobbyPage(
            children: [
              const LobbyPageHeader(
                tag: '04 / SETTINGS',
                title: '키·몸무게',
                tagColor: AppColors.textSecondary,
              ),
              const SizedBox(height: AppSpacing.s12),
              Text(
                '운동 리포트의 칼로리와 들어 올린 무게 추정에 쓰여요.',
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.s24),
              if (state.loading)
                const Center(child: CircularProgressIndicator())
              else if (state.loadFailed) ...[
                const FormErrorMessage('저장된 키·몸무게를 불러오지 못했어요.'),
                const SizedBox(height: AppSpacing.s12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton(
                    onPressed: vm.load,
                    child: const Text('다시 시도'),
                  ),
                ),
              ] else ...[
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
                  onChanged: busy ? null : _toggleConsent,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.ink,
                  checkColor: AppColors.accent,
                  title: Text('개인정보(키·몸무게) 수집·이용 동의', style: text.bodyLarge),
                  subtitle: Text(
                    '내 계정에 저장되고 운동 피드백에 쓰여요.',
                    style: text.bodySmall?.copyWith(color: AppColors.textMuted),
                  ),
                ),
                if (consentError != null)
                  Text(
                    consentError,
                    style: text.bodySmall?.copyWith(color: AppColors.warning),
                  ),
                if (formError != null) ...[
                  const SizedBox(height: AppSpacing.s16),
                  FormErrorMessage(formError),
                ],
              ],
              const Spacer(),
              const SizedBox(height: AppSpacing.s24),
              AccentButton(
                title: '저장',
                hint: state.saving ? '저장하는 중…' : null,
                onPressed: _save,
              ),
            ],
          );
        },
      ),
    );
  }
}
