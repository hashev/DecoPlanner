import 'dart:async';
import 'dart:js_interop';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

@JS('Telegram')
external _Telegram? get _telegram;

extension type _Telegram._(JSObject _) implements JSObject {
  @JS('WebApp')
  external _WebApp? get webApp;
}

extension type _WebApp._(JSObject _) implements JSObject {
  external String get platform;
  @JS('BackButton')
  external _TelegramBackButton? get backButton;
  external _Insets? get safeAreaInset;
  external _Insets? get contentSafeAreaInset;
  external void ready();
  external bool isVersionAtLeast(String version);
  external void onEvent(String name, JSFunction callback);
  external void offEvent(String name, JSFunction callback);
}

extension type _TelegramBackButton._(JSObject _) implements JSObject {
  external void show();
  external void hide();
  external void onClick(JSFunction callback);
  external void offClick(JSFunction callback);
}

extension type _Insets._(JSObject _) implements JSObject {
  external double get top;
  external double get right;
  external double get bottom;
  external double get left;
}

final class TelegramIntegration extends NavigatorObserver with ChangeNotifier {
  TelegramIntegration() {
    final app = _telegram?.webApp;
    if (app == null || app.platform == 'unknown') return;
    _app = app;
    if (app.isVersionAtLeast('6.1')) {
      _back = app.backButton;
      _back?.onClick(_onBack);
    }
    if (app.isVersionAtLeast('8.0')) {
      _observeInsets = true;
      for (final event in _insetEvents) {
        app.onEvent(event, _onInsetsChanged);
      }
    }
  }

  static const _insetEvents = ['safeAreaChanged', 'contentSafeAreaChanged'];
  _WebApp? _app;
  _TelegramBackButton? _back;
  bool _observeInsets = false;
  late final JSFunction _onBack = (() {
    final state = navigator;
    if (state != null) unawaited(state.maybePop());
  }).toJS;
  late final JSFunction _onInsetsChanged = notifyListeners.toJS;

  void ready() => _app?.ready();

  @override
  void didChangeTop(Route<dynamic> topRoute, Route<dynamic>? previousTopRoute) {
    if (navigator?.canPop() == true) {
      _back?.show();
    } else {
      _back?.hide();
    }
  }

  Widget wrap(BuildContext context, Widget child) {
    if (!_observeInsets) return child;
    final viewport = MediaQuery.of(context);
    final safe = _app?.safeAreaInset, content = _app?.contentSafeAreaInset;
    final edge = EdgeInsets.fromLTRB(
      (safe?.left ?? 0) + (content?.left ?? 0),
      (safe?.top ?? 0) + (content?.top ?? 0),
      (safe?.right ?? 0) + (content?.right ?? 0),
      (safe?.bottom ?? 0) + (content?.bottom ?? 0),
    );
    final viewPadding = EdgeInsets.fromLTRB(
      math.max(edge.left, viewport.viewPadding.left),
      math.max(edge.top, viewport.viewPadding.top),
      math.max(edge.right, viewport.viewPadding.right),
      math.max(edge.bottom, viewport.viewPadding.bottom),
    );
    return MediaQuery(
      data: viewport.copyWith(
        viewPadding: viewPadding,
        padding: EdgeInsets.fromLTRB(
          math.max(0, viewPadding.left - viewport.viewInsets.left),
          math.max(0, viewPadding.top - viewport.viewInsets.top),
          math.max(0, viewPadding.right - viewport.viewInsets.right),
          math.max(0, viewPadding.bottom - viewport.viewInsets.bottom),
        ),
      ),
      child: child,
    );
  }

  @override
  void dispose() {
    if (_back case final back?) {
      back.offClick(_onBack);
      back.hide();
    }
    if (_observeInsets) {
      for (final event in _insetEvents) {
        _app?.offEvent(event, _onInsetsChanged);
      }
    }
    super.dispose();
  }
}
