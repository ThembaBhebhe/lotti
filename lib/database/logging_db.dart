import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/database/stream_helpers.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/notification_service.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'logging_db.g.dart';

enum InsightLevel {
  error,
  warn,
  info,
  trace,
}

enum InsightType {
  log,
  exception,
}

@DriftDatabase(
  include: {'logging_db.drift'},
)
class LoggingDb extends _$LoggingDb {
  final JournalDb _journalDb = getIt<JournalDb>();

  LoggingDb() : super(_openConnection());

  @override
  int get schemaVersion => 1;

  Future<int> log(LogEntry logEntry) async {
    return into(logEntries).insert(logEntry);
  }

  Future<void> captureEvent(
    dynamic event, {
    required String domain,
    String? subDomain,
    InsightLevel level = InsightLevel.info,
    InsightType type = InsightType.log,
  }) async {
    log(LogEntry(
      id: uuid.v1(),
      createdAt: DateTime.now().toIso8601String(),
      domain: domain,
      subDomain: subDomain,
      message: event.toString(),
      level: level.name.toUpperCase(),
      type: type.name.toUpperCase(),
    ));
  }

  Future<void> captureException(
    dynamic exception, {
    required String domain,
    String? subDomain,
    dynamic stackTrace,
    InsightLevel level = InsightLevel.error,
    InsightType type = InsightType.exception,
  }) async {
    log(LogEntry(
      id: uuid.v1(),
      createdAt: DateTime.now().toIso8601String(),
      domain: domain,
      subDomain: subDomain,
      message: exception.toString(),
      stacktrace: stackTrace.toString(),
      level: level.name.toUpperCase(),
      type: type.name.toUpperCase(),
    ));

    bool notifyEnabled = await _journalDb.getConfigFlag('notify_exceptions');
    if (notifyEnabled) {
      String title = 'Exception in $domain $subDomain';
      getIt<NotificationService>().showNotification(
        title: title,
        body: exception.toString().substring(0, 195),
        notificationId: title.hashCode,
        deepLink: '/settings/logging',
      );
    }
  }

  Stream<List<LogEntry>> watchLogEntryById(String id) {
    return logEntryById(id).watch().where(makeDuplicateFilter());
  }

  InsightsSpan startTransaction(String name, String operation) {
    return InsightsSpan();
  }

  Stream<List<LogEntry>> watchLogEntries({
    int limit = 1000,
  }) {
    return allLogEntries(limit).watch();
  }
}

class InsightsSpan {
  Future<void> finish() async {}
  Future<void> error() async {}
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'logging_db.sqlite'));
    return NativeDatabase(file);
  });
}
