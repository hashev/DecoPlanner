import 'dart:io';

import 'package:deco_planner/data/models/planner_document.dart';

import '../support/document_fixtures.dart';

void main(List<String> arguments) {
  final [mode, path] = arguments;
  final file = File(path);
  final native = documentFixture();
  if (mode == 'write') {
    file.writeAsBytesSync(encodePlannerDocument(native));
    return;
  }
  final fromWeb = decodePlannerDocument(file.readAsBytesSync());
  if (fromWeb.name != 'Из веб-версии' ||
      !fromWeb.usesCurrentModel ||
      fromWeb.plan.dives.length != native.plan.dives.length ||
      fromWeb.results.length != native.results.length ||
      fromWeb.plan.dives.last.surfaceIntervalMin !=
          native.plan.dives.last.surfaceIntervalMin) {
    throw StateError('The native decoder did not recover the web document.');
  }
}
