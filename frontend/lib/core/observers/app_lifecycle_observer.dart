import 'package:flutter/widgets.dart';
import '../services/error_logger_service.dart';

/// Observes app lifecycle changes (resumed, paused, inactive, etc.)
/// and logs them via [ErrorLoggerService].
class AppLifecycleObserver extends WidgetsBindingObserver {
  final ErrorLoggerService _logger = ErrorLoggerService.instance;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _logger.lifecycleChange(state.name);

    // Flush pending logs when the app is paused/detached so logs
    // aren't lost if the OS kills the process.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _logger.flush();
    }
  }

  @override
  void didHaveMemoryPressure() {
    _logger.warn(
      'Memory pressure warning from OS',
      category: LogCategory.lifecycle,
    );
  }
}
