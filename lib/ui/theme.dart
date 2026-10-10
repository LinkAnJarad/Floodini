import 'package:flutter/material.dart';

/// Floodini Emergency Design System (DESIGN.md).
///
/// Brand colors come from the "Colors" section; surface and container tones
/// from the front matter. Dark-mode tones are derived from the same palette.
class FloodiniPalette {
  const FloodiniPalette._();

  static const riverBlue = Color(0xFF168AAD);
  static const deepTeal = Color(0xFF0F4C5C);
  static const cyan = Color(0xFF25C9D5);
  static const carbon = Color(0xFF12181B);
  static const lightSurface = Color(0xFFF7F9FA);
  static const darkSurface = Color(0xFF0E1417);
  static const sosRed = Color(0xFFD62828);
  static const amber = Color(0xFFF5A623);
  static const safeGreen = Color(0xFF2E9E6B);
  static const cream = Color(0xFFF7EED1);
}

/// Semantic colors that Material's scheme has no slot for.
@immutable
class FloodiniColors extends ThemeExtension<FloodiniColors> {
  const FloodiniColors({
    required this.safe,
    required this.safeContainer,
    required this.onSafeContainer,
    required this.caution,
    required this.cautionContainer,
    required this.onCautionContainer,
    required this.cardBorder,
    required this.cardShadow,
  });

  final Color safe;
  final Color safeContainer;
  final Color onSafeContainer;
  final Color caution;
  final Color cautionContainer;
  final Color onCautionContainer;
  final Color cardBorder;
  final Color cardShadow;

  static const light = FloodiniColors(
    safe: FloodiniPalette.safeGreen,
    safeContainer: Color(0xFFDFF5EA),
    onSafeContainer: Color(0xFF14573A),
    caution: FloodiniPalette.amber,
    cautionContainer: Color(0xFFFFF1D6),
    onCautionContainer: Color(0xFF6B4300),
    cardBorder: Color(0x1412181B),
    cardShadow: Color(0x0F0F4C5C),
  );

  static const dark = FloodiniColors(
    safe: Color(0xFF52C78F),
    safeContainer: Color(0xFF123B2B),
    onSafeContainer: Color(0xFF9BE6C2),
    caution: FloodiniPalette.amber,
    cautionContainer: Color(0xFF3D2B05),
    onCautionContainer: Color(0xFFFFD38A),
    cardBorder: Color(0x24FFFFFF),
    cardShadow: Color(0x66000000),
  );

  @override
  FloodiniColors copyWith({
    Color? safe,
    Color? safeContainer,
    Color? onSafeContainer,
    Color? caution,
    Color? cautionContainer,
    Color? onCautionContainer,
    Color? cardBorder,
    Color? cardShadow,
  }) => FloodiniColors(
    safe: safe ?? this.safe,
    safeContainer: safeContainer ?? this.safeContainer,
    onSafeContainer: onSafeContainer ?? this.onSafeContainer,
    caution: caution ?? this.caution,
    cautionContainer: cautionContainer ?? this.cautionContainer,
    onCautionContainer: onCautionContainer ?? this.onCautionContainer,
    cardBorder: cardBorder ?? this.cardBorder,
    cardShadow: cardShadow ?? this.cardShadow,
  );

  @override
  FloodiniColors lerp(ThemeExtension<FloodiniColors>? other, double t) {
    if (other is! FloodiniColors) return this;
    return FloodiniColors(
      safe: Color.lerp(safe, other.safe, t)!,
      safeContainer: Color.lerp(safeContainer, other.safeContainer, t)!,
      onSafeContainer: Color.lerp(onSafeContainer, other.onSafeContainer, t)!,
      caution: Color.lerp(caution, other.caution, t)!,
      cautionContainer: Color.lerp(
        cautionContainer,
        other.cautionContainer,
        t,
      )!,
      onCautionContainer: Color.lerp(
        onCautionContainer,
        other.onCautionContainer,
        t,
      )!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      cardShadow: Color.lerp(cardShadow, other.cardShadow, t)!,
    );
  }
}

extension FloodiniThemeContext on BuildContext {
  /// Falls back to the matching default when a plain [ThemeData] is in use
  /// (for example in widget tests).
  FloodiniColors get floodini {
    final theme = Theme.of(this);
    return theme.extension<FloodiniColors>() ??
        (theme.brightness == Brightness.dark
            ? FloodiniColors.dark
            : FloodiniColors.light);
  }
}

/// DESIGN.md spacing and shape tokens.
class FloodiniSpacing {
  const FloodiniSpacing._();

  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const minTouch = 56.0;
}

class FloodiniRadius {
  const FloodiniRadius._();

