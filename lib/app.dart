import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/presentation/main_layout.dart';
import 'package:starlight/themes/dark.dart';
import 'package:starlight/themes/light.dart';
import 'package:starlight/themes/theme_provider.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          home: const MainLayout(),
        );
      },
    );
  }
}
