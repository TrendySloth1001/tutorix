import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'core/services/database_service.dart';
import 'features/auth/controllers/auth_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Warm up the local database so cache reads are instant.
  await DatabaseService.instance.database;
  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthController()..initialize(),
      child: const TutorixApp(),
    ),
  );
}
