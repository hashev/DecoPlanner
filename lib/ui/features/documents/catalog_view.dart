import '../../core/planner_dialog.dart';
import 'dart:math';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import '../../../data/models/planner_document.dart';
import '../plan/gas_usage_view.dart';
import '../plan/switches_editor.dart';
import 'document_session.dart';

String catalogId() =>
    'item-${List.generate(16, (_) => Random.secure().nextInt(256).toRadixString(16).padLeft(2, '0')).join()}';
Future<String?> editCatalogName(
  BuildContext context, {
  String initial = '',
  String title = 'Название в справочнике',
  String action = 'Сохранить в справочник',
}) => showPlannerDialog<String>(
  context: context,
  builder: (_) => _NameEditor(initial: initial, title: title, action: action),
);

class _NameEditor extends StatefulWidget {
  const _NameEditor({
    required this.initial,
    required this.title,
    required this.action,
  });
  final String initial, title, action;
  @override
  State<_NameEditor> createState() => _NameEditorState();
}

class _NameEditorState extends State<_NameEditor> {
  final form = GlobalKey<FormState>();
  late final name = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    name.dispose();
    super.dispose();
  }

  void save() {
    if (form.currentState!.validate()) Navigator.pop(context, name.text.trim());
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.title),
    content: Form(
      key: form,
      child: TextFormField(
        controller: name,
        autofocus: true,
        decoration: const InputDecoration(labelText: 'Название'),
        validator: (v) => (v ?? '').trim().isEmpty || v!.trim().length > 160
            ? 'Введите название от 1 до 160 символов'
            : null,
        onFieldSubmitted: (_) => save(),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отменить'),
      ),
      FilledButton(onPressed: save, child: Text(widget.action)),
    ],
  );
}

class CatalogView extends StatelessWidget {
  const CatalogView({super.key, required this.session});
  final DocumentSession session;
  Future<bool> confirm(BuildContext context, String name) async =>
      await showPlannerDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Удалить «$name»?'),
          content: const Text(
            'Применённые к планам и расходу копии останутся без изменений. Прямых ссылок на справочник в плане нет.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Отменить'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Удалить'),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> gasSet(BuildContext context, GasSetPreset? initial) async {
    final switches = initial?.switches ?? session.model.selected.switches;
    final values = await editGasSwitches(
      context,
      initial: switches,
      units: session.model.units,
      ccr:
          switches.any((s) => s.breathing.mode == BreathingMode.ccr) ||
          session.model.selected.levels.any(
            (l) => l.breathing.mode == BreathingMode.ccr,
          ),
    );
    if (values == null || !context.mounted) return;
    final name = await editCatalogName(
      context,
      initial: initial?.name ?? 'Набор газов',
    );
    if (name == null || !context.mounted) return;
    session.saveGasSet(
      GasSetPreset(
        id: initial?.id ?? catalogId(),
        name: name,
        switches: values,
      ),
    );
  }

  Future<void> tank(BuildContext context, TankPreset? initial) async {
    final value = await editTankParameters(
      context,
      waterLitres: initial?.waterLitres ?? 12,
      workingBar: initial?.workingBar ?? 232,
      editableCount: false,
      nominalCapacity: true,
      units: session.model.units,
    );
    if (value == null || !context.mounted) return;
    final name = await editCatalogName(
      context,
      initial: initial?.name ?? 'Баллон',
    );
    if (name == null || !context.mounted) return;
    session.saveTank(
      TankPreset(
        id: initial?.id ?? catalogId(),
        name: name,
        waterLitres: value.waterLitres,
        workingBar: value.workingBar,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: session,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Справочники')),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                const Text(
                  'Наборы и баллоны сохраняются с документом. Применение создаёт физическую копию; редактирование справочника не изменяет планы.',
                ),
                const SizedBox(height: 16),
                Text(
                  'Наборы газов',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                if (session.document.gasSets.isEmpty)
                  const Text('Сохранённых наборов нет'),
                for (final set in session.document.gasSets)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(set.name),
                          Text('Переключений: ${set.switches.length}'),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => gasSet(context, set),
                                child: const Text('Редактировать набор'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  if (await confirm(context, set.name)) {
                                    session.deleteGasSet(set.id);
                                  }
                                },
                                child: const Text('Удалить набор'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => gasSet(context, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить набор газов'),
                ),
                const SizedBox(height: 24),
                Text('Баллоны', style: Theme.of(context).textTheme.titleLarge),
                if (session.document.tanks.isEmpty)
                  const Text('Сохранённых баллонов нет'),
                for (final value in session.document.tanks)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(value.name),
                          Text(
                            '${value.waterLitres} L · ${usagePressure(value.workingBar, session.model.units)}',
                          ),
                          Wrap(
                            spacing: 8,
                            children: [
                              TextButton(
                                onPressed: () => tank(context, value),
                                child: const Text('Редактировать баллон'),
                              ),
                              TextButton(
                                onPressed: () async {
                                  if (await confirm(context, value.name)) {
                                    session.deleteTank(value.id);
                                  }
                                },
                                child: const Text('Удалить баллон'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                OutlinedButton.icon(
                  onPressed: () => tank(context, null),
                  icon: const Icon(Icons.add),
                  label: const Text('Добавить баллон'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
