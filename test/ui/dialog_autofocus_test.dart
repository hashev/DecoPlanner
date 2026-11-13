import 'package:deco_planner/ui/features/documents/catalog_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('dialog Escape policy preserves name field autofocus', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => editCatalogName(context),
              child: const Text('Открыть'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Открыть'));
    await tester.pumpAndSettle();
    final field = tester.widget<TextFormField>(find.byType(TextFormField));
    final context = FocusManager.instance.primaryFocus?.context;
    final editable = context?.widget is EditableText
        ? context!.widget as EditableText
        : context?.findAncestorWidgetOfExactType<EditableText>();
    expect(editable?.controller, same(field.controller));
    expect(tester.testTextInput.hasAnyClients, isTrue);
  });
}
