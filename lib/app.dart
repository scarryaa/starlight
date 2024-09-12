import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:starlight/screens/home_page.dart';
import 'package:starlight/themes/theme_provider.dart';
import 'themes/dark.dart';
import 'themes/light.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeProvider.themeMode,
          home: const MyHomePage(),
        );
      },
    );
  }
}
