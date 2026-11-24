import 'package:flutter/widgets.dart';

final class TelegramIntegration extends NavigatorObserver with ChangeNotifier {
  void ready() {}
  Widget wrap(BuildContext context, Widget child) => child;
}
