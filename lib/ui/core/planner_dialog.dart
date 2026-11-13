import 'package:flutter/material.dart';

Future<T?> showPlannerDialog<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool barrierDismissible = true,
}) => showDialog<T>(
  context: context,
  barrierDismissible: barrierDismissible,
  animationStyle: MediaQuery.disableAnimationsOf(context)
      ? AnimationStyle.noAnimation
      : null,
  builder: (context) => _DialogEscape(child: builder(context)),
);

class _DialogEscape extends StatelessWidget {
  const _DialogEscape({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Actions(
    actions: {
      DismissIntent: CallbackAction<DismissIntent>(
        onInvoke: (_) {
          // Keep outside taps disabled while preserving PopScope dirty checks.
          Navigator.of(context).maybePop();
          return null;
        },
      ),
    },
    child: FocusScope(autofocus: true, child: child),
  );
}
