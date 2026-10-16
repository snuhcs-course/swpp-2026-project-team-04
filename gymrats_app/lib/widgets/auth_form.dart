import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A labeled text field of the login and sign-up forms, with its error
/// (amber, from the theme) or [helper] underneath.
class AuthTextField extends StatelessWidget {
  const AuthTextField({
    super.key,
    required this.controller,
    required this.label,
    this.error,
    this.helper,
    this.obscure = false,
    this.autofillHints,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.onChanged,
    this.onSubmitted,
  });

  final TextEditingController controller;
  final String label;
  final String? error;
  final String? helper;
  final bool obscure;
  final Iterable<String>? autofillHints;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      obscureText: obscure,
      enableSuggestions: !obscure,
      autocorrect: false,
      autofillHints: autofillHints,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: text.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        errorText: error,
        helperText: helper,
        helperStyle: text.bodySmall?.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}

/// A problem with the whole form, e.g. a wrong password or no network: an
/// amber icon and message.
class FormErrorMessage extends StatelessWidget {
  const FormErrorMessage(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.error_outline_rounded, color: AppColors.warning),
        const SizedBox(width: AppSpacing.s8),
        Expanded(
          child: Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium
                ?.copyWith(color: AppColors.warning),
          ),
        ),
      ],
    );
  }
}

/// The back arrow and a title at the top of a pushed screen.
class TopBar extends StatelessWidget {
  const TopBar({super.key, required this.title, this.onBack});

  final String title;

  /// Defaults to popping this screen.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: '뒤로',
            color: AppColors.textPrimary,
            onPressed: onBack ?? () => Navigator.maybePop(context),
          ),
          const SizedBox(width: AppSpacing.s4),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

/// A centered message with an optional retry, like the home and matching
/// load-failed screens (1-2, 2-2).
class CenteredMessage extends StatelessWidget {
  const CenteredMessage({
    super.key,
    required this.title,
    this.detail,
    this.onRetry,
  });

  final String title;
  final String? detail;

  /// Shows a "다시 시도" button when set.
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final detail = this.detail;
    final onRetry = this.onRetry;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.s32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, textAlign: TextAlign.center, style: text.titleMedium),
            if (detail != null) ...[
              const SizedBox(height: AppSpacing.s8),
              Text(
                detail,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.s16),
              FilledButton(onPressed: onRetry, child: const Text('다시 시도')),
            ],
          ],
        ),
      ),
    );
  }
}
