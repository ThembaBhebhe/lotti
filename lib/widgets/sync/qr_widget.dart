import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/classes/config.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/misc/buttons.dart';
import 'package:lotti/widgets/sync/qr_reader_widget.dart';
import 'package:qr_flutter/qr_flutter.dart';

class EncryptionQrWidget extends StatelessWidget {
  const EncryptionQrWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    if (Platform.isIOS || Platform.isAndroid) {
      return const EncryptionQrReaderWidget();
    }
    return BlocBuilder<SyncConfigCubit, SyncConfigState>(
        builder: (context, SyncConfigState state) {
      return Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Button(
              localizations.settingsSyncGenKeyButton,
              onPressed: () =>
                  context.read<SyncConfigCubit>().generateSharedKey(),
              primaryColor: Colors.red,
            ),
            const Padding(padding: EdgeInsets.all(8.0)),
            state.when(
              (String? sharedKey, ImapConfig? imapConfig) {
                if (sharedKey != null && imapConfig != null) {
                  SyncConfig syncConfig = SyncConfig(
                    imapConfig: imapConfig,
                    sharedSecret: sharedKey,
                  );
                  String syncCfgJson = json.encode(syncConfig);
                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.all(
                            Radius.circular(8.0),
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () {
                            showDialog<String>(
                              context: context,
                              builder: (BuildContext context) => AlertDialog(
                                title: Text(
                                  localizations.settingsSyncCopyCfg,
                                  style: const TextStyle(fontFamily: 'Oswald'),
                                ),
                                content: Text(
                                  localizations.settingsSyncCopyCfgWarning,
                                  style: const TextStyle(fontFamily: 'Lato'),
                                ),
                                actions: <Widget>[
                                  Button(
                                    localizations.settingsSyncCancelButton,
                                    onPressed: () {
                                      Navigator.pop(context, 'Cancel');
                                    },
                                    primaryColor: Colors.grey,
                                  ),
                                  Button(
                                    localizations.settingsSyncCopyButton,
                                    onPressed: () {
                                      Clipboard.setData(
                                          ClipboardData(text: syncCfgJson));
                                      Navigator.pop(context, 'Copy SyncConfig');
                                    },
                                    primaryColor: Colors.red,
                                  ),
                                ],
                              ),
                            );
                          },
                          child: QrImage(
                            data: syncCfgJson,
                            version: QrVersions.auto,
                            size: 280.0,
                          ),
                        ),
                      ),
                      Button(localizations.settingsSyncDeleteKeyButton,
                          onPressed: () =>
                              context.read<SyncConfigCubit>().deleteSharedKey(),
                          primaryColor: Colors.red),
                    ],
                  );
                } else {
                  return StatusTextWidget(
                      localizations.settingsSyncIncompleteConfig);
                }
              },
              loading: () =>
                  StatusTextWidget(localizations.settingsSyncLoadingKey),
              generating: () =>
                  StatusTextWidget(localizations.settingsSyncGenKey),
              empty: () => Column(
                children: [
                  StatusTextWidget(localizations.settingsSyncNotInitialized),
                  Button(
                    localizations.settingsSyncPasteCfg,
                    onPressed: () {
                      showDialog<String>(
                        context: context,
                        builder: (BuildContext context) => AlertDialog(
                          title: Text(
                            localizations.settingsSyncPasteCfg,
                            style: const TextStyle(fontFamily: 'Oswald'),
                          ),
                          content: Text(
                            localizations.settingsSyncPasteCfgWarning,
                            style: const TextStyle(fontFamily: 'Lato'),
                          ),
                          actions: <Widget>[
                            Button(
                              localizations.settingsSyncCancelButton,
                              onPressed: () {
                                Navigator.pop(context, 'Cancel');
                              },
                              primaryColor: Colors.grey,
                            ),
                            Button(
                              localizations.settingsSyncImportButton,
                              onPressed: () async {
                                ClipboardData? data =
                                    await Clipboard.getData('text/plain');
                                String? syncCfg = data?.text;
                                if (syncCfg != null) {
                                  context
                                      .read<SyncConfigCubit>()
                                      .setSyncConfig(syncCfg);
                                }
                                Navigator.pop(context, 'Import SyncConfig');
                              },
                              primaryColor: Colors.red,
                            ),
                          ],
                        ),
                      );
                    },
                    primaryColor: Colors.red,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    });
  }
}

class StatusTextWidget extends StatelessWidget {
  final String label;
  const StatusTextWidget(
    this.label, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'ShareTechMono',
          color: AppColors.entryTextColor,
        ),
      ),
    );
  }
}
