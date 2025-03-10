import 'package:flutter/material.dart';
import 'package:lotti/database/database.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/theme.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionAppBar extends StatefulWidget with PreferredSizeWidget {
  const VersionAppBar({
    Key? key,
    required this.title,
  }) : super(key: key);

  final String title;

  @override
  _VersionAppBarState createState() => _VersionAppBarState();

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _VersionAppBarState extends State<VersionAppBar> {
  String version = '';
  String buildNumber = '';

  final JournalDb _db = getIt<JournalDb>();
  late Stream<int> countStream;

  Future<void> getVersions() async {
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    setState(() {
      version = packageInfo.version;
      buildNumber = packageInfo.buildNumber;
    });
  }

  @override
  void initState() {
    super.initState();
    getVersions();
    countStream = _db.watchJournalCount();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<int>(
        stream: countStream,
        builder: (
          BuildContext context,
          AsyncSnapshot<int> snapshot,
        ) {
          if (snapshot.data == null) {
            return const SizedBox.shrink();
          } else {
            return Column(
              children: [
                Text(
                  widget.title,
                  style: appBarTextStyle,
                ),
                Text(
                  'v$version ($buildNumber), n = ${snapshot.data}',
                  style: TextStyle(
                    color: AppColors.headerFontColor2,
                    fontFamily: 'Oswald',
                    fontSize: 10.0,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            );
          }
        });
  }
}
