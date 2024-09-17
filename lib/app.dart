import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/presentation/main_layout.dart';
import 'package:starlight/services/settings_service.dart';
import 'package:starlight/themes/dark.dart';
import 'package:starlight/themes/light.dart';
import 'package:starlight/themes/theme_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer2<ThemeProvider, SettingsService>(
      builder: (context, themeProvider, settingsService, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: settingsService.themeMode,
          home: const MainLayout(),
        );
      },
    );
  }
}
