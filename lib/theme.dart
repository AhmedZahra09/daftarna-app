import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

const kGreen = Color(0xFF1B5E20);
const kRed = Color(0xFFC62828);
const kStoreName = 'متجري';

final _money = NumberFormat('#,##0', 'en');
String fmt(num v) => _money.format(v);
String fmtDate(int ms) =>
    DateFormat('dd/MM/yyyy', 'en').format(DateTime.fromMillisecondsSinceEpoch(ms));

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: kGreen),
      scaffoldBackgroundColor: const Color(0xFFF6F7F5),
      appBarTheme: const AppBarTheme(
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
      ),
    );
