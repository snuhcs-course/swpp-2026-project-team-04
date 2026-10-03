import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Asks '매칭을 취소할까요?'. Pops true for 매칭 취소, false for 계속하기.
class CancelMatchingDialog extends StatelessWidget {
  const CancelMatchingDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppTheme.cardRadius)),
        side: BorderSide(color: AppColors.border),
      ),
      title: const Text('매칭을 취소할까요?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('계속하기'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('매칭 취소'),
        ),
      ],
    );
  }
}

/// Shows [CancelMatchingDialog]. True only for 매칭 취소: 계속하기, a tap
/// outside, or back while it is open all mean stay.
Future<bool> confirmCancelMatching(BuildContext context) async {
  final cancel = await showDialog<bool>(
    context: context,
    builder: (_) => const CancelMatchingDialog(),
  );
  return cancel ?? false;
}

/// Leaves the matching flow: closes every screen above home.
///
/// These are plain pops, which `PopScope(canPop: false)` does not stop; it
/// only hears about them, with `didPop` true.
void popToHome(BuildContext context) =>
    Navigator.popUntil(context, (route) => route.isFirst);
