import '../ui/core/planner_dialog.dart';
import '../domain/planner_report.dart';
import '../ui/features/export/report_view.dart';
import 'dart:convert';
import 'dart:async';
import 'package:deco_core/deco_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import '../ui/core/planner_theme.dart';
import '../data/repositories/document_repository.dart';
import '../ui/features/documents/document_session.dart';
import '../ui/features/documents/document_library.dart';
import '../data/services/calculation_worker.dart';
import '../ui/features/plan/level_editor.dart';
import '../ui/features/plan/gas_usage_view.dart';
import '../ui/features/plan/settings_editor.dart';
import '../ui/features/plan/profile_view.dart';
import '../domain/profile_data.dart';
import '../ui/features/tools/gas_property_tools.dart';
import '../ui/features/range/range_view.dart';
import '../ui/features/plan/switches_editor.dart';
import '../ui/features/documents/catalog_view.dart';
import '../data/models/planner_document.dart';
import '../ui/features/plan/bailout_editor.dart';
import '../ui/features/plan/planner_view_model.dart';

class PlannerApp extends StatefulWidget {
  const PlannerApp({super.key, this.viewModel, this.documentSession});
  final PlannerViewModel? viewModel;
  final DocumentSession? documentSession;
  @override
  State<PlannerApp> createState() => _PlannerAppState();
}

class _PlannerAppState extends State<PlannerApp> with WidgetsBindingObserver {
  late final model =
      widget.viewModel ?? widget.documentSession?.model ?? PlannerViewModel();
  DocumentSession? documents;
  bool loading = false;
  String? storageError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    documents = widget.documentSession;
    assert(documents == null || identical(documents!.model, model));
    if (widget.viewModel == null && documents == null) {
      loading = true;
      unawaited(_initializeDocuments());
    }
  }

  Future<void> _initializeDocuments() async {
    try {
      final repository = await DocumentRepository.application();
      if (!mounted) return;
      final session = DocumentSession(model: model, repository: repository);
      documents = session;
      await session.initialize();
    } catch (_) {
      storageError = 'Локальное хранилище недоступно. Сохранение не настроено.';
    }
    if (mounted) setState(() => loading = false);
  }

  @override
  void didChangeAccessibilityFeatures() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      final session = documents;
      if (session != null) unawaited(session.save());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (widget.documentSession == null) documents?.dispose();
    if (widget.viewModel == null && widget.documentSession == null) {
      model.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([model, documents]),
    builder: (context, _) => MaterialApp(
      title: 'Планировщик погружений',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: plannerTheme(Brightness.light),
      darkTheme: plannerTheme(Brightness.dark),
      themeMode: model.theme,
      themeAnimationDuration:
          WidgetsBinding
              .instance
              .platformDispatcher
              .accessibilityFeatures
              .disableAnimations
          ? Duration.zero
          : kThemeAnimationDuration,
      home: loading
          ? const Scaffold(
              body: Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Открытие документов',
                ),
              ),
            )
          : _PlannerShell(
              key: ValueKey(documents?.document.id),
              model: model,
              documents: documents,
              storageError: storageError,
            ),
    ),
  );
}

class _PlannerShell extends StatefulWidget {
  const _PlannerShell({
    super.key,
    required this.model,
    this.documents,
    this.storageError,
  });
  final PlannerViewModel model;
  final DocumentSession? documents;
  final String? storageError;
  @override
  State<_PlannerShell> createState() => _PlannerShellState();
}

