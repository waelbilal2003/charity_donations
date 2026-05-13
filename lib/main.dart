import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/date_selection_screen.dart';
import 'security/activation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final String activationStatus = prefs.getString('activation_status') ?? '';

  bool isActivated = false;
  if (activationStatus.isNotEmpty) {
    try {
      final decodedStatus = utf8.decode(base64.decode(activationStatus));
      if (decodedStatus == 'activated_ok') {
        isActivated = true;
      }
    } catch (e) {
      isActivated = false;
    }
  }

  runApp(MyApp(isActivated: isActivated));
}

class MyApp extends StatelessWidget {
  final bool isActivated;

  const MyApp({super.key, required this.isActivated});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Worker Payments',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: isActivated
          ? const DateSelectionScreen(
              storeType: '',
              storeName: '',
            )
          : const ActivationScreen(),
    );
  }
}

/*
import 'package:flutter/material.dart';
import 'screens/date_selection_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Worker Payments',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.teal,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        fontFamily: 'Arial',
      ),
      home: const DateSelectionScreen(
        storeType: '',
        storeName: '',
      ),
    );
  }
}
*/
