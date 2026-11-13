import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'app/planner_app.dart';

void main() {
  LicenseRegistry.addLicense(() async* {
    for (final family in ['firasans', 'firacode']) {
      yield LicenseEntryWithLineBreaks([
        'Fira fonts',
      ], await rootBundle.loadString('assets/fonts/$family-OFL.txt'));
    }
  });
  runApp(const PlannerApp());
}