class _PlannerShellState extends State<_PlannerShell> {
  int destination = 0;
  static const labels = ['План', 'Инструменты', 'Настройки'];
  static const icons = [
    Icons.list_alt_outlined,
    Icons.science_outlined,
    Icons.settings_outlined,
  ];
  @override
  Widget build(BuildContext context) => CallbackShortcuts(
    bindings: {
      const SingleActivator(LogicalKeyboardKey.enter, meta: true): () =>
          unawaited(widget.model.calculateSelection()),
      const SingleActivator(LogicalKeyboardKey.enter, control: true): () =>
          unawaited(widget.model.calculateSelection()),
    },
    child: Focus(
      autofocus: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final small = constraints.maxWidth < 600;
          final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
          final content = IndexedStack(
            index: destination,
            children: [
              _PlanWorkspace(
                model: widget.model,
                documents: widget.documents,
                storageError: widget.storageError,
                wide: constraints.maxWidth >= 1000 && !largeText,
              ),
              GasPropertyTools(
                model: widget.model,
                tanks: widget.documents?.document.tanks ?? const [],
              ),
              _Settings(model: widget.model, documents: widget.documents),
            ],
          );
          return Scaffold(
            appBar: AppBar(
              title: const Text('Планировщик'),
              actions: [
                if (widget.documents != null)
                  IconButton(
                    tooltip: 'Документы',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            DocumentLibrary(session: widget.documents!),
                      ),
                    ),
                    icon: const Icon(
                      Icons.folder_open,
                      semanticLabel: 'Документы',
                    ),
                  ),
                IconButton(
                  tooltip: 'Справка',
                  onPressed: () => _help(context),
                  icon: const Icon(
                    Icons.help_outline,
                    semanticLabel: 'Справка',
                  ),
                ),
              ],
            ),
            body: SafeArea(
              child: Row(
                children: [
                  if (!small)
                    NavigationRail(
                      selectedIndex: destination,
                      onDestinationSelected: (i) =>
                          setState(() => destination = i),
                      labelType: NavigationRailLabelType.none,
                      destinations: [
                        for (var i = 0; i < labels.length; i++)
                          NavigationRailDestination(
                            icon: Tooltip(
                              message: labels[i],
                              child: Icon(icons[i], semanticLabel: labels[i]),
                            ),
                            label: Text(labels[i]),
                          ),
                      ],
                    ),
                  Expanded(child: content),
                ],
              ),
            ),
            bottomNavigationBar: !small
                ? null
                : largeText
                ? SafeArea(
                    child: Row(
                      children: [
                        for (var i = 0; i < labels.length; i++)
                          Expanded(
                            child: Semantics(
                              selected: destination == i,
                              child: TextButton(
                                onPressed: () =>
                                    setState(() => destination = i),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icons[i]),
                                    Text(
                                      labels[i],
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  )
                : NavigationBar(
                    selectedIndex: destination,
                    onDestinationSelected: (i) =>
                        setState(() => destination = i),
                    destinations: [
                      for (var i = 0; i < labels.length; i++)
                        NavigationDestination(
                          icon: Icon(icons[i]),
                          label: labels[i],
                        ),
                    ],
                  ),
          );
        },
      ),
    ),
  );
  Future<void> _help(BuildContext context) async {
    final text = await rootBundle.loadString('assets/help/planner.txt');
    if (!context.mounted) return;
    await showPlannerDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Справка'),
        scrollable: true,
        content: Text(text),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }
}

class _PlanWorkspace extends StatelessWidget {
  const _PlanWorkspace({
    required this.model,
    required this.wide,
    this.documents,
    this.storageError,
  });
  final PlannerViewModel model;
  final bool wide;
  final DocumentSession? documents;
  final String? storageError;
  @override
  Widget build(BuildContext context) {
    final dive = model.selected,
        snapshot = model.displaySnapshot,
        units = model.units;
    final branch = model.selectedBailout;
    final editor = <Widget>[
      if (storageError != null) Text(storageError!),
      if (documents != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  documents!.document.name,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    documents!.failure != null
                        ? documentFailureText(documents!.failure!)
                        : documents!.busy
                        ? 'Сохранение…'
                        : documents!.dirty
                        ? 'Есть несохранённые изменения'
                        : 'Сохранено локально',
                  ),
                ),
                if (documents!.recoveredFromBackup)
                  const Text('Восстановлено из резервной копии'),
                TextButton.icon(
                  onPressed: documents!.busy ? null : () => documents!.save(),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Сохранить'),
                ),
              ],
            ),
          ),
        ),
      Text('План погружений', style: Theme.of(context).textTheme.titleLarge),
      TextButton.icon(
        key: const Key('edit-switches'),
        onPressed: () async {
          final source = model.selected;
          final switches = await editGasSwitches(
            context,
            initial: source.switches,
            presets: documents?.document.gasSets ?? const [],
            savePreset: documents == null
                ? null
                : (switches) async {
                    final name = await editCatalogName(
                      context,
                      initial: 'Набор газов',
                    );
                    if (name == null || !context.mounted) return null;
                    final value = GasSetPreset(
                      id: catalogId(),
                      name: name,
                      switches: switches,
                    );
                    documents!.saveGasSet(value);
                    return value;
                  },
            units: model.units,
            ccr: source.levels.any(
              (level) => level.breathing.mode == BreathingMode.ccr,
            ),
          );
          if (switches != null &&
              context.mounted &&
              model.selected.id == source.id) {
            model.replaceSwitches(switches);
          }
        },
        icon: const Icon(Icons.swap_vert),
        label: Text('Газы и переключения (${dive.switches.length})'),
      ),

      const SizedBox(height: 16),
      DropdownButtonFormField<int>(
        key: ValueKey('selected-${dive.id}'),
        initialValue: model.selectedIndex,
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Погружение'),
        items: [
          for (var i = 0; i < model.dives.length; i++)
            DropdownMenuItem(value: i, child: Text('Погружение ${i + 1}')),
        ],
        onChanged: (i) {
          if (i != null) {
            model.select(i);
          }
        },
      ),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          TextButton.icon(
            onPressed: model.addDive,
            icon: const Icon(Icons.add),
            label: const Text('Добавить погружение'),
          ),
          IconButton(
            tooltip: 'Погружение вверх',
            onPressed: model.selectedIndex > 0
                ? () => model.moveDive(-1)
                : null,
            icon: const Icon(
              Icons.arrow_upward,
              semanticLabel: 'Погружение вверх',
            ),
          ),
          IconButton(
            tooltip: 'Погружение вниз',
            onPressed: model.selectedIndex < model.dives.length - 1
                ? () => model.moveDive(1)
                : null,
            icon: const Icon(
              Icons.arrow_downward,
              semanticLabel: 'Погружение вниз',
            ),
          ),
          TextButton(
            onPressed: model.dives.length > 1
                ? () async {
                    if (await _confirm(context, 'Удалить погружение?')) {
                      model.removeDive();
                    }
                  }
                : null,
            child: const Text('Удалить погружение'),
          ),
        ],
      ),
      if (model.selectedIndex > 0)
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 16),
          child: OutlinedButton(
            onPressed: () async {
              final id = dive.id;
              final value = await _editInterval(
                context,
                dive.surfaceIntervalMin,
              );
              if (value != null && model.selected.id == id) {
                model.setSurfaceInterval(value);
              }
            },
            child: Text(
              'Интервал ${number(dive.surfaceIntervalMin)} мин · изменить',
            ),
          ),
        ),
      const SizedBox(height: 16),
      Text(_modelSummary(dive.settings)),
      const Divider(height: 32),
      Text('Уровни', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      for (var i = 0; i < dive.levels.length; i++)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Уровень ${i + 1}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    '${_shortDepth(dive.levels[i].depthMetres, units)} ${depthUnit(units)} · ${number(dive.levels[i].durationMin)} мин',
                  ),
                  Text(
                    '${dive.levels[i].breathing.mode.name.toUpperCase()} · O₂/He ${_gas(dive.levels[i].breathing)}',
                  ),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: [
                      TextButton(
                        onPressed: () => _edit(context, i),
                        child: const Text('Изменить'),
                      ),
                      IconButton(
                        tooltip: 'Уровень ${i + 1} вверх',
                        onPressed: i > 0 ? () => _move(i, -1) : null,
                        icon: Icon(
                          Icons.arrow_upward,
                          semanticLabel: 'Уровень ${i + 1} вверх',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Уровень ${i + 1} вниз',
                        onPressed: i < dive.levels.length - 1
                            ? () => _move(i, 1)
                            : null,
                        icon: Icon(
                          Icons.arrow_downward,
                          semanticLabel: 'Уровень ${i + 1} вниз',
                        ),
                      ),
                      IconButton(
                        tooltip: 'Удалить уровень ${i + 1}',
                        onPressed: dive.levels.length > 1
                            ? () async {
                                if (await _confirm(
                                  context,
                                  'Удалить уровень ${i + 1}?',
                                )) {
                                  final levels = dive.levels.toList()
                                    ..removeAt(i);
                                  model.replaceLevels(levels);
                                }
                              }
                            : null,
                        icon: Icon(
                          Icons.delete_outline,
                          semanticLabel: 'Удалить уровень ${i + 1}',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      OutlinedButton.icon(
        onPressed: () => _edit(context, null),
        icon: const Icon(Icons.add),
        label: const Text('Добавить уровень'),
      ),
      const SizedBox(height: 16),
      Text(
        dive.settings.includeDescentInLevelTime
            ? 'Спуск включён в длительность уровня.'
            : 'Спуск добавляется к длительности уровня.',
      ),
      if (dive.levels.any((l) => l.breathing.mode == BreathingMode.ccr) ||
          model.selectedDiveBailouts.isNotEmpty) ...[
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          key: ValueKey('scenario-${dive.id}-${branch?.id}'),
          initialValue: branch?.id ?? dive.id,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Сценарий результата'),
          items: [
            DropdownMenuItem(
              value: dive.id,
              child: const Text('Исходный план'),
            ),
            for (var i = 0; i < model.selectedDiveBailouts.length; i++)
              DropdownMenuItem(
                value: model.selectedDiveBailouts[i].id,
                child: Text('Bailout ${i + 1}'),
              ),
          ],
          onChanged: (id) => model.selectBailout(id == dive.id ? null : id),
        ),
        if (branch != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'CCR → OC на ${number(branch.runtimeMin)} мин · источник: погружение ${model.selectedIndex + 1}, revision ${model.snapshot.inputRevision}',
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (dive.levels.any((l) => l.breathing.mode == BreathingMode.ccr))
              TextButton.icon(
                key: const Key('create-bailout'),
                onPressed: () => _editBailout(context),
                icon: const Icon(Icons.call_split),
                label: const Text('Создать bailout'),
              ),
            if (branch != null) ...[
              TextButton.icon(
                key: const Key('edit-bailout'),
                onPressed: () => _editBailout(context, initial: branch),
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Изменить bailout'),
              ),
              TextButton.icon(
                onPressed: () async {
                  if (await _confirm(context, 'Удалить bailout-сценарий?')) {
                    model.removeSelectedBailout();
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: const Text('Удалить bailout'),
              ),
            ],
          ],
        ),
      ],
      const SizedBox(height: 16),
      FilledButton.icon(
        key: const Key('calculate'),
        onPressed: model.calculating
            ? null
            : () => unawaited(model.calculateSelection()),
        icon: const Icon(Icons.calculate_outlined),
        label: Text(branch == null ? 'Рассчитать' : 'Рассчитать bailout'),
      ),
      if (model.calculating)
        TextButton(
          onPressed: model.cancel,
          child: const Text('Отменить расчёт'),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const Key('range-view'),
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(
            builder: (_) => RangeView(
              model: model,
              sourceId: dive.id,
              bailoutId: branch?.id,
            ),
          ),
        ),
        icon: const Icon(Icons.grid_on),
        label: const Text('Таблицы диапазонов'),
      ),
      const SizedBox(height: 8),
      TextButton(
        onPressed: () async {
          if (await _confirm(
            context,
            model.toolDraft['profile:keepComparisonsOnReset'] == 'false'
                ? 'Сбросить уровни, газы и удалить снимки сравнения?'
                : 'Сбросить уровни и газы?',
          )) {
            documents?.prepareProfileReset();
            model.resetSelected();
          }
        },
        child: const Text('Сбросить погружение'),
      ),
    ];
    final result = snapshot.result;
    // Cached schedules do not retain the original RMV/grid settings. Never
    // derive a historical volume using newly edited settings.
    final usage = result != null && snapshot.status == PlanStatus.ready
        ? calculateGasUsage(
            result,
            dive.settings,
            stopsPerGroup: model.ratioStops,
          )
        : null;
    final resultCount = 4 + (result?.segments.length ?? 0);
    final knownProfile = documents?.knownProfile(result?.diveId ?? '');
    final frozenSettings = knownProfile?.plan.dives
        .where((value) => value.id == dive.id)
        .firstOrNull
        ?.settings;
    final profileSettings = snapshot.status == PlanStatus.ready
        ? dive.settings
        : identical(knownProfile?.results[result?.diveId]?.result, result)
        ? frozenSettings
        : null;
    Widget resultItem(int index) {
      if (index == 0) {
        return Text(
          branch == null ? 'Результат' : 'Bailout · результат',
          style: Theme.of(context).textTheme.titleLarge,
        );
      }
      if (index == 1) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: _Status(snapshot: snapshot),
        );
      }
      if (index == 2) {
        return result == null
            ? const Text('Задайте профиль и нажмите «Рассчитать».')
            : Wrap(
                spacing: 24,
                runSpacing: 16,
                children: [
                  _Metric(
                    'Общее время',
                    '${result.runtimeMin.toStringAsFixed(1)} мин',
                  ),
                  _Metric(
                    'Подъём',
                    '${result.ascentMin.toStringAsFixed(1)} мин',
                  ),
                  _Metric(
                    'Декомпрессия',
                    '${result.decompressionMin.toStringAsFixed(1)} мин',
                  ),
                  _Metric(
                    'CNS',
                    result.finalState.oxygen.cnsFraction == null
                        ? 'Недоступен'
                        : '${(result.finalState.oxygen.cnsFraction! * 100).toStringAsFixed(1)} %',
                  ),
                  _Metric(
                    'OTU',
                    result.finalState.oxygen.otu.toStringAsFixed(1),
                  ),
                ],
              );
      }
      if (index == 3) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (result?.finalState.oxygen.cnsUnavailableReason != null)
                const Text(
                  'CNS недоступен: ppO₂ превысило область модели 1,6 ATA. Декомпрессия и OTU рассчитаны.',
                ),
              const Text('Один дайвер · без резервов'),
              if (result != null) ...[
                Text(
                  'Первая остановка ${_shortDepth(result.firstStopMetres, units)} ${depthUnit(units)}',
                ),
                Text(
                  'Давление поверхности ${usagePressure(result.pressure.surfaceBar, units)}',
                ),
                if (snapshot.status == PlanStatus.ready) ...[
                  Text(_modelSummary(dive.settings)),
                  if (dive.settings.altitude.enabled)
                    Text(
                      'Высота ${_shortDepth(dive.settings.altitude.diveAltitudeMetres, units)} ${depthUnit(units)}',
                    ),
                ],
                if (result.finalState.vpm != null &&
                    _decoZoneDepth(result) != null)
                  Text(
                    'Начало декомпрессионной зоны VPM ${_shortDepth(_decoZoneDepth(result)!, units)} ${depthUnit(units)}',
                  ),
                TextButton.icon(
                  key: const Key('report-view'),
                  onPressed: snapshot.status != PlanStatus.ready
                      ? null
                      : () {
                          final report = PlannerReport.dive(
                            result: result,
                            request: dive,
                            bailout: branch,
                            units: units,
                          );
                          Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => ReportView(
                                report: report,
                                changes: model,
                                isCurrent: () =>
                                    model.displaySnapshot.status ==
                                        PlanStatus.ready &&
                                    identical(
                                      model.displaySnapshot.result,
                                      result,
                                    ),
                              ),
                            ),
                          );
                        },
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Печатный вид'),
                ),
                TextButton.icon(
                  key: const Key('gas-usage'),
                  onPressed: usage == null
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ListenableBuilder(
                              listenable: model,
                              builder: (context, _) =>
                                  model.displaySnapshot.status ==
                                          PlanStatus.ready &&
                                      identical(
                                        model.displaySnapshot.result,
                                        result,
                                      )
                                  ? GasUsageView(
                                      report: usage,
                                      tanks:
                                          documents?.document.tanks ?? const [],
                                      units: model.units,
                                      drafts: model.toolDraft,
                                      onDraft: model.setToolDraft,
                                    )
                                  : Scaffold(
                                      appBar: AppBar(
                                        title: const Text('Расход газа'),
                                      ),
                                      body: const Padding(
                                        padding: EdgeInsets.all(16),
                                        child: Text(
                                          'Результат изменён. Вернитесь к плану и пересчитайте.',
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.propane_tank_outlined),
                  label: const Text('Расход газа и баллоны'),
                ),
                TextButton.icon(
                  key: const Key('profile-view'),
                  onPressed: profileSettings == null
                      ? null
                      : () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => ProfileView(
                              data: ProfileData(
                                result: result,
                                settings: profileSettings,
                              ),
                              model: model,
                              documents: documents,
                            ),
                          ),
                        ),
                  icon: const Icon(Icons.show_chart),
                  label: const Text('Профиль и ткани'),
                ),

                if (usage == null)
                  const Text('Расход и GF доступны после актуального расчёта.'),
              ],
              if (result != null)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: Text('Сегменты · раскройте строку для подробностей'),
                ),
            ],
          ),
        );
      }
      final segment = result!.segments[index - 4], physical = segment.physical;
      return Card(
        child: ExpansionTile(
          key: PageStorageKey('result-segment-${index - 4}'),
          title: wide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        '${_shortDepth(physical.startDepthMetres, units)} → ${_shortDepth(physical.endDepthMetres, units)} ${depthUnit(units)}',
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${physical.durationMin.toStringAsFixed(2)} / ${segment.endMin.toStringAsFixed(2)}',
                      ),
                    ),
                    Expanded(
                      child: Text(
                        '${physical.breathing.mode.name.toUpperCase()} ${_gas(physical.breathing)}',
                      ),
                    ),
                  ],
                )
              : Text(
                  '${_shortDepth(physical.startDepthMetres, units)} → ${_shortDepth(physical.endDepthMetres, units)} ${depthUnit(units)}',
                ),
          subtitle: Text(
            '${physical.breathing.mode.name.toUpperCase()} · ${_phase(segment.phase)} · ${physical.durationMin.toStringAsFixed(2)} мин · до ${segment.endMin.toStringAsFixed(2)}',
          ),
          childrenPadding: const EdgeInsets.all(16),
          expandedCrossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Газ ${physical.breathing.mode.name.toUpperCase()} · O₂/He ${_gas(physical.breathing)}',
            ),
            if (physical.breathing.setpointBar != null)
              Text(
                'Setpoint ${Units.barToAta(physical.breathing.setpointBar!).toStringAsFixed(2)} ATA',
              ),
            Text(
              'Начало ${segment.startMin.toStringAsFixed(3)} мин · конец ${segment.endMin.toStringAsFixed(3)} мин',
            ),
            Text(
              'Давление ${result.pressure.ambientBar(physical.endDepthMetres).toStringAsFixed(3)} bar',
            ),
            Text(
              'ppO₂ в конце ${Units.barToAta(_segmentOxygenBar(physical, result.pressure)).toStringAsFixed(3)} ATA',
            ),
            Text(
              'Плотность ${physical.breathing.mode == BreathingMode.ccr ? 'сухой смеси контура' : 'газа'} в конце ${_segmentDensity(physical, result.pressure).toStringAsFixed(3)} g/L',
            ),
            if (usage != null)
              Text(
                'Расход сегмента ${usageVolume(usage.segments[index - 4].litres, units)}${physical.breathing.mode == BreathingMode.ccr ? ' · кислород CCR' : ''}',
              ),
            if (usage != null && dive.settings.model != DecompressionModel.vpmB)
              Text(
                'GF по глубине ${(dive.settings.gradientFactors.atDepth(depthMetres: physical.endDepthMetres, firstStopMetres: result.firstStopMetres) * 100).toStringAsFixed(1)} %',
              ),
            if (usage != null && dive.settings.model == DecompressionModel.vpmB)
              const Text('GF неприменим к VPM-B'),
            Text(
              'CNS ${segment.endState.oxygen.cnsFraction == null ? 'недоступен' : '${(segment.endState.oxygen.cnsFraction! * 100).toStringAsFixed(2)} %'} · OTU ${segment.endState.oxygen.otu.toStringAsFixed(2)}',
            ),
          ],
        ),
      );
    }

    if (wide) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 360, child: ListView(children: editor)),
            const SizedBox(width: 24),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (result != null)
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 8, 48, 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: Text('Глубина')),
                          Expanded(child: Text('Время / конец, мин')),
                          Expanded(child: Text('Режим · O₂/He')),
                        ],
                      ),
                    ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: resultCount,
                      itemBuilder: (context, i) => resultItem(i),
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: editor.length + resultCount,
          itemBuilder: (context, i) => i < editor.length
              ? editor[i]
              : Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: resultItem(i - editor.length),
                ),
        ),
      ),
    );
  }

  Future<void> _editBailout(
    BuildContext context, {
    BailoutRequest? initial,
  }) async {
    final source = model.selected;
    final value = await editBailout(
      context,
      source: source,
      units: model.units,
      initial: initial,
      sourceResult: model.snapshot.status == PlanStatus.ready
          ? model.snapshot.result
          : null,
    );
    if (value != null && context.mounted && model.selected.id == source.id) {
      model.saveBailout(
        id: initial?.id,
        runtimeMin: value.runtimeMin,
        initialOcGas: value.initialOcGas,
        switches: value.switches,
      );
    }
  }

  void _move(int index, int delta) {
    final levels = model.selected.levels.toList();
    final value = levels.removeAt(index);
    levels.insert(index + delta, value);
    model.replaceLevels(levels);
  }

  Future<void> _edit(BuildContext context, int? index) async {
    final dive = model.selected, id = dive.id;
    final level = index == null
        ? Level(
            depthMetres: 21,
            durationMin: 5,
            breathing: dive.levels.last.breathing,
          )
        : dive.levels[index];
    final value = await editLevel(
      context,
      level: level,
      units: model.units,
      previousDepth: index == null
          ? dive.levels.last.depthMetres
          : index == 0
          ? 0
          : dive.levels[index - 1].depthMetres,
      settings: dive.settings,
    );
    if (value == null || model.selected.id != id) return;
    final levels = dive.levels.toList();
    if (index == null) {
      levels.add(value);
    } else {
      levels[index] = value;
    }
    model.replaceLevels(levels);
  }
}

