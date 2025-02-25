import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:form_builder_validators/localization/l10n.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:lotti/blocs/audio/player_cubit.dart';
import 'package:lotti/blocs/audio/recorder_cubit.dart';
import 'package:lotti/blocs/sync/outbox_cubit.dart';
import 'package:lotti/blocs/sync/sync_config_cubit.dart';
import 'package:lotti/database/logging_db.dart';
import 'package:lotti/get_it.dart';
import 'package:lotti/routes/router.gr.dart';
import 'package:lotti/services/window_service.dart';
import 'package:lotti/utils/screenshots.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (Platform.isMacOS) {
    await windowManager.ensureInitialized();
    hotKeyManager.unregisterAll();
  }

  getIt.registerSingleton<WindowService>(WindowService());
  await getIt<WindowService>().restore();
  tz.initializeTimeZones();

  runZonedGuarded(() {
    registerSingletons();

    FlutterError.onError = (FlutterErrorDetails details) {
      final LoggingDb _loggingDb = getIt<LoggingDb>();
      _loggingDb.captureException(
        details,
        domain: 'MAIN',
        subDomain: 'onError',
      );
    };

    registerScreenshotHotkey();

    runApp(LottiApp());
  }, (Object error, StackTrace stackTrace) {
    final LoggingDb _loggingDb = getIt<LoggingDb>();
    _loggingDb.captureException(
      error,
      domain: 'MAIN',
      subDomain: 'runZonedGuarded',
      stackTrace: stackTrace,
    );
  });
}

class LottiApp extends StatelessWidget {
  LottiApp({Key? key}) : super(key: key);
  final router = getIt<AppRouter>();

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<SyncConfigCubit>(
          lazy: false,
          create: (BuildContext context) => SyncConfigCubit(),
        ),
        BlocProvider<OutboxCubit>(
          lazy: false,
          create: (BuildContext context) => OutboxCubit(),
        ),
        BlocProvider<AudioRecorderCubit>(
          create: (BuildContext context) => AudioRecorderCubit(),
        ),
        BlocProvider<AudioPlayerCubit>(
          create: (BuildContext context) => AudioPlayerCubit(),
        ),
      ],
      child: MaterialApp.router(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          FormBuilderLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          primarySwatch: Colors.grey,
        ),
        debugShowCheckedModeBanner: true,
        routerDelegate: router.delegate(
          navigatorObservers: () => [],
        ),
        routeInformationParser: router.defaultRouteParser(),
      ),
    );
  }
}
