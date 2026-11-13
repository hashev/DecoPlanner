import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import '../../../data/services/pdf_actions.dart';
import '../../../data/services/planner_pdf.dart';
import '../../../domain/planner_report.dart';

class ReportView extends StatefulWidget {
  const ReportView({
    super.key,
    required this.report,
    required this.changes,
    required this.isCurrent,
    this.actions = const NativePdfActions(),
    this.generate,
    this.preview,
  });
  final PlannerReport report;
  final Listenable changes;
  final bool Function() isCurrent;
  final PdfActions actions;
  final Future<Uint8List> Function(PlannerReport)? generate;
  final Widget Function(Uint8List)? preview;
  @override
  State<ReportView> createState() => _ReportViewState();
}

class _ReportViewState extends State<ReportView> {
  Uint8List? bytes;
  String? message;
  bool building = false, acting = false;
  PdfCapabilities? capabilities;
  @override
  void initState() {
    super.initState();
    loadCapabilities();
    buildPdf();
  }

  Future<void> loadCapabilities() async {
    PdfCapabilities value;
    try {
      value = await widget.actions.capabilities();
    } catch (_) {
      value = const PdfCapabilities(canPrint: false, canShare: false);
    }
    if (mounted) setState(() => capabilities = value);
  }

  Future<void> buildPdf() async {
    setState(() {
      building = true;
      message = null;
    });
    try {
      final value = await (widget.generate ?? const PlannerPdf().build)(
        widget.report,
      );
      if (mounted) setState(() => bytes = value);
    } catch (_) {
      if (mounted) {
        setState(
          () => message = 'Не удалось сформировать PDF. Повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => building = false);
    }
  }

  Future<void> act(int action) async {
    if (bytes == null || !widget.isCurrent() || acting) return;
    final box = context.findRenderObject() as RenderBox;
    final origin = box.localToGlobal(Offset.zero) & box.size;
    setState(() {
      acting = true;
      message = null;
    });
    try {
      final name = pdfFileName(widget.report.title);
      final result = await switch (action) {
        0 => widget.actions.print(bytes!),
        1 => widget.actions.save(bytes!, name, origin),
        _ => widget.actions.share(bytes!, name, origin),
      };
      if (mounted) {
        setState(
          () => message = switch (result) {
            PdfActionResult.completed => 'Действие завершено',
            PdfActionResult.cancelled =>
              'Действие отменено. PDF остаётся доступен.',
            PdfActionResult.handedOff => 'PDF передан системному диалогу',
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => message =
              'Не удалось выполнить действие. PDF сохранён в предпросмотре; повторите попытку.',
        );
      }
    } finally {
      if (mounted) setState(() => acting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.changes,
    builder: (context, _) {
      final current = widget.isCurrent();
      final enabled = bytes != null && !acting && current;
      return Scaffold(
        appBar: AppBar(title: const Text('Печатный вид')),
        body: SafeArea(
          child: Column(
            children: [
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .45,
                ),
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(widget.report.title),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            current
                                ? 'Снимок актуальных результатов'
                                : 'Входы изменены. Вернитесь и пересчитайте перед экспортом.',
                          ),
                        ),
                        if (capabilities case final c?) ...[
                          if (!c.canPrint)
                            const Text(
                              'Системная печать недоступна на этой платформе.',
                            ),
                          if (!c.canShare)
                            const Text(
                              'Системная отправка недоступна на этой платформе.',
                            ),
                        ],
                        if (message != null)
                          Semantics(liveRegion: true, child: Text(message!)),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            OutlinedButton.icon(
                              onPressed:
                                  enabled && capabilities?.canPrint == true
                                  ? () => act(0)
                                  : null,
                              icon: const Icon(Icons.print_outlined),
                              label: const Text('Печать'),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  enabled &&
                                      (!widget.actions.saveUsesShare ||
                                          capabilities?.canShare == true)
                                  ? () => act(1)
                                  : null,
                              icon: const Icon(Icons.save_alt),
                              label: Text(
                                widget.actions.saveUsesShare
                                    ? 'Сохранить через систему'
                                    : 'Сохранить PDF',
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed:
                                  enabled && capabilities?.canShare == true
                                  ? () => act(2)
                                  : null,
                              icon: const Icon(Icons.share_outlined),
                              label: const Text('Поделиться'),
                            ),
                            if (bytes == null && !building)
                              TextButton(
                                onPressed: buildPdf,
                                child: const Text('Повторить формирование'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (building || acting)
                const LinearProgressIndicator(semanticsLabel: 'Подготовка PDF'),
              Expanded(
                child: !current
                    ? const Center(child: Text('Устаревший PDF скрыт'))
                    : bytes == null
                    ? const Center(child: Text('Подготовка предпросмотра'))
                    : widget.preview?.call(bytes!) ??
                          PdfPreview(
                            build: (_) async => bytes!,
                            useActions: false,
                            canChangePageFormat: false,
                            canChangeOrientation: false,
                            allowPrinting: false,
                            allowSharing: false,
                            onError: (_, _) => const Center(
                              child: Text(
                                'Предпросмотр недоступен. Можно сохранить PDF или повторно открыть экран.',
                              ),
                            ),
                          ),
              ),
            ],
          ),
        ),
      );
    },
  );
}
