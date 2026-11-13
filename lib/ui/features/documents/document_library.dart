import '../../core/planner_dialog.dart';
import 'package:flutter/material.dart';
import '../../../data/models/planner_document.dart';
import '../../../data/repositories/document_repository.dart';
import '../../../data/services/document_files.dart';
import 'document_session.dart';

String documentFailureText(DocumentFailure failure) => switch (failure.kind) {
  DocumentFailureKind.unsupportedSchema =>
    'Этот документ создан в более новой версии приложения.',
  DocumentFailureKind.tooLarge =>
    'Документ превышает допустимый размер 32 МиБ.',
  DocumentFailureKind.integrity =>
    'Нарушена целостность документа. Проверьте резервную копию.',
  DocumentFailureKind.invalidDocument => 'Некорректный документ или имя плана.',
  DocumentFailureKind.notFound => 'Документ не найден или уже удалён.',
  DocumentFailureKind.io =>
    'Не удалось выполнить операцию с файлом. Данные остались в редакторе.',
};

class DocumentLibrary extends StatefulWidget {
  const DocumentLibrary({
    super.key,
    required this.session,
    this.files = const NativeDocumentFiles(),
  });
  final DocumentSession session;
  final DocumentFiles files;
  @override
  State<DocumentLibrary> createState() => _DocumentLibraryState();
}

class _DocumentLibraryState extends State<DocumentLibrary> {
  late Future<List<DocumentEntry>> entries = widget.session.list();
  bool working = false;
  String? message;

  Future<void> _run(Future<void> Function() action) async {
    if (working) return;
    setState(() {
      working = true;
      message = null;
    });
    try {
      await action();
    } on DocumentFailure catch (failure) {
      if (mounted) setState(() => message = documentFailureText(failure));
    } finally {
      if (mounted) {
        setState(() {
          working = false;
          entries = widget.session.list();
        });
      }
    }
  }

  void _result(bool success, String text) {
    if (!mounted) return;
    setState(
      () => message = success
          ? text
          : documentFailureText(widget.session.failure!),
    );
  }

  Future<void> _rename(DocumentEntry entry) async {
    final name = await showPlannerDialog<String>(
      context: context,
      builder: (_) => _DocumentNameDialog(name: entry.loaded!.document.name),
    );
    if (name != null) {
      _result(
        await widget.session.rename(entry.id, name),
        'Название сохранено',
      );
    }
  }

  Future<void> _delete(DocumentEntry entry) async {
    final confirmed = await showPlannerDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить план?'),
        content: Text(
          '«${entry.loaded?.document.name ?? entry.id}» и его локальная резервная копия будут удалены.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      _result(await widget.session.delete(entry.id), 'План удалён');
    }
  }

  Future<void> _import() async {
    final bytes = await widget.files.pickJson();
    if (bytes == null) return;
    _result(
      await widget.session.importBytes(bytes),
      'Документ импортирован. Результаты требуют пересчёта.',
    );
  }

  Future<void> _export() async {
    final box = context.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    final result = await widget.files.exportJson(
      await widget.session.exportBytes(),
      widget.session.document.name,
      origin,
    );
    if (!mounted) return;
    setState(
      () => message = switch (result) {
        DocumentExport.cancelled => null,
        DocumentExport.saved => 'JSON сохранён',
        DocumentExport.shared => 'JSON передан выбранному приложению',
        DocumentExport.handedOff =>
          'Открыто системное меню. Сохранение файла не подтверждено.',
      },
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Документы')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Текущий план: ${widget.session.document.name}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: working
                        ? null
                        : () => _run(() async {
                            _result(
                              await widget.session.save(),
                              'План сохранён',
                            );
                          }),
                    icon: const Icon(Icons.save_outlined),
                    label: const Text('Сохранить план'),
                  ),
                  OutlinedButton.icon(
                    onPressed: working
                        ? null
                        : () => _run(() async {
                            _result(
                              await widget.session.create(),
                              'Создан новый план',
                            );
                          }),
                    icon: const Icon(Icons.add),
                    label: const Text('Новый план'),
                  ),
                  OutlinedButton.icon(
                    onPressed: working ? null : () => _run(_import),
                    icon: const Icon(Icons.file_open_outlined),
                    label: const Text('Импорт JSON'),
                  ),
                  OutlinedButton.icon(
                    onPressed: working ? null : () => _run(_export),
                    icon: const Icon(Icons.ios_share),
                    label: const Text('Экспорт JSON'),
                  ),
                ],
              ),
              if (working)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Операция с документом…'),
                ),
              if (message != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Semantics(liveRegion: true, child: Text(message!)),
                ),
              if (widget.session.recoveredFromBackup)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Текущий документ восстановлен из резервной копии. Проверьте последние изменения.',
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Локальные планы',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              FutureBuilder<List<DocumentEntry>>(
                future: entries,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return const Text(
                      'Не удалось прочитать список документов.',
                    );
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.data!.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Сохранённых планов пока нет'),
                    );
                  }
                  return Column(
                    children: [
                      for (final entry in snapshot.data!)
                        Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry.loaded?.document.name ?? entry.id,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                                if (entry.failure != null)
                                  Text(documentFailureText(entry.failure!)),
                                if (entry.loaded?.recoveredFromBackup == true)
                                  const Text('Доступна резервная копия'),
                                if (entry.loaded != null)
                                  Text(
                                    '${entry.loaded!.document.plan.dives.length} погр. · ${entry.loaded!.document.modifiedAt.toLocal().toIso8601String().substring(0, 16).replaceFirst('T', ' ')}',
                                  ),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 4,
                                  children: [
                                    if (entry.loaded != null)
                                      TextButton(
                                        onPressed: working
                                            ? null
                                            : () => _run(() async {
                                                final success = await widget
                                                    .session
                                                    .open(entry.id);
                                                if (success &&
                                                    context.mounted) {
                                                  Navigator.pop(context);
                                                } else {
                                                  _result(false, '');
                                                }
                                              }),
                                        child: const Text('Открыть'),
                                      ),
                                    if (entry.loaded != null)
                                      TextButton(
                                        onPressed: working
                                            ? null
                                            : () => _run(() => _rename(entry)),
                                        child: const Text('Переименовать'),
                                      ),
                                    TextButton(
                                      onPressed: working
                                          ? null
                                          : () => _run(() => _delete(entry)),
                                      child: const Text('Удалить'),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _DocumentNameDialog extends StatefulWidget {
  const _DocumentNameDialog({required this.name});
  final String name;
  @override
  State<_DocumentNameDialog> createState() => _DocumentNameDialogState();
}

class _DocumentNameDialogState extends State<_DocumentNameDialog> {
  late final controller = TextEditingController(text: widget.name);
  final form = GlobalKey<FormState>();
  void submit() {
    if (form.currentState!.validate()) {
      Navigator.pop(context, controller.text.trim());
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Переименовать план'),
    content: SingleChildScrollView(
      child: Form(
        key: form,
        child: TextFormField(
          controller: controller,
          autofocus: true,
          maxLength: 160,
          decoration: const InputDecoration(labelText: 'Название'),
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Введите название' : null,
          onFieldSubmitted: (_) => submit(),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Отмена'),
      ),
      FilledButton(onPressed: submit, child: const Text('Сохранить')),
    ],
  );
}
