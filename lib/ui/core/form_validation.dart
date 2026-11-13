import 'dart:async';
import 'package:flutter/material.dart';

/// Reveal the first invalid field after its error has been laid out.
bool validatePlannerForm(GlobalKey<FormState> key) {
  final errors = key.currentState!.validateGranularly();
  if (errors.isEmpty) return true;
  final first = errors.first;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!first.mounted) return;
    EditableText? input;
    void visit(Element element) {
      if (input != null) return;
      if (element.widget case final EditableText field) {
        input = field;
      } else {
        element.visitChildElements(visit);
      }
    }

    (first.context as Element).visitChildElements(visit);
    input?.focusNode.requestFocus();
    unawaited(Scrollable.ensureVisible(first.context, alignment: .1));
  });
  return false;
}
