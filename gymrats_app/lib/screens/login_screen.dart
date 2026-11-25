import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../services/auth/auth_repository.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/login_viewmodel.dart';
import '../widgets/auth_cast.dart';
import '../widgets/auth_form.dart';

/// Shown while nobody is logged in (P8, LoginB look d1 with the id link):
/// the GYMMOUSE logo, the group photo on its podium, "Google로 시작하기"
/// and the "아이디로 로그인" link, which opens the id sheet. On success
/// GymRatsApp switches to home by itself and closes the sheet.
///
/// The states of LoginS: L1 (a spinner in the Google button, the button
/// and the link greyed), C2 (a grey line over the button after backing
/// out of Google), F1 (an error box over the button, the button saying
/// "Google로 다시 시도"). An expired session shows in the same box.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.createViewModel});

  /// Builds the view model; replaces the default one in tests.
  final LoginViewModel Function()? createViewModel;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final LoginViewModel _viewModel;

  // Kept here, so a closed and reopened sheet keeps what was typed.
  final _loginId = TextEditingController();
  final _password = TextEditingController();
  bool _sheetOpen = false;

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

  /// A new provider account picks its nickname before it is created.
  Future<void> _signInWith(SocialSignInService service) async {
    await _viewModel.signInWith(service);
    final request = _viewModel.takeSignupRequest();
    if (request == null || !mounted) return;
    await Navigator.pushNamed(
      context,
      GymRatsApp.socialSignupRoute,
      arguments: request,
    );
  }

  /// Opens the id sheet. Opening and closing it clear the first screen's
  /// notes and the sheet's errors, so neither shows the other's.
  Future<void> _openIdSheet() async {
    _viewModel.edited();
    setState(() => _sheetOpen = true);
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: AuthColors.scrim,
      elevation: 0,
      builder: (_) => ChangeNotifierProvider<LoginViewModel>.value(
        value: _viewModel,
        child: _IdLoginSheet(loginId: _loginId, password: _password),
      ),
    );
    if (!mounted) return;
    setState(() => _sheetOpen = false);
    if (_viewModel.state.busy) {
      // Closed while logging in: the result is the sheet's, so it is
      // cleared once it comes rather than shown on the first screen.
      _clearWhenDone();
    } else {
      _viewModel.edited();
    }
  }

  void _clearWhenDone() {
    void done() {
      if (_viewModel.state.busy) return;
      _viewModel.removeListener(done);
      if (!_sheetOpen) _viewModel.edited();
    }

    _viewModel.addListener(done);
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<LoginViewModel>.value(
      value: _viewModel,
      child: Scaffold(
        backgroundColor: AppColors.background,
        // The id sheet rides up with the keyboard by itself; the first
        // screen under it stays as it is.
        resizeToAvoidBottomInset: false,
        body: Stack(
          children: [
            const Positioned.fill(child: AuthBackdrop()),
            SafeArea(
              child: Consumer<LoginViewModel>(
                builder: (context, vm, _) => _firstScreen(vm),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _firstScreen(LoginViewModel vm) {
    final state = vm.state;
    final google = vm.google;
    final busy = state.signingInWith != null;
    final formError = state.formError;
    final Widget? notice = _sheetOpen
        ? null
        : state.cancelledWith != null
        ? const AuthNotice('로그인을 취소했어요')
        : formError != null
        ? AuthErrorBox(formError)
        : null;
    return CustomMultiChildLayout(
      delegate: _FirstScreenLayout(),
      children: [
        LayoutId(id: _Slot.logo, child: const _Logo()),
        LayoutId(
          id: _Slot.stage,
          child: const AuthCastStage(place: AuthCastPlace.login),
        ),
        LayoutId(id: _Slot.notice, child: notice ?? const SizedBox.shrink()),
        LayoutId(
          id: _Slot.controls,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (google != null) ...[
                AuthGoogleButton(
                  busy: busy,
                  label: busy
                      ? '${google.provider.label}로 로그인하는 중…'
                      : state.failedWith == google.provider
                      ? '${google.provider.label}로 다시 시도'
                      : '${google.provider.label}로 시작하기',
                  onPressed: state.busy ? null : () => _signInWith(google),
                ),
                const SizedBox(height: AuthLayout.gap),
              ],
              AuthTextLink(
                label: '아이디로 로그인',
                onPressed: state.busy ? null : _openIdSheet,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

enum _Slot { logo, stage, notice, controls }

/// LoginB's first screen in any size: the logo at the top, the Google
/// button and the link at the bottom, the group photo between them as
/// large as fits (no larger than the width allows), its feet on the
/// controls. A note over the button may cover the podium's lowest step,
/// as in LoginS; when it would reach the lowest row's feet the photo
/// shrinks instead.
class _FirstScreenLayout extends MultiChildLayoutDelegate {
  @override
  void performLayout(Size size) {
    const side = AppSpacing.s20;
    const place = AuthCastPlace.login;
    final inner = math.max(0.0, size.width - 2 * side);
    final logo = layoutChild(_Slot.logo, BoxConstraints(maxWidth: inner));
    positionChild(
      _Slot.logo,
      Offset((size.width - logo.width) / 2, AuthLayout.logoTop),
    );
    final controls = layoutChild(
      _Slot.controls,
      BoxConstraints.tightFor(width: inner),
    );
    final controlsTop = size.height - AppSpacing.s24 - controls.height;
    positionChild(_Slot.controls, Offset(side, controlsTop));
    final notice = layoutChild(
      _Slot.notice,
      BoxConstraints.tightFor(width: inner),
    );
    final noticeRoom = notice.height > 0 ? notice.height + AuthLayout.gap : 0.0;
    positionChild(_Slot.notice, Offset(side, controlsTop - noticeRoom));

    final top = AuthLayout.logoTop + logo.height;
    final room = controlsTop - top;
    final belowFeet = place.bottom - place.feet;
    var scale = room / place.height;
    if (noticeRoom > belowFeet * scale) {
      scale = (room - noticeRoom) / (place.height - belowFeet);
    }
    scale = math.max(
      0.0,
      math.min(scale, size.width / AuthCast.standard.stage.width),
    );
    final bottom = math.min(
      controlsTop,
      controlsTop - noticeRoom + belowFeet * scale,
    );
    final height = place.height * scale;
    layoutChild(
      _Slot.stage,
      BoxConstraints.tightFor(width: size.width, height: height),
    );
    positionChild(_Slot.stage, Offset(0, bottom - height));
  }

  @override
  bool shouldRelayout(_FirstScreenLayout oldDelegate) => false;
}

/// The lime bar and the slanted GYMMOUSE, and "1V1 30초 실시간 운동 대결"
/// under it; each line shrinks to fit rather than breaking.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: SizedBox(
            height: AuthLayout.logoRow,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const _Slant(
                  degrees: AuthLayout.logoBarSkew,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      border: Border.fromBorderSide(
                        BorderSide(
                          color: AppColors.ink,
                          width: AuthLayout.thinEdge,
                        ),
                      ),
                    ),
                    child: SizedBox(
                      width: AuthLayout.logoBarWidth,
                      height: AuthLayout.logoBarHeight,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.s12),
                _Slant(
                  degrees: AuthLayout.logoSkew,
                  child: Semantics(
                    header: true,
                    child: Text('GYMMOUSE', style: text.authLogo),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: AuthLayout.gap),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('1V1', style: text.authTagMark),
              const SizedBox(width: AuthLayout.tagGap),
              Text('30초 실시간 운동 대결', style: text.authSmall),
            ],
          ),
        ),
      ],
    );
  }
}

/// Slants [child] by [degrees], its top to the right, about its middle (CSS
/// skewX(-degrees)).
class _Slant extends StatelessWidget {
  const _Slant({required this.degrees, required this.child});

  final double degrees;
  final Widget child;

  @override
  Widget build(BuildContext context) => Transform(
    alignment: Alignment.center,
    transform: Matrix4.skewX(-degrees * math.pi / 180),
    child: child,
  );
}

/// "아이디로 로그인" (LoginS idsheet, iderr): the app's id and password
/// with LoginViewModel's checks and messages, the lime 로그인 and the link
/// to the sign-up screen. It rides up with the keyboard.
class _IdLoginSheet extends StatelessWidget {
  const _IdLoginSheet({required this.loginId, required this.password});

  final TextEditingController loginId;
  final TextEditingController password;

  /// Logs in; only a login that worked tells the phone's password
  /// manager to save what was typed.
  Future<void> _submit(BuildContext context) async {
    FocusScope.of(context).unfocus();
    final loggedIn = await context.read<LoginViewModel>().submit(
      loginId: loginId.text,
      password: password.text,
    );
    if (loggedIn) TextInput.finishAutofillContext();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final vm = context.watch<LoginViewModel>();
    final state = vm.state;
    final loginIdError = state.loginIdError;
    final passwordError = state.passwordError;
    final formError = state.formError;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(AppRadius.sheet),
          ),
        ),
        position: DecorationPosition.background,
        child: CustomPaint(
          foregroundPainter: const _SheetEdge(),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.s20,
                AuthLayout.sheetPadTop,
                AppSpacing.s20,
                AppSpacing.s24,
              ),
              // Closing the sheet is not a login: the password manager is not
              // asked to save (Samsung Pass did after a wrong password).
              child: AutofillGroup(
                onDisposeAction: AutofillContextAction.cancel,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Center(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AuthColors.sheetHandle,
                          borderRadius: BorderRadius.all(
                            Radius.circular(AuthLayout.handleRadius),
                          ),
                        ),
                        child: SizedBox(
                          width: AuthLayout.handleWidth,
                          height: AuthLayout.handleHeight,
                        ),
                      ),
                    ),
                    const SizedBox(height: AuthLayout.gap),
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AuthLayout.sheetTitleTop,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              header: true,
                              child: AuthWords(
                                '아이디로 로그인',
                                style: text.authSheetTitle,
                              ),
                            ),
                          ),
                          AuthRoundButton(
                            glyph: AuthGlyph.close,
                            tooltip: '닫기',
                            size: AuthLayout.closeButton,
                            icon: AuthLayout.closeIcon,
                            onPressed: () => Navigator.of(context).maybePop(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AuthLayout.gap),
                    const Padding(
                      padding: EdgeInsets.only(top: AuthLayout.sheetTitleTop),
                      child: AuthLabel('아이디'),
                    ),
                    const SizedBox(height: AuthLayout.gap),
                    AuthInputField(
                      controller: loginId,
                      label: '아이디',
                      autofillHints: const [AutofillHints.username],
                      keyboardType: TextInputType.visiblePassword,
                      onChanged: (_) => vm.edited(),
                    ),
                    if (loginIdError != null) ...[
                      const SizedBox(height: AuthLayout.gap),
                      AuthFieldError(loginIdError),
                    ],
                    const SizedBox(height: AuthLayout.gap),
                    const AuthLabel('비밀번호'),
                    const SizedBox(height: AuthLayout.gap),
                    AuthInputField(
                      controller: password,
                      label: '비밀번호',
                      obscure: true,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onChanged: (_) => vm.edited(),
                      onSubmitted: (_) => _submit(context),
                    ),
                    if (passwordError != null) ...[
                      const SizedBox(height: AuthLayout.gap),
                      AuthFieldError(passwordError),
                    ],
                    if (formError != null) ...[
                      const SizedBox(height: AuthLayout.gap),
                      AuthFieldError(formError),
                    ],
                    const SizedBox(height: AuthLayout.gap + AppSpacing.s8),
                    AuthLimeButton(
                      label: '로그인',
                      busy: state.submitting,
                      busyLabel: '로그인하는 중…',
                      onPressed: () => _submit(context),
                    ),
                    const SizedBox(height: AuthLayout.gap),
                    AuthTextLink(
                      label: '처음이신가요? 회원가입',
                      height: AuthLayout.sheetLinkHeight,
                      onPressed: state.busy
                          ? null
                          : () => Navigator.pushNamed(
                              context,
                              GymRatsApp.signupRoute,
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The sheet's ink edge on its top and sides, not along the screen's
/// bottom (LoginS: inset 2 px on the top, left and right).
class _SheetEdge extends CustomPainter {
  const _SheetEdge();

  @override
  void paint(Canvas canvas, Size size) {
    const inset = AuthLayout.edge / 2;
    const r = AppRadius.sheet - inset;
    final path = Path()
      ..moveTo(inset, size.height)
      ..lineTo(inset, AppRadius.sheet)
      ..arcToPoint(
        const Offset(AppRadius.sheet, inset),
        radius: const Radius.circular(r),
      )
      ..lineTo(size.width - AppRadius.sheet, inset)
      ..arcToPoint(
        Offset(size.width - inset, AppRadius.sheet),
        radius: const Radius.circular(r),
      )
      ..lineTo(size.width - inset, size.height);
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = AuthLayout.edge,
    );
  }

  @override
  bool shouldRepaint(_SheetEdge oldDelegate) => false;
}