class _Status extends StatelessWidget {
  const _Status({required this.snapshot});
  final DiveSnapshot snapshot;
  @override
  Widget build(BuildContext context) {
    final message = switch (snapshot.status) {
      PlanStatus.draft => 'Черновик — результат ещё не рассчитан',
      PlanStatus.calculating => 'Расчёт…',
      PlanStatus.ready => 'Расчёт завершён',
      PlanStatus.stale => 'Входы изменены — пересчитайте',
      PlanStatus.error => _error(snapshot.failure),
    };
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            if (snapshot.result != null && snapshot.status != PlanStatus.ready)
              const Text(
                'Показан предыдущий результат. Для актуальных данных выполните расчёт.',
              ),
            if (snapshot.status == PlanStatus.calculating)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: LinearProgressIndicator(),
              ),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label),
      Text(
        value,
        style: const TextStyle(fontFamily: 'Fira Code', fontSize: 24),
      ),
    ],
  );
}

String _shortDepth(double metres, DisplayUnits units) =>
    (units == DisplayUnits.metric ? metres : Units.metresToFeet(metres))
        .toStringAsFixed(1);
String _gas(BreathingGas gas) =>
    '${(gas.gas.oxygen * 100).toStringAsFixed(0)}/${(gas.gas.helium * 100).toStringAsFixed(0)} %';
