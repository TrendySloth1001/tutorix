import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'core/services/database_service.dart';
import 'core/services/error_logger_service.dart';
import 'features/auth/controllers/auth_controller.dart';

void main() async {
  // Run everything inside a guarded zone so that all uncaught async errors
  // are captured and logged instead of crashing the app silently.
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      final logger = ErrorLoggerService.instance;

      // ── Flutter framework errors ────────────────────────────────────────
      FlutterError.onError = (FlutterErrorDetails details) {
        logger.fatal(
          'FlutterError: ${details.exceptionAsString()}',
          category: LogCategory.system,
          error: details.exception,
          stackTrace: details.stack,
          metadata: {
            'library': details.library ?? 'unknown',
            'context': details.context?.toString() ?? 'none',
          },
        );
        // Keep default behavior in debug mode (red error screen)
        FlutterError.presentError(details);
      };

      // ── Platform dispatcher errors (e.g. codec failures) ───────────────
      PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
        logger.fatal(
          'PlatformDispatcher error: $error',
          category: LogCategory.system,
          error: error,
          stackTrace: stack,
        );
        return true; // Handled
      };

      // Warm up the local database so cache reads are instant.
      await DatabaseService.instance.database;

      logger.info('App started', category: LogCategory.lifecycle);

      runApp(
        ChangeNotifierProvider(
          create: (_) => AuthController()..initialize(),
          child: const TutorixApp(),
        ),
      );
    },
    // ── Uncaught async errors in the zone ─────────────────────────────────
    (Object error, StackTrace stack) {
      ErrorLoggerService.instance.fatal(
        'Uncaught zone error: $error',
        category: LogCategory.system,
        error: error,
        stackTrace: stack,
      );
    },
  );
}
