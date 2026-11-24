import 'document_repository.dart';

Future<DocumentStore> openDocumentStore() => DocumentRepository.application();
