import 'package:flutter/widgets.dart';
import '../services/error_logger_service.dart';

/// Logs all push/pop/replace navigations via [ErrorLoggerService].
class LoggingNavigatorObserver extends NavigatorObserver {
  final ErrorLoggerService _logger = ErrorLoggerService.instance;

  String _routeName(Route<dynamic>? route) {
    return route?.settings.name ?? route.runtimeType.toString();
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.navigationPush(_routeName(route));
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.navigationPop(_routeName(route));
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    _logger.navigationReplace(_routeName(oldRoute), _routeName(newRoute));
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _logger.debug(
      'Removed route: ${_routeName(route)}',
      category: LogCategory.navigation,
    );
  }
}
