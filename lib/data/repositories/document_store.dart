import '../models/planner_document.dart';

final class LoadedDocument {
  const LoadedDocument(
    this.document, {
    this.recoveredFromBackup = false,
    this.primaryFailure,
  });
  final PlannerDocument document;
  final bool recoveredFromBackup;
  final DocumentFailure? primaryFailure;
}

final class DocumentEntry {
  const DocumentEntry(this.id, {this.loaded, this.failure});
  final String id;
  final LoadedDocument? loaded;
  final DocumentFailure? failure;
}

abstract interface class DocumentStore {
  Future<LoadedDocument> load(String id);
  Future<List<DocumentEntry>> list();
  Future<void> save(PlannerDocument document);
  Future<void> rename(String id, String name, {DateTime? modifiedAt});
  Future<void> delete(String id);
}
