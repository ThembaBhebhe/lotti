import 'package:drift/drift.dart' as drift;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/outbox_state.dart';
import 'package:lotti/database/sync_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';

class OutboxMonitorPage extends StatefulWidget {
  const OutboxMonitorPage({Key? key}) : super(key: key);

  @override
  State<OutboxMonitorPage> createState() => _OutboxMonitorPageState();
}

class _OutboxMonitorPageState extends State<OutboxMonitorPage> {
  final SyncDatabase _db = getIt<SyncDatabase>();
  late Stream<List<OutboxItem>> stream =
      _db.watchOutboxItems(statuses: [OutboxStatus.pending]);
  String _selectedValue = 'pending';

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;

    return BlocBuilder<OutboxCubit, OutboxState>(
      builder: (_, OutboxState state) {
        return StreamBuilder<List<OutboxItem>>(
          stream: stream,
          builder: (
            BuildContext context,
            AsyncSnapshot<List<OutboxItem>> snapshot,
          ) {
            List<OutboxItem> items = snapshot.data ?? [];
            bool onlineStatus = state is! OutboxDisabled;

            return SingleChildScrollView(
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CupertinoSegmentedControl(
                        selectedColor: AppColors.entryBgColor,
                        unselectedColor: AppColors.headerBgColor,
                        borderColor: AppColors.entryBgColor,
                        groupValue: _selectedValue,
                        onValueChanged: (String value) {
                          setState(() {
                            _selectedValue = value;
                            if (_selectedValue == 'all') {
                              stream = _db.watchOutboxItems();
                            }
                            if (_selectedValue == 'pending') {
                              stream = _db.watchOutboxItems(
                                  statuses: [OutboxStatus.pending]);
                            }
                            if (_selectedValue == 'error') {
                              stream = _db.watchOutboxItems(
                                  statuses: [OutboxStatus.error]);
                            }
                          });
                        },
                        children: {
                          'pending': SizedBox(
                            width: 64,
                            height: 32,
                            child: Center(
                              child: Text(
                                localizations.outboxMonitorLabelPending,
                                style: segmentItemStyle,
                              ),
                            ),
                          ),
                          'error': SizedBox(
                            child: Center(
                              child: Text(
                                localizations.outboxMonitorLabelError,
                                style: segmentItemStyle,
                              ),
                            ),
                          ),
                          'all': SizedBox(
                            child: Center(
                              child: Text(
                                localizations.outboxMonitorLabelAll,
                                style: segmentItemStyle,
                              ),
                            ),
                          ),
                        },
                      ),
                      CupertinoSwitch(
                        value: onlineStatus,
                        onChanged: (_) {
                          context.read<OutboxCubit>().toggleStatus();
                        },
                      ),
                    ],
                  ),
                  ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.all(8.0),
                    children: List.generate(
                      items.length,
                      (int index) {
                        return OutboxItemCard(
                          item: items.elementAt(index),
                          index: index,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class OutboxItemCard extends StatelessWidget {
  final SyncDatabase _db = getIt<SyncDatabase>();
  final OutboxItem item;
  final int index;

  OutboxItemCard({
    Key? key,
    required this.item,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    AppLocalizations localizations = AppLocalizations.of(context)!;
    OutboxStatus statusEnum = OutboxStatus.values[item.status];

    String getStringFromStatus(OutboxStatus x) {
      switch (x) {
        case OutboxStatus.pending:
          return localizations.outboxMonitorLabelPending;
        case OutboxStatus.sent:
          return localizations.outboxMonitorLabelSent;
        default:
          return localizations.outboxMonitorLabelError;
      }
    }

    String status = getStringFromStatus(statusEnum);

    Color cardColor(OutboxStatus status) {
      switch (statusEnum) {
        case OutboxStatus.pending:
          return AppColors.outboxPendingColor;
        case OutboxStatus.error:
          return AppColors.outboxErrorColor;
        default:
          return AppColors.outboxSuccessColor;
      }
    }

    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: Card(
        color: cardColor(statusEnum),
        elevation: 8.0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: SingleChildScrollView(
          child: ListTile(
            contentPadding: const EdgeInsets.only(left: 24, right: 24),
            title: Text(
              '${df.format(item.createdAt)} - $status',
              style: TextStyle(
                color: AppColors.entryTextColor,
                fontFamily: 'Oswald',
                fontSize: 16.0,
              ),
            ),
            subtitle: Text(
              '${item.retries} ${localizations.outboxMonitorRetries} - '
              '${item.filePath ?? localizations.outboxMonitorNoAttachment}',
              style: TextStyle(
                color: AppColors.entryTextColor,
                fontFamily: 'Oswald',
                fontWeight: FontWeight.w200,
                fontSize: 16.0,
              ),
            ),
            enabled: true,
            onTap: () {
              if (statusEnum == OutboxStatus.error) {
                _db.updateOutboxItem(
                  OutboxCompanion(
                    id: drift.Value(item.id),
                    status: drift.Value(OutboxStatus.pending.index),
                    retries: drift.Value(item.retries + 1),
                    updatedAt: drift.Value(DateTime.now()),
                  ),
                );
              }
            },
          ),
        ),
      ),
    );
  }
}
