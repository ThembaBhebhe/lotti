import 'package:flutter/material.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/widgets/journal/duration_widget.dart';
import 'package:lotti/widgets/journal/entry_details/delete_icon_widget.dart';
import 'package:lotti/widgets/journal/entry_details/share_button_widget.dart';
import 'package:lotti/widgets/journal/entry_tools.dart';
import 'package:lotti/widgets/misc/map_widget.dart';

class EntryDetailFooter extends StatefulWidget {
  final String itemId;
  final Function saveFn;
  final bool popOnDelete;

  const EntryDetailFooter({
    Key? key,
    required this.itemId,
    required this.saveFn,
    required this.popOnDelete,
  }) : super(key: key);

  @override
  State<EntryDetailFooter> createState() => _EntryDetailFooterState();
}

class _EntryDetailFooterState extends State<EntryDetailFooter> {
  bool mapVisible = false;

  final JournalDb db = getIt<JournalDb>();
  late final Stream<JournalEntity?> stream = db.watchEntityById(widget.itemId);

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<JournalEntity?>(
        stream: stream,
        builder: (
          BuildContext context,
          AsyncSnapshot<JournalEntity?> snapshot,
        ) {
          JournalEntity? item = snapshot.data;
          Geolocation? loc = item?.geolocation;

          if (item == null) {
            return const SizedBox.shrink();
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 8, right: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    DurationWidget(
                      item: item,
                      style: textStyle,
                      showControls: true,
                      saveFn: widget.saveFn,
                    ),
                    Visibility(
                      visible: loc != null && loc.longitude != 0,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Row(
                          children: [
                            TextButton(
                              onPressed: () => setState(() {
                                mapVisible = !mapVisible;
                              }),
                              child: Text(
                                '📍 ${formatLatLon(loc?.latitude)}, '
                                '${formatLatLon(loc?.longitude)}',
                                style: textStyle,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DeleteIconWidget(
                          entityId: widget.itemId,
                          popOnDelete: widget.popOnDelete,
                        ),
                        ShareButtonWidget(entityId: widget.itemId),
                      ],
                    ),
                  ],
                ),
              ),
              Visibility(
                visible: mapVisible,
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(8),
                    bottomRight: Radius.circular(8),
                  ),
                  child: MapWidget(
                    geolocation: item.geolocation,
                  ),
                ),
              ),
            ],
          );
        });
  }
}