String _phase(SegmentPhase phase) => switch (phase) {
  SegmentPhase.levelTravel => 'Переход уровня',
  SegmentPhase.levelHold => 'Выдержка',
  SegmentPhase.ascent => 'Подъём',
  SegmentPhase.decompression => 'Остановка',
};
String _error(WorkerFailure? failure) {
  if (failure?.kind == WorkerFailureKind.timeout) {
    return 'Время расчёта превышено. Ввод сохранён; попробуйте ещё раз.';
  }
  if (failure?.calculationFailure?.code ==
      CalculationFailureCode.invalidInput) {
    return 'Проверьте профиль: длительности уровня должно хватать на спуск, а состав газа должен быть допустимым.';
  }
  return 'Не удалось рассчитать план. Ввод сохранён. Проверьте параметры и повторите расчёт.';
}

Future<bool> _confirm(BuildContext context, String message) async =>
    await showPlannerDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отменить'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    ) ??
    false;

class _Settings extends StatelessWidget {
  const _Settings({required this.model, this.documents});
  final PlannerViewModel model;
  final DocumentSession? documents;
  Future<void> edit(BuildContext context) async {
    final source = model.selected;
    final value = await editCalculationSettings(
      context,
      initial: source.settings,
      ratioStops: model.ratioStops,
      units: model.units,
      allowDefaults: documents != null,
    );
    if (value == null || !context.mounted || model.selected.id != source.id) {
      return;
    }
    if (value.action == SettingsAction.saveDefaults) {
      documents!.saveDefaultSettings(
        value.settings,
        ratioStops: value.ratioStops,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Сохранено для новых планов. Текущее погружение не изменено.',
          ),
        ),
      );
    } else {
      if (jsonEncode(source.settings.toJson()) !=
          jsonEncode(value.settings.toJson())) {
        model.replaceSettings(value.settings);
      }
      model.setToolDraft('ratio:stops', value.ratioStops.toString());
    }
  }

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Настройки', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => edit(context),
            icon: const Icon(Icons.tune),
            label: const Text('Расчётные настройки'),
          ),
          const SizedBox(height: 24),
          if (documents != null)
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => CatalogView(session: documents!),
                ),
              ),
              icon: const Icon(Icons.inventory_2_outlined),
              label: const Text('Справочники газов и баллонов'),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Профиль: только подъём и остановки'),
            value: model.toolDraft['profile:ascentOnly'] == 'true',
            onChanged: (value) =>
                model.setToolDraft('profile:ascentOnly', value.toString()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Сохранять предыдущий профиль при пересчёте'),
            subtitle: const Text(
              'Именованные сравнения сохраняются независимо от этого параметра.',
            ),
            value: model.toolDraft['profile:keepPrevious'] == 'true',
            onChanged: (value) =>
                model.setToolDraft('profile:keepPrevious', value.toString()),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Сохранять снимки при сбросе погружения'),
            value: model.toolDraft['profile:keepComparisonsOnReset'] != 'false',
            onChanged: (value) => model.setToolDraft(
              'profile:keepComparisonsOnReset',
              value.toString(),
            ),
          ),
          const Text('Тема'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final theme in ThemeMode.values)
                ChoiceChip(
                  label: Text(switch (theme) {
                    ThemeMode.system => 'Системная',
                    ThemeMode.light => 'Светлая',
                    ThemeMode.dark => 'Тёмная',
                  }),
                  selected: model.theme == theme,
                  onSelected: (_) => model.setTheme(theme),
                ),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Единицы глубины'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final unit in DisplayUnits.values)
                ChoiceChip(
                  label: Text(unit == DisplayUnits.metric ? 'Метры' : 'Футы'),
                  selected: model.units == unit,
                  onSelected: (_) => model.setUnits(unit),
                ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Модель текущего погружения: ${_modelSummary(model.selected.settings)}',
          ),
          const SizedBox(height: 16),
          Text(
            model.selected.settings.model == DecompressionModel.vpmB
                ? 'Консерватизм ${model.selected.settings.vpmConservatism}'
                : 'GF ${(model.selected.settings.gradientFactors.low * 100).round()}/${(model.selected.settings.gradientFactors.high * 100).round()}',
          ),
          const SizedBox(height: 24),
          const Text(
            'Сетка остановок сохраняет физические величины при смене единиц.',
          ),
          const SizedBox(height: 24),
          OutlinedButton(
            onPressed: () => showLicensePage(
              context: context,
              applicationName: 'Планировщик',
            ),
            child: const Text('Лицензии компонентов'),
          ),
        ],
      ),
    ),
  );
}

