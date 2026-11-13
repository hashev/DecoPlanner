import 'package:flutter/material.dart';

ThemeData plannerTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final primary = Color(dark ? 0xFF93C5FD : 0xFF1E40AF);
  final text = Color(dark ? 0xFFF8FAFC : 0xFF0F172A);
  final secondary = Color(dark ? 0xFFCBD5E1 : 0xFF475569);
  final border = Color(dark ? 0xFF94A3B8 : 0xFF64748B);
  final surface = Color(dark ? 0xFF1E293B : 0xFFFFFFFF);
  final scheme =
      ColorScheme.fromSeed(seedColor: primary, brightness: brightness).copyWith(
        primary: primary,
        onPrimary: Color(dark ? 0xFF0F172A : 0xFFFFFFFF),
        surface: surface,
        onSurface: text,
        onSurfaceVariant: secondary,
        outline: border,
        error: Color(dark ? 0xFFFCA5A5 : 0xFFB91C1C),
      );
  return ThemeData(
    useMaterial3: true,
    pageTransitionsTheme: PageTransitionsTheme(
      builders: {
        for (final platform in TargetPlatform.values)
          platform: const _PlannerPageTransitions(),
      },
    ),
    colorScheme: scheme,
    fontFamily: 'Fira Sans',
    scaffoldBackgroundColor: Color(dark ? 0xFF0F172A : 0xFFF8FAFC),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(fontSize: 16, height: 1.5),
      bodyMedium: TextStyle(fontSize: 16, height: 1.5),
      bodySmall: TextStyle(fontSize: 14, height: 1.4),
      titleLarge: TextStyle(
        fontSize: 24,
        height: 1.33,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: TextStyle(
        fontSize: 20,
        height: 1.4,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: border),
      ),
      contentPadding: const EdgeInsets.all(16),
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: text,
      elevation: 0,
    ),
  );
}

class _PlannerPageTransitions extends PageTransitionsBuilder {
  const _PlannerPageTransitions();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return const PageTransitionsTheme().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      child,
    );
  }
}
