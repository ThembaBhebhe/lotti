import 'package:flutter/material.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/classes/tag_type_definitions.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/services/tags_service.dart';
import 'package:lotti/theme.dart';

class TagsViewWidget extends StatelessWidget {
  final TagsService tagsService = getIt<TagsService>();
  final JournalDb db = getIt<JournalDb>();

  TagsViewWidget({
    Key? key,
    required this.item,
  }) : super(key: key);

  final JournalEntity item;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<TagEntity>>(
      stream: db.watchTags(),
      builder: (
        BuildContext context,
        // This stream is not used, the StreamBuilder is only here
        // to trigger updates when any tag changes. In that case,
        // data in the tags service will already have been updated.
        AsyncSnapshot<List<TagEntity>> _,
      ) {
        List<String> tagIds = item.meta.tagIds ?? [];
        List<TagEntity> tagsFromTagIds = [];

        for (String tagId in tagIds) {
          TagEntity? tagEntity = tagsService.getTagById(tagId);
          if (tagEntity != null) {
            tagsFromTagIds.add(tagEntity);
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2.0),
          child: Column(
            children: [
              Wrap(
                spacing: 4,
                runSpacing: 4,
                children: tagsFromTagIds
                    .map((tagEntity) => TagChip(tagEntity))
                    .toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}

class TagChip extends StatelessWidget {
  final TagEntity tagEntity;

  const TagChip(
    this.tagEntity, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 1.0),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(chipBorderRadius),
        child: Container(
          padding: chipPadding,
          color: getTagColor(tagEntity),
          child: Text(
            tagEntity.tag,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'Oswald',
            ),
          ),
        ),
      ),
    );
  }
}