Future<double?> _editInterval(BuildContext context, double minutes) {
  var draft = number(minutes);
  final form = GlobalKey<FormState>();
  return showPlannerDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Поверхностный интервал'),
      scrollable: true,
      content: Form(
        key: form,
        child: TextFormField(
          initialValue: draft,
          autofocus: true,
          onChanged: (text) => draft = text,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Длительность, мин'),
          validator: (text) {
            final n = double.tryParse((text ?? '').replaceAll(',', '.'));
            return n == null || !n.isFinite || n < 0
                ? 'Введите число не меньше нуля'
                : null;
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отменить'),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, double.parse(draft.replaceAll(',', '.')));
            }
          },
          child: const Text('Сохранить'),
        ),
      ],
    ),
  );
}

String _modelSummary(CalculationSettings settings) {
  if (settings.model == DecompressionModel.vpmB) {
    return 'VPM-B · консерватизм ${settings.vpmConservatism}';
  }
  final name = settings.model == DecompressionModel.buhlmannB
      ? 'Bühlmann B'
      : 'Bühlmann C';
  return '$name · GF ${(settings.gradientFactors.low * 100).round()}/${(settings.gradientFactors.high * 100).round()}';
}

double _segmentOxygenBar(PropagationSegment segment, PressureContext pressure) {
  final ambient = pressure.ambientBar(segment.endDepthMetres);
  return segment.breathing.mode == BreathingMode.oc
      ? ambient * segment.breathing.gas.oxygen
      : (segment.breathing.setpointBar! < ambient
            ? segment.breathing.setpointBar!
            : ambient);
}

