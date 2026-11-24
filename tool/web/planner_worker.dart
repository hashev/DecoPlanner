import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:deco_core/deco_core.dart';
import 'package:deco_planner/data/services/calculation_worker.dart';
import 'package:deco_planner/data/services/range_worker.dart';

@JS('self.onmessage')
external set _onMessage(JSFunction callback);

@JS('self.postMessage')
external void _postMessage(JSString message);

extension type _MessageEvent._(JSObject _) implements JSObject {
  external JSString get data;
}

void _send(Map<String, Object?> event) => _postMessage(jsonEncode(event).toJS);

RangeAxis _axis(Map<String, Object?> json) => RangeAxis(
  first: (json['first'] as num).toDouble(),
  last: (json['last'] as num).toDouble(),
  step: (json['step'] as num).toDouble(),
);

void main() {
  Completer<bool>? acknowledgement;
  _onMessage = ((_MessageEvent event) {
    final message = jsonDecode(event.data.toDart) as Map<String, Object?>;
    switch (message['operation']) {
      case 'calculation':
        runCalculationWorker(message, _send);
      case 'range':
        final identity = message['identity'] as Map<String, Object?>;
        final expected = CalculationIdentity(
          requestId: identity['requestId'] as int,
          inputRevision: identity['inputRevision'] as int,
          dependencyVersion: identity['dependencyVersion'] as String,
        );
        if (!expected.matches(identity)) {
          // The client rejects a response with an incompatible worker version.
          _send({'identity': expected.toJson()});
          return;
        }
        final bailout = message['bailout'] as Map<String, Object?>?;
        unawaited(
          runRangeWorker(
            identity: identity,
            source: DiveRequest.fromJson(
              message['source'] as Map<String, Object?>,
            ),
            bailout: bailout == null ? null : BailoutRequest.fromJson(bailout),
            depths: _axis(message['depths'] as Map<String, Object?>),
            durations: _axis(message['durations'] as Map<String, Object?>),
            variants: (message['variants'] as List<Object?>)
                .map((variant) => RangeVariant.values.byName(variant as String))
                .toList(),
            send: (response) => _send({
              ...response,
              if (response['cell'] case final RangeSummary cell)
                'cell': cell.toJson(),
              if (response['failure'] case final CalculationFailure failure)
                'failure': failure.toJson(),
            }),
            waitForAck: () {
              acknowledgement = Completer<bool>();
              return acknowledgement!.future;
            },
          ),
        );
      case 'rangeAck':
        final pending = acknowledgement;
        acknowledgement = null;
        pending?.complete(true);
    }
  }).toJS;
}
