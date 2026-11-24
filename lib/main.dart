import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'app/planner_app.dart';
import 'data/repositories/document_store_platform.dart';
import 'data/services/browser_worker.dart';

Future<void> main() async {
  if (usesBrowserWorkers) {
    WidgetsFlutterBinding.ensureInitialized();
    await prepareBrowserWorkers();
  }
  LicenseRegistry.addLicense(() async* {
    for (final family in ['firasans', 'firacode']) {
      yield LicenseEntryWithLineBreaks([
        'Fira fonts',
      ], await rootBundle.loadString('assets/fonts/$family-OFL.txt'));
    }
  });
  runApp(const PlannerApp(openDocumentStore: openDocumentStore));
}
