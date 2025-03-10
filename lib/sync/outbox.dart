import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_fgbg/flutter_fgbg.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/sync_message.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/sync_config_service.dart';
import 'package:lotti/services/vector_clock_service.dart';
import 'package:lotti/sync/encryption.dart';
import 'package:lotti/sync/outbox_imap.dart';
import 'package:lotti/utils/audio_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/utils/platform.dart';
import 'package:mutex/mutex.dart';
import 'package:path_provider/path_provider.dart';

class OutboxService {
  final SyncConfigService _syncConfigService = getIt<SyncConfigService>();
  ConnectivityResult? _connectivityResult;
  final LoggingDb _loggingDb = getIt<LoggingDb>();

  final sendMutex = Mutex();
  final SyncDatabase _syncDatabase = getIt<SyncDatabase>();
  String? _b64Secret;
  bool enabled = true;

  late final StreamSubscription<FGBGType> fgBgSubscription;
  Timer? timer;

  OutboxService() {
    init();

    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      _connectivityResult = result;
      debugPrint('Connectivity onConnectivityChanged $result');
      _loggingDb.captureEvent(
        'OUTBOX: Connectivity onConnectivityChanged $result',
        domain: 'OUTBOX_CUBIT',
      );

      if (result == ConnectivityResult.none) {
        stopPolling();
      } else {
        startPolling();
      }
    });

    if (isMobile) {
      fgBgSubscription = FGBGEvents.stream.listen((event) {
        _loggingDb.captureEvent(event, domain: 'OUTBOX_CUBIT');
        if (event == FGBGType.foreground) {
          startPolling();
        }
        if (event == FGBGType.background) {
          stopPolling();
        }
      });
    }
  }

  Future<void> init() async {
    SyncConfig? syncConfig = await _syncConfigService.getSyncConfig();

    if (syncConfig != null) {
      _b64Secret = syncConfig.sharedSecret;
      startPolling();
    }
  }

  void reportConnectivity() async {
    _loggingDb.captureEvent(
      'reportConnectivity: $_connectivityResult',
      domain: 'OUTBOX_CUBIT',
    );
  }

  // Inserts a fault 25% of the time, where an exception would
  // have to be handled, a retry intent recorded, and a retry
  // scheduled. Improper handling of the retry would become
  // very obvious and painful very soon.
  String insertFault(String path) {
    Random random = Random();
    double randomNumber = random.nextDouble();
    return (randomNumber < 0.25) ? '${path}Nope' : path;
  }

  Future<List<OutboxItem>> getNextItems() async {
    return await _syncDatabase.oldestOutboxItems(10);
  }

  void sendNext({ImapClient? imapClient}) async {
    _loggingDb.captureEvent('sendNext()', domain: 'OUTBOX_CUBIT');

    if (!enabled) return;

    final transaction = _loggingDb.startTransaction('sendNext()', 'task');
    try {
      _connectivityResult = await Connectivity().checkConnectivity();
      if (_connectivityResult == ConnectivityResult.none) {
        reportConnectivity();
        stopPolling();
        return;
      }

      if (_b64Secret != null) {
        // TODO: check why not working reliably on macOS - workaround
        bool isConnected = _connectivityResult != ConnectivityResult.none;

        if (isConnected && !sendMutex.isLocked) {
          List<OutboxItem> unprocessed = await getNextItems();
          if (unprocessed.isNotEmpty) {
            sendMutex.acquire();

            OutboxItem nextPending = unprocessed.first;
            try {
              String encryptedMessage = await encryptString(
                b64Secret: _b64Secret,
                plainText: nextPending.message,
              );

              String? filePath = nextPending.filePath;
              String? encryptedFilePath;

              if (filePath != null) {
                Directory docDir = await getApplicationDocumentsDirectory();
                File encryptedFile =
                    File('${docDir.path}${nextPending.filePath}.aes');
                File attachment = File(insertFault('${docDir.path}$filePath'));
                await encryptFile(attachment, encryptedFile, _b64Secret!);
                encryptedFilePath = encryptedFile.path;
              }

              ImapClient? successfulClient = await persistImap(
                encryptedFilePath: encryptedFilePath,
                subject: nextPending.subject,
                encryptedMessage: encryptedMessage,
                prevImapClient: imapClient,
              );
              if (successfulClient != null) {
                _syncDatabase.updateOutboxItem(
                  OutboxCompanion(
                    id: Value(nextPending.id),
                    status: Value(OutboxStatus.sent.index),
                    updatedAt: Value(DateTime.now()),
                  ),
                );
                if (unprocessed.length > 1) {
                  sendNext(imapClient: successfulClient);
                }
              }
            } catch (e) {
              _syncDatabase.updateOutboxItem(
                OutboxCompanion(
                  id: Value(nextPending.id),
                  status: Value(nextPending.retries < 10
                      ? OutboxStatus.pending.index
                      : OutboxStatus.error.index),
                  retries: Value(nextPending.retries + 1),
                  updatedAt: Value(DateTime.now()),
                ),
              );
              stopPolling();
            } finally {
              if (sendMutex.isLocked) {
                sendMutex.release();
              }
            }
          } else {
            stopPolling();
          }
        }
      } else {
        stopPolling();
      }
    } catch (exception, stackTrace) {
      await _loggingDb.captureException(
        exception,
        domain: 'OUTBOX',
        subDomain: 'sendNext',
        stackTrace: stackTrace,
      );
      if (sendMutex.isLocked) {
        sendMutex.release();
      }
    }
    await transaction.finish();
  }

  void startPolling() async {
    SyncConfig? syncConfig = await _syncConfigService.getSyncConfig();

    if (syncConfig == null) {
      _loggingDb.captureEvent('Sync config missing -> polling not started',
          domain: 'OUTBOX_CUBIT');
      return;
    }

    _loggingDb.captureEvent('startPolling()', domain: 'OUTBOX_CUBIT');

    if ((timer != null && timer!.isActive) || false) {
      return;
    }

    sendNext();
    timer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      _connectivityResult = await Connectivity().checkConnectivity();
      _loggingDb.captureEvent('_connectivityResult: $_connectivityResult',
          domain: 'OUTBOX_CUBIT');

      List<OutboxItem> unprocessed = await getNextItems();

      if (_connectivityResult == ConnectivityResult.none ||
          unprocessed.isEmpty) {
        timer.cancel();
        _loggingDb.captureEvent('timer cancelled', domain: 'OUTBOX_CUBIT');
      } else {
        sendNext();
      }
    });
  }

  void stopPolling() async {
    if (timer != null) {
      _loggingDb.captureEvent('stopPolling()', domain: 'OUTBOX_CUBIT');

      timer?.cancel();
      timer = null;
    }
  }

  Future<void> enqueueMessage(SyncMessage syncMessage) async {
    if (syncMessage is SyncJournalEntity) {
      final transaction =
          _loggingDb.startTransaction('enqueueMessage()', 'task');
      try {
        JournalEntity journalEntity = syncMessage.journalEntity;
        String jsonString = json.encode(syncMessage);
        var docDir = await getApplicationDocumentsDirectory();
        final VectorClockService vectorClockService =
            getIt<VectorClockService>();

        File? attachment;
        String host = await vectorClockService.getHost();
        String hostHash = await vectorClockService.getHostHash();
        int? localCounter = journalEntity.meta.vectorClock?.vclock[host];
        String subject = '$hostHash:$localCounter';

        journalEntity.maybeMap(
          journalAudio: (JournalAudio journalAudio) {
            if (syncMessage.status == SyncEntryStatus.initial) {
              attachment = File(AudioUtils.getAudioPath(journalAudio, docDir));
            }
          },
          journalImage: (JournalImage journalImage) {
            if (syncMessage.status == SyncEntryStatus.initial) {
              attachment =
                  File(getFullImagePathWithDocDir(journalImage, docDir));
            }
          },
          orElse: () {},
        );

        int fileLength = attachment?.lengthSync() ?? 0;
        await _syncDatabase.addOutboxItem(OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          filePath: Value(
              (fileLength > 0) ? getRelativeAssetPath(attachment!.path) : null),
          subject: Value(subject),
          message: Value(jsonString),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

        await transaction.finish();
        startPolling();
      } catch (exception, stackTrace) {
        await _loggingDb.captureException(
          exception,
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
          stackTrace: stackTrace,
        );
      }
    }

    if (syncMessage is SyncEntityDefinition) {
      final transaction =
          _loggingDb.startTransaction('enqueueMessage()', 'task');
      try {
        String jsonString = json.encode(syncMessage);
        final VectorClockService vectorClockService =
            getIt<VectorClockService>();

        String host = await vectorClockService.getHost();
        String hostHash = await vectorClockService.getHostHash();
        int? localCounter =
            syncMessage.entityDefinition.vectorClock?.vclock[host];
        String subject = '$hostHash:$localCounter';

        await _syncDatabase.addOutboxItem(OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: Value(subject),
          message: Value(jsonString),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

        await transaction.finish();
        startPolling();
      } catch (exception, stackTrace) {
        await _loggingDb.captureException(
          exception,
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
          stackTrace: stackTrace,
        );
      }
    }

    if (syncMessage is SyncEntryLink) {
      final transaction =
          _loggingDb.startTransaction('enqueueMessage()', 'link');
      try {
        String jsonString = json.encode(syncMessage);
        final VectorClockService vectorClockService =
            getIt<VectorClockService>();

        String hostHash = await vectorClockService.getHostHash();
        String subject = '$hostHash:link';

        await _syncDatabase.addOutboxItem(OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: Value(subject),
          message: Value(jsonString),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

        await transaction.finish();
        startPolling();
      } catch (exception, stackTrace) {
        await _loggingDb.captureException(
          exception,
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
          stackTrace: stackTrace,
        );
      }
    }

    if (syncMessage is SyncTagEntity) {
      final transaction =
          _loggingDb.startTransaction('enqueueMessage()', 'tag');
      try {
        String jsonString = json.encode(syncMessage);
        final VectorClockService vectorClockService =
            getIt<VectorClockService>();

        String hostHash = await vectorClockService.getHostHash();
        String subject = '$hostHash:tag';

        await _syncDatabase.addOutboxItem(OutboxCompanion(
          status: Value(OutboxStatus.pending.index),
          subject: Value(subject),
          message: Value(jsonString),
          createdAt: Value(DateTime.now()),
          updatedAt: Value(DateTime.now()),
        ));

        await transaction.finish();
        startPolling();
      } catch (exception, stackTrace) {
        await _loggingDb.captureException(
          exception,
          domain: 'OUTBOX',
          subDomain: 'enqueueMessage',
          stackTrace: stackTrace,
        );
      }
    }
  }
}