  static const base = 8.0;
  static const card = 16.0;
  static const panel = 24.0;
}

const _fontFamily = 'Inter';

const _lightScheme = ColorScheme(
  brightness: Brightness.light,
  primary: FloodiniPalette.riverBlue,
  onPrimary: Colors.white,
  primaryContainer: Color(0xFFBBE9FF),
  onPrimaryContainer: Color(0xFF001F29),
  secondary: FloodiniPalette.deepTeal,
  onSecondary: Colors.white,
  secondaryContainer: Color(0xFFB3E8FB),
  onSecondaryContainer: FloodiniPalette.deepTeal,
  tertiary: FloodiniPalette.cyan,
  onTertiary: FloodiniPalette.carbon,
  tertiaryContainer: Color(0xFF7CF4FF),
  onTertiaryContainer: Color(0xFF002022),
  error: FloodiniPalette.sosRed,
  onError: Colors.white,
  errorContainer: Color(0xFFFFDAD6),
  onErrorContainer: Color(0xFF93000A),
  surface: FloodiniPalette.lightSurface,
  onSurface: FloodiniPalette.carbon,
  onSurfaceVariant: Color(0xFF3E484D),
  surfaceDim: Color(0xFFD5DBDF),
  surfaceBright: FloodiniPalette.lightSurface,
  surfaceContainerLowest: Colors.white,
  surfaceContainerLow: Color(0xFFEFF4F8),
  surfaceContainer: Color(0xFFE9EFF3),
  surfaceContainerHigh: Color(0xFFE3E9ED),
  surfaceContainerHighest: Color(0xFFDEE3E7),
  outline: Color(0xFF6E797E),
  outlineVariant: Color(0xFFBEC8CE),
  inverseSurface: Color(0xFF2B3135),
  onInverseSurface: Color(0xFFECF1F6),
  inversePrimary: Color(0xFF74D2F8),
  surfaceTint: FloodiniPalette.riverBlue,
  shadow: Colors.black,
  scrim: Colors.black,
);

const _darkScheme = ColorScheme(
  brightness: Brightness.dark,
  primary: Color(0xFF74D2F8),
  onPrimary: Color(0xFF00364A),
  primaryContainer: Color(0xFF004D63),
  onPrimaryContainer: Color(0xFFBBE9FF),
  secondary: Color(0xFF9ACEE1),
  onSecondary: Color(0xFF003543),
  secondaryContainer: Color(0xFF114D5D),
  onSecondaryContainer: Color(0xFFB6EBFE),
  tertiary: FloodiniPalette.cyan,
  onTertiary: Color(0xFF00363A),
  tertiaryContainer: Color(0xFF004F54),
  onTertiaryContainer: Color(0xFF7CF4FF),
  error: Color(0xFFFFB4AB),
  onError: Color(0xFF690005),
  errorContainer: Color(0xFF93000A),
  onErrorContainer: Color(0xFFFFDAD6),
  surface: FloodiniPalette.darkSurface,
  onSurface: Color(0xFFE3EAEE),
  onSurfaceVariant: Color(0xFFBEC8CE),
  surfaceDim: FloodiniPalette.darkSurface,
  surfaceBright: Color(0xFF2B363C),
  surfaceContainerLowest: Color(0xFF0A1013),
  surfaceContainerLow: Color(0xFF141B1F),
  surfaceContainer: Color(0xFF182126),
  surfaceContainerHigh: Color(0xFF1F2A30),
  surfaceContainerHighest: Color(0xFF27343B),
  outline: Color(0xFF8A979D),
  outlineVariant: Color(0xFF3E484D),
  inverseSurface: Color(0xFFE3EAEE),
  onInverseSurface: Color(0xFF2B3135),
  inversePrimary: FloodiniPalette.riverBlue,
  surfaceTint: Color(0xFF74D2F8),
  shadow: Colors.black,
  scrim: Colors.black,
);

TextTheme _textTheme() => const TextTheme(
  // headline-xl
  headlineLarge: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.64,
  ),
  // headline-lg
  headlineMedium: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 26,
    height: 32 / 26,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.26,
  ),
  // headline-md
  headlineSmall: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
  ),
  titleLarge: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeight.w600,
  ),
  // headline-sm
  titleMedium: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeight.w600,
  ),
  // label-lg
  titleSmall: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.14,
  ),
  bodyLarge: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeight.w400,
  ),
  bodyMedium: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w400,
  ),
  bodySmall: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w400,
  ),
  labelLarge: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.14,
  ),
  labelMedium: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.24,
  ),
  labelSmall: TextStyle(
    fontFamily: _fontFamily,
    fontSize: 11,
    height: 14 / 11,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.44,
  ),
);