double _segmentDensity(PropagationSegment segment, PressureContext pressure) {
  var gas = segment.breathing.gas;
  if (segment.breathing.mode == BreathingMode.ccr) {
    final ambient = pressure.ambientBar(segment.endDepthMetres);
    final dry = ambient - pressure.waterVapourBar;
    final inert = inspiredInert(
      ambient,
      pressure.waterVapourBar,
      segment.breathing,
    );
    final helium = dry == 0 ? 0.0 : inert.helium / dry;
    final nitrogen = dry == 0 ? 0.0 : inert.nitrogen / dry;
    gas = Gas(oxygen: (1 - helium - nitrogen).clamp(0, 1), helium: helium);
  }
  return GasProperties.densityGramsPerLitre(
    gas,
    segment.endDepthMetres,
    pressure,
  );
}

double? _decoZoneDepth(CalculationResult result) {
  final time = result.finalState.vpm?.decoZoneStartMin;
  if (time == null || time <= 0) return null;
  for (final segment in result.segments) {
    if (time < segment.startMin || time > segment.endMin) continue;
    final physical = segment.physical;
    if (physical.durationMin == 0) return physical.endDepthMetres;
    return physical.startDepthMetres +
        (physical.endDepthMetres - physical.startDepthMetres) *
            (time - segment.startMin) /
            physical.durationMin;
  }
  return null;
}
