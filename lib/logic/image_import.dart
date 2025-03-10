import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:lotti/classes/geolocation.dart';
import 'package:lotti/classes/journal_entities.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/location.dart';
import 'package:lotti/logic/persistence_logic.dart';
import 'package:lotti/utils/file_utils.dart';
import 'package:lotti/utils/image_utils.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

Future<void> importImageAssets(
  BuildContext context, {
  JournalEntity? linked,
}) async {
  final PersistenceLogic persistenceLogic = getIt<PersistenceLogic>();

  final List<AssetEntity>? assets = await AssetPicker.pickAssets(
    context,
    pickerConfig: const AssetPickerConfig(
      maxAssets: 40,
      requestType: RequestType.image,
      textDelegate: EnglishAssetPickerTextDelegate(),
    ),
  );
  if (assets != null) {
    for (final AssetEntity asset in assets) {
      Geolocation? geolocation;
      LatLng latLng = await asset.latlngAsync();
      double? latitude = latLng.latitude ?? asset.latitude;
      double? longitude = latLng.longitude ?? asset.longitude;

      if (latitude != null &&
          longitude != null &&
          latitude != 0.0 &&
          longitude != 0.0) {
        geolocation = Geolocation(
          createdAt: asset.createDateTime,
          latitude: latitude,
          longitude: longitude,
          geohashString: DeviceLocation.getGeoHash(
            latitude: latitude,
            longitude: longitude,
          ),
        );
      }

      DateTime createdAt = asset.createDateTime;
      File? file = await asset.file;

      if (file != null) {
        String idNamePart = asset.id.split('/').first;
        String originalName = file.path.split('/').last;
        String imageFileName = '$idNamePart.$originalName'
            .replaceAll(
              'HEIC',
              'JPG',
            )
            .replaceAll(
              'PNG',
              'JPG',
            );
        String day = DateFormat('yyyy-MM-dd').format(createdAt);
        String relativePath = '/images/$day/';
        String directory = await createAssetDirectory(relativePath);
        String targetFilePath = '$directory$imageFileName';
        await compressAndSave(file, targetFilePath);
        DateTime created = asset.createDateTime;

        ImageData imageData = ImageData(
          imageId: asset.id,
          imageFile: imageFileName,
          imageDirectory: relativePath,
          capturedAt: created,
          geolocation: geolocation,
        );

        persistenceLogic.createImageEntry(
          imageData,
          linked: linked,
        );
      }
    }
  }
}
