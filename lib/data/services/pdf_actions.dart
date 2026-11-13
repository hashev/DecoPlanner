import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/services.dart';
import 'package:printing/printing.dart';
import 'document_files.dart';

enum PdfActionResult { completed, cancelled, handedOff }

final class PdfCapabilities {
  const PdfCapabilities({required this.canPrint, required this.canShare});
  final bool canPrint, canShare;
}

abstract interface class PdfActions {
  bool get saveUsesShare;
  Future<PdfCapabilities> capabilities();
  Future<PdfActionResult> print(Uint8List bytes);
  Future<PdfActionResult> save(Uint8List bytes, String name, Rect origin);
  Future<PdfActionResult> share(Uint8List bytes, String name, Rect origin);
}

final class NativePdfActions implements PdfActions {
  const NativePdfActions();
  @override
  Future<PdfCapabilities> capabilities() async {
    final info = await Printing.info();
    return PdfCapabilities(canPrint: info.canPrint, canShare: info.canShare);
  }

  @override
  bool get saveUsesShare => Platform.isAndroid || Platform.isIOS;
  @override
  Future<PdfActionResult> print(Uint8List bytes) async =>
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Deco Planner',
        // This is a frozen PDF. Dynamic macOS layout blocks its main thread
        // while requesting Dart bytes, deadlocking with merged UI/platform threads.
        dynamicLayout: false,
      )
      ? PdfActionResult.completed
      : PdfActionResult.cancelled;
  @override
  Future<PdfActionResult> share(
    Uint8List bytes,
    String name,
    Rect origin,
  ) async =>
      await Printing.sharePdf(bytes: bytes, filename: name, bounds: origin)
      ? PdfActionResult.handedOff
      : PdfActionResult.cancelled;
  @override
  Future<PdfActionResult> save(
    Uint8List bytes,
    String name,
    Rect origin,
  ) async {
    if (saveUsesShare) return share(bytes, name, origin);
    final target = await getSaveLocation(
      suggestedName: name,
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'PDF',
          extensions: ['pdf'],
          mimeTypes: ['application/pdf'],
          uniformTypeIdentifiers: ['com.adobe.pdf'],
        ),
      ],
    );
    if (target == null) return PdfActionResult.cancelled;
    await File(target.path).writeAsBytes(bytes, flush: true);
    return PdfActionResult.completed;
  }
}

String pdfFileName(String name) =>
    '${documentFileName(name).replaceFirst(RegExp(r'\.json$'), '')}.pdf';
