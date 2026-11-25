import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../theme/app_theme.dart';
import '../viewmodels/signup_viewmodel.dart';
import '../viewmodels/social_signup_viewmodel.dart';
import '../widgets/auth_cast.dart';
import '../widgets/auth_form.dart';

/// The nickname of a new Google account (P8, LoginB step signup; LoginS
/// nick, nickerr, nickbusy): back and "회원가입" at the top, the group photo
/// on its podium, and the nickname with its count, its help line (or its
/// error) and the lime "시작하기" at the bottom. Opened from login; back
/// returns there and creates nothing. On success the user is logged in and
/// GymRatsApp moves on by itself.
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
    return ChangeNotifierProvider<SocialSignupViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Stack(
          children: [
            const Positioned.fill(child: AuthBackdrop()),
            SafeArea(
              child: Consumer<SocialSignupViewModel>(
                builder: (context, vm, _) => CustomMultiChildLayout(
                  delegate: _SignupLayout(),
                  children: [
                    LayoutId(id: _Slot.title, child: const _TitleRow()),
                    LayoutId(
                      id: _Slot.stage,
                      child: const AuthCastStage(place: AuthCastPlace.signup),
                    ),
                    LayoutId(id: _Slot.form, child: _form(vm)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(SocialSignupViewModel vm) {
    final text = Theme.of(context).textTheme;
    final state = vm.state;
    final nicknameError = state.nicknameError;
    final formError = state.formError;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthLabel('닉네임'),
        const SizedBox(height: AppSpacing.s8),
        AuthInputField(
          controller: _nickname,
          label: '닉네임',
          height: AuthLayout.nicknameHeight,
          autofillHints: const [AutofillHints.nickname],
          textInputAction: TextInputAction.done,
          // The design's maxlength: input stops at 12, cut only once a
          // Korean syllable is finished (P8 decision, 2026-11-25).
          inputFormatters: [
            LengthLimitingTextInputFormatter(
              SignupRules.nicknameMax,
              maxLengthEnforcement:
                  MaxLengthEnforcement.truncateAfterCompositionEnds,
            ),
          ],
          onChanged: (_) => vm.edited(),
          onSubmitted: (_) => _submit(),
          trailing: ExcludeSemantics(
            child: ValueListenableBuilder<TextEditingValue>(
              valueListenable: _nickname,
              builder: (context, value, _) => Text(
                '${math.min(value.text.characters.length, SignupRules.nicknameMax)}'
                '/${SignupRules.nicknameMax}',
                style: text.authCount,
              ),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.s8),
        if (nicknameError != null)
          AuthFieldError(nicknameError)
        else
          AuthWords(
            '대결 화면에 보이는 이름, ${SignupRules.nicknameMax}자 이하',
            style: text.authSmall,
          ),
        if (formError != null) ...[
          const SizedBox(height: AppSpacing.s8),
          AuthErrorBox(formError),
        ],
        // The column's gap and the button's own top margin.
        const SizedBox(height: AppSpacing.s8 + AppSpacing.s8),
        AuthLimeButton(
          label: '시작하기',
          busy: state.submitting,
          busyLabel: '계정을 만드는 중…',
          onPressed: _submit,
        ),
      ],
    );
  }
}

enum _Slot { title, stage, form }

/// LoginB's sign-up screen in any size: the title row at the top, the
/// nickname form at the bottom, the group photo between them as large as
/// fits. With the keyboard up the form stays whole and the photo shrinks or
/// goes; if even the form does not fit, the title row moves up out of the
/// way.
class _SignupLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    const side = AppSpacing.s20;
    const place = AuthCastPlace.signup;
    final inner = math.max(0.0, size.width - 2 * side);
    final form = layoutChild(_Slot.form, BoxConstraints.tightFor(width: inner));
    final formTop = size.height - AppSpacing.s24 - form.height;
    positionChild(_Slot.form, Offset(side, formTop));
    final title = layoutChild(
      _Slot.title,
      BoxConstraints.tightFor(
        width: math.max(0.0, size.width - 2 * AppSpacing.s16),
      ),
    );
    final titleTop = math.min(AuthLayout.titleTop, formTop - title.height);
    positionChild(_Slot.title, Offset(AppSpacing.s16, titleTop));
    final top = titleTop + title.height;
    final room = math.max(0.0, formTop - top);
    final scale = math.min(
      room / place.height,
      size.width / AuthCast.standard.stage.width,
    );
    final height = place.height * scale;
    layoutChild(
      _Slot.stage,
      BoxConstraints.tightFor(width: size.width, height: height),
    );
    positionChild(_Slot.stage, Offset(0, formTop - height));
  }

  @override
  bool shouldRelayout(_SignupLayout oldDelegate) => false;
}

/// The round back button and "회원가입".
class _TitleRow extends StatelessWidget {
  const _TitleRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        AuthRoundButton(
          glyph: AuthGlyph.back,
          tooltip: '뒤로',
          size: AuthLayout.backButton,
          icon: AuthLayout.backIcon,
          onPressed: () => Navigator.maybePop(context),
        ),
        const SizedBox(width: AuthLayout.gap),
        Expanded(
          child: Semantics(
            header: true,
            child: AuthWords(
              '회원가입',
              style: Theme.of(context).textTheme.authTitle,
            ),
          ),
        ),
      ],
    );
  }
}
