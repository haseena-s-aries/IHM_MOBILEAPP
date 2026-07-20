import 'package:flutter/material.dart';

enum AppDialogType { success, error, warning, info }

class AppDialog {
  const AppDialog._();

  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: _DialogHeader(
          type: destructive ? AppDialogType.warning : AppDialogType.info,
          title: title,
        ),
        content: Text(
          message,
          style: const TextStyle(height: 1.45, color: Color(0xFF52627A)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: destructive
                  ? const Color(0xFFD92D20)
                  : const Color(0xFF2563EB),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  static Future<void> success(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return _message(
      context,
      type: AppDialogType.success,
      title: title,
      message: message,
    );
  }

  static Future<void> error(
    BuildContext context, {
    String title = 'Something went wrong',
    required Object message,
  }) {
    return _message(
      context,
      type: AppDialogType.error,
      title: title,
      message: _cleanError(message),
    );
  }

  static Future<void> info(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return _message(
      context,
      type: AppDialogType.info,
      title: title,
      message: message,
    );
  }

  static Future<void> warning(
    BuildContext context, {
    required String title,
    required String message,
  }) {
    return _message(
      context,
      type: AppDialogType.warning,
      title: title,
      message: message,
    );
  }

  static Future<T?> execute<T>(
    BuildContext context, {
    required String loadingMessage,
    required Future<T> Function() action,
    String? successTitle,
    String? successMessage,
    String errorTitle = 'Operation failed',
  }) async {
    final navigator = Navigator.of(context, rootNavigator: true);
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          content: Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Text(
                  loadingMessage,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF24324A),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    await Future<void>.delayed(const Duration(milliseconds: 80));
    try {
      final result = await action();
      if (navigator.canPop()) navigator.pop();
      if (context.mounted &&
          successTitle != null &&
          successMessage != null) {
        await success(
          context,
          title: successTitle,
          message: successMessage,
        );
      }
      return result;
    } catch (errorValue) {
      if (navigator.canPop()) navigator.pop();
      if (context.mounted) {
        await error(context, title: errorTitle, message: errorValue);
      }
      return null;
    }
  }

  static Future<void> _message(
    BuildContext context, {
    required AppDialogType type,
    required String title,
    required String message,
  }) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: _DialogHeader(type: type, title: title),
        content: Text(
          message,
          style: const TextStyle(height: 1.45, color: Color(0xFF52627A)),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  static String _cleanError(Object error) {
    final text = error.toString().trim();
    return text.startsWith('Exception: ')
        ? text.substring('Exception: '.length)
        : text;
  }
}

class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.type, required this.title});

  final AppDialogType type;
  final String title;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (type) {
      AppDialogType.success => (
          Icons.check_circle_rounded,
          const Color(0xFF067647),
          const Color(0xFFECFDF3),
        ),
      AppDialogType.error => (
          Icons.error_rounded,
          const Color(0xFFB42318),
          const Color(0xFFFEF3F2),
        ),
      AppDialogType.warning => (
          Icons.warning_amber_rounded,
          const Color(0xFFB54708),
          const Color(0xFFFFFAEB),
        ),
      AppDialogType.info => (
          Icons.info_rounded,
          const Color(0xFF175CD3),
          const Color(0xFFEFF8FF),
        ),
    };

    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(color: background, shape: BoxShape.circle),
          child: Icon(icon, color: color),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Color(0xFF172033),
            ),
          ),
        ),
      ],
    );
  }
}
