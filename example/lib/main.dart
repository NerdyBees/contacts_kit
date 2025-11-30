import 'package:contacts_kit_example/contacts_list_screen.dart'
    show ContactsListScreen;
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Contacts Kit Demo',
      theme: ThemeData(
        primarySwatch: Colors.indigo,
        appBarTheme: AppBarTheme(
          backgroundColor: Colors.indigo.shade700,
          foregroundColor: Colors.white,
          elevation: 2, // Slight elevation
          titleTextStyle: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        listTileTheme: const ListTileThemeData(
          contentPadding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 0,
          ), // Smaller vertical padding
          dense: true, // Makes list tiles more compact
        ),
        cardTheme: CardThemeData(
          margin: const EdgeInsets.symmetric(
            vertical: 4,
            horizontal: 8,
          ), // Smaller card margins
          elevation: 1, // Subtle elevation
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ), // Slightly smaller radius
        ),
        textTheme: const TextTheme(
          titleLarge: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ), // Adjusted for compactness
          titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          bodyMedium: TextStyle(fontSize: 14), // Default text size
          bodySmall: TextStyle(fontSize: 12),
        ),
        visualDensity: VisualDensity.compact, // Compact visual density
      ),
      home: const ContactsListScreen(),
    );
  }
}
