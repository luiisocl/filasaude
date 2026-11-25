import 'package:flutter/material.dart';

import '../domain/entities.dart';

/// Cores do protótipo aprovado (telas do MVP).
class AppColors {
  AppColors._();

  static const primaria = Color(0xFF0B5F66);
  static const primariaEscura = Color(0xFF08444A);
  static const primariaClara = Color(0xFFE3F1EF);
  static const fundo = Color(0xFFF4F7F7);
  static const borda = Color(0xFFD5DEDD);
  static const bordaCampo = Color(0xFFB9C6C4);
  static const texto = Color(0xFF10231F);
  static const textoSecundario = Color(0xFF4A5A57);
  static const textoMedio = Color(0xFF3B4C49);
  static const alertaFundo = Color(0xFFFFF4E5);
  static const alertaBorda = Color(0xFFF2C27D);
  static const alertaTexto = Color(0xFF5C3300);
  static const perigo = Color(0xFFA12A1F);
  static const sucesso = Color(0xFF1E8A3C);

  static Color risco(CorRisco c) => switch (c) {
        CorRisco.vermelho => const Color(0xFFB42318),
        CorRisco.laranja => const Color(0xFFD9620B),
        CorRisco.amarelo => const Color(0xFFE8B100),
        CorRisco.verde => const Color(0xFF1E8A3C),
        CorRisco.azul => const Color(0xFF1D5FB8),
      };

  /// Texto legível sobre a cor de risco (amarelo pede texto escuro).
  static Color sobreRisco(CorRisco c) => c == CorRisco.amarelo ? texto : Colors.white;
}

class AppTheme {
  AppTheme._();

  static ThemeData get claro {
    final esquema = ColorScheme.fromSeed(
      seedColor: AppColors.primaria,
      primary: AppColors.primaria,
      surface: Colors.white,
      error: AppColors.perigo,
    );
    final borda = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.bordaCampo),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: esquema,
      scaffoldBackgroundColor: AppColors.fundo,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primaria,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: Colors.white),
      ),
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.texto),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: AppColors.texto),
        titleMedium: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: AppColors.texto),
        bodyLarge: TextStyle(fontSize: 16, color: AppColors.texto),
        bodyMedium: TextStyle(fontSize: 15, color: AppColors.texto),
        bodySmall: TextStyle(fontSize: 13, color: AppColors.textoSecundario),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: borda,
        enabledBorder: borda,
        focusedBorder: borda.copyWith(borderSide: const BorderSide(color: AppColors.primaria, width: 2)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaria,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.texto,
          minimumSize: const Size.fromHeight(52),
          side: const BorderSide(color: AppColors.bordaCampo),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.borda),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primariaClara,
        height: 68,
      ),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
      // Transição nativa e leve entre telas.
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
        },
      ),
    );
  }
}
