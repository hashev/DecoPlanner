import 'package:deco_planner/data/services/pdf_actions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('net.nfet.printing');
  test(
    'frozen PDF printing disables dynamic layout and preserves native cancellation',
    () async {
      var printed = false;
      binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
        call,
      ) async {
        if (call.method == 'printingInfo') {
          return {'canPrint': true, 'canShare': true};
        }
        if (call.method == 'printPdf') {
          printed = true;
          final args = call.arguments as Map;
          expect(
            args['dynamic'],
            isFalse,
            reason:
                'Dynamic macOS layout blocks the merged UI/platform thread waiting for Dart bytes.',
          );
          binding.channelBuffers.push(
            channel.name,
            const StandardMethodCodec().encodeMethodCall(
              MethodCall('onCompleted', {
                'job': args['job'],
                'completed': false,
              }),
            ),
            (_) {},
          );
          return 1;
        }
        throw StateError('Unexpected method ${call.method}');
      });
      addTearDown(
        () => binding.defaultBinaryMessenger.setMockMethodCallHandler(
          channel,
          null,
        ),
      );
      const actions = NativePdfActions();
      expect((await actions.capabilities()).canPrint, isTrue);
      expect(
        await actions.print(Uint8List.fromList([37, 80, 68, 70])),
        PdfActionResult.cancelled,
      );
      expect(printed, isTrue);
    },
  );
}
