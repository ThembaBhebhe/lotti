import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_image_slideshow/flutter_image_slideshow.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/theme.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:lotti/widgets/journal/editor/editor_wrapper_widget.dart';
import 'package:path_provider/path_provider.dart';

class SlideShowWidget extends StatelessWidget {
  final List<JournalEntity> items;
  const SlideShowWidget(
    this.items, {
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    List<JournalImage> imageItems = items.whereType<JournalImage>().toList();

    return Container(
      color: Colors.black,
      child: ImageSlideshow(
        width: double.infinity,
        height: double.infinity,
        initialPage: 0,
        indicatorColor: AppColors.bottomNavIconSelected,
        indicatorBackgroundColor: AppColors.bottomNavIconUnselected,
        onPageChanged: (value) {
          debugPrint('Page changed: $value');
        },
//        autoPlayInterval: 1000,
        isLoop: true,
        children: [
          ...List.generate(
            imageItems.length,
            (int index) {
              JournalImage item = imageItems.elementAt(index);
              return Stack(
                children: [
                  Align(
                    child: CardImageWidget(
                      height: MediaQuery.of(context).size.height.ceil(),
                      journalImage: item,
                    ),
                  ),
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: ClipRRect(
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(16.0),
                        topRight: Radius.circular(16.0),
                      ),
                      child: Container(
                        color: Colors.white,
                        padding: const EdgeInsets.only(bottom: 8),
                        constraints: const BoxConstraints(
                          maxHeight: 200,
                          minHeight: 80,
                        ),
                        width: MediaQuery.of(context).size.width,
                        child: EditorWrapperWidget(
                          popOnDelete: false,
                          itemId: item.meta.id,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
            growable: true,
          ),
        ],
      ),
    );
  }
}

class CardImageWidget extends StatefulWidget {
  final JournalImage journalImage;
  final int height;
  final BoxFit fit;

  const CardImageWidget(
      {Key? key,
      required this.journalImage,
      required this.height,
      this.fit = BoxFit.scaleDown})
      : super(key: key);

  @override
  State<CardImageWidget> createState() => _CardImageWidgetState();
}

class _CardImageWidgetState extends State<CardImageWidget> {
  Directory? docDir;

  @override
  void initState() {
    super.initState();

    getApplicationDocumentsDirectory().then((value) {
      setState(() {
        docDir = value;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (docDir != null) {
      File file =
          File(getFullImagePathWithDocDir(widget.journalImage, docDir!));

      return Container(
        color: Colors.black,
        height: widget.height.toDouble(),
        child: Image.file(
          file,
          cacheHeight: widget.height * 3,
          height: widget.height.toDouble(),
          fit: widget.fit,
        ),
      );
    } else {
      return Container();
    }
  }
}