ThemeData floodiniTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = dark ? _darkScheme : _lightScheme;
  final colors = dark ? FloodiniColors.dark : FloodiniColors.light;
  final textTheme = _textTheme().apply(
    bodyColor: scheme.onSurface,
    displayColor: scheme.onSurface,
  );
  const cardRadius = BorderRadius.all(Radius.circular(FloodiniRadius.card));
  const baseRadius = BorderRadius.all(Radius.circular(FloodiniRadius.base));
  const buttonShape = RoundedRectangleBorder(borderRadius: cardRadius);
  const minButton = Size(64, FloodiniSpacing.minTouch);
  final buttonLabel = textTheme.titleMedium!.copyWith(
    fontWeight: FontWeight.w700,
    fontSize: 16,
  );

  OutlineInputBorder inputBorder(Color color, [double width = 1.5]) =>
      OutlineInputBorder(
        borderRadius: baseRadius,
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    fontFamily: _fontFamily,
    textTheme: textTheme,
    extensions: [colors],
    appBarTheme: AppBarTheme(
      backgroundColor: dark
          ? scheme.surfaceContainerLow
          : FloodiniPalette.deepTeal,
      foregroundColor: dark ? scheme.onSurface : Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: textTheme.titleMedium!.copyWith(
        color: dark ? scheme.onSurface : Colors.white,
      ),
    ),
    cardTheme: CardThemeData(
      color: scheme.surfaceContainerLowest,
      elevation: 1,
      shadowColor: colors.cardShadow,
      surfaceTintColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: FloodiniSpacing.xs),
      shape: RoundedRectangleBorder(
        borderRadius: cardRadius,
        side: BorderSide(color: colors.cardBorder),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: minButton,
        shape: buttonShape,
        textStyle: buttonLabel,
        padding: const EdgeInsets.symmetric(horizontal: FloodiniSpacing.md),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: minButton,
        shape: buttonShape,
        textStyle: buttonLabel,
        foregroundColor: dark ? scheme.primary : FloodiniPalette.deepTeal,
        backgroundColor: scheme.surfaceContainerLowest,
        side: BorderSide(color: scheme.outlineVariant, width: 1.5),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: const RoundedRectangleBorder(borderRadius: baseRadius),
        textStyle: textTheme.labelLarge,
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLowest,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: FloodiniSpacing.md,
        vertical: 18,
      ),
      border: inputBorder(scheme.outline),
      enabledBorder: inputBorder(scheme.outline),
      focusedBorder: inputBorder(scheme.primary, 2),
      errorBorder: inputBorder(scheme.error),
      focusedErrorBorder: inputBorder(scheme.error, 2),
      disabledBorder: inputBorder(scheme.outlineVariant),
      hintStyle: textTheme.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
      labelStyle: textTheme.bodyLarge!.copyWith(color: scheme.onSurfaceVariant),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: scheme.surfaceContainerLowest,
      surfaceTintColor: Colors.transparent,
      elevation: 3,
      shadowColor: colors.cardShadow,
      indicatorColor: scheme.primaryContainer,
      labelTextStyle: WidgetStateProperty.resolveWith(
        (states) => textTheme.labelMedium!.copyWith(
          fontWeight: FontWeight.w700,
          color: states.contains(WidgetState.selected)
              ? (dark ? scheme.primary : FloodiniPalette.deepTeal)
              : scheme.onSurfaceVariant,
        ),
      ),
      iconTheme: WidgetStateProperty.resolveWith(
        (states) => IconThemeData(
          size: 26,
          color: states.contains(WidgetState.selected)
              ? (dark ? scheme.onPrimaryContainer : FloodiniPalette.deepTeal)
              : scheme.onSurfaceVariant,
        ),
      ),
    ),
    chipTheme: ChipThemeData(
      shape: const StadiumBorder(),
      side: BorderSide(color: scheme.outlineVariant),
      labelStyle: textTheme.labelLarge,
      backgroundColor: scheme.surfaceContainerLowest,
      selectedColor: scheme.primaryContainer,
    ),
    checkboxTheme: CheckboxThemeData(
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.comfortable,
      side: BorderSide(color: scheme.outline, width: 2),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      minVerticalPadding: 12,
      contentPadding: EdgeInsets.symmetric(horizontal: FloodiniSpacing.md),
    ),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: scheme.inverseSurface,
      contentTextStyle: textTheme.bodyMedium!.copyWith(
        color: scheme.onInverseSurface,
      ),
      shape: const RoundedRectangleBorder(borderRadius: baseRadius),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
      linearMinHeight: 8,
    ),
  );
}
