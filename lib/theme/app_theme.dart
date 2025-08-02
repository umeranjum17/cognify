import 'package:flutter/material.dart';

const TextStyle bodyLarge = TextStyle(fontSize: 16, fontWeight: FontWeight.normal);

const TextStyle bodyMedium = TextStyle(fontSize: 14, fontWeight: FontWeight.normal);

const TextStyle bodySmall = TextStyle(fontSize: 12, fontWeight: FontWeight.normal);
const TextStyle titleLarge = TextStyle(fontSize: 22, fontWeight: FontWeight.bold);
const TextStyle titleMedium = TextStyle(fontSize: 18, fontWeight: FontWeight.bold);
const TextStyle titleSmall = TextStyle(fontSize: 14, fontWeight: FontWeight.bold);
ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  scaffoldBackgroundColor: AppColors.darkBackground,
  primaryColor: AppColors.darkPrimary,
  cardColor: AppColors.darkCard,
  dividerColor: AppColors.darkDivider,
  useMaterial3: true,
  colorScheme: ColorScheme.dark(
    primary: AppColors.darkPrimary,
    secondary: AppColors.darkAccent,
    tertiary: AppColors.darkAccentSecondary,
    error: AppColors.darkError,
    surface: AppColors.darkCard,
    onPrimary: AppColors.darkButtonText,
    onSecondary: AppColors.darkButtonText,
    onSurface: AppColors.darkText,
    onError: AppColors.darkButtonText,
    primaryContainer: AppColors.darkPrimaryLight,
    secondaryContainer: AppColors.darkAccent.withValues(alpha: 0.2),
    tertiaryContainer: AppColors.darkAccentSecondary.withValues(alpha: 0.2),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColors.darkText, fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(color: AppColors.darkTextSecondary, fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(color: AppColors.darkTextMuted, fontSize: 12, fontWeight: FontWeight.w400),
    titleLarge: TextStyle(color: AppColors.darkText, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    titleMedium: TextStyle(color: AppColors.darkText, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3),
    titleSmall: TextStyle(color: AppColors.darkTextSecondary, fontSize: 16, fontWeight: FontWeight.w600),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderSide: const BorderSide(color: AppColors.darkInputBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: AppColors.darkInputBorderFocus, width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
    hintStyle: const TextStyle(color: AppColors.darkInputPlaceholder),
    filled: true,
    fillColor: AppColors.darkInput,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.darkBackgroundAlt,
    foregroundColor: AppColors.darkText,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: AppColors.darkText,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
);
ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  scaffoldBackgroundColor: AppColors.lightBackground,
  primaryColor: AppColors.lightPrimary,
  cardColor: AppColors.lightCard,
  dividerColor: AppColors.lightDivider,
  useMaterial3: true,
  colorScheme: ColorScheme.light(
    primary: AppColors.lightPrimary,
    secondary: AppColors.lightAccent,
    tertiary: AppColors.lightAccentSecondary,
    error: AppColors.lightError,
    surface: AppColors.lightSurface,
    onPrimary: AppColors.lightButtonText,
    onSecondary: AppColors.lightButtonText,
    onSurface: AppColors.lightText,
    onError: AppColors.lightButtonText,
    primaryContainer: AppColors.lightPrimaryLight,
    secondaryContainer: AppColors.lightAccent.withValues(alpha: 0.1),
    tertiaryContainer: AppColors.lightAccentSecondary.withValues(alpha: 0.1),
  ),
  textTheme: const TextTheme(
    bodyLarge: TextStyle(color: AppColors.lightText, fontSize: 16, fontWeight: FontWeight.w400),
    bodyMedium: TextStyle(color: AppColors.lightTextSecondary, fontSize: 14, fontWeight: FontWeight.w400),
    bodySmall: TextStyle(color: AppColors.lightTextMuted, fontSize: 12, fontWeight: FontWeight.w400),
    titleLarge: TextStyle(color: AppColors.lightText, fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: -0.5),
    titleMedium: TextStyle(color: AppColors.lightText, fontSize: 20, fontWeight: FontWeight.w600, letterSpacing: -0.3),
    titleSmall: TextStyle(color: AppColors.lightTextSecondary, fontSize: 16, fontWeight: FontWeight.w600),
  ),
  inputDecorationTheme: InputDecorationTheme(
    border: OutlineInputBorder(
      borderSide: const BorderSide(color: AppColors.lightInputBorder),
      borderRadius: BorderRadius.circular(12),
    ),
    focusedBorder: OutlineInputBorder(
      borderSide: const BorderSide(color: AppColors.lightInputBorderFocus, width: 2),
      borderRadius: BorderRadius.circular(12),
    ),
    hintStyle: const TextStyle(color: AppColors.lightInputPlaceholder),
    filled: true,
    fillColor: AppColors.lightInput,
  ),
  appBarTheme: const AppBarTheme(
    backgroundColor: AppColors.lightBackgroundAlt,
    foregroundColor: AppColors.lightText,
    elevation: 0,
    titleTextStyle: TextStyle(
      color: AppColors.lightText,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    ),
  ),
);

class AppColors {
  // Light Theme - Enhanced Robot Logo Color Palette (more vibrant and classy)
  static const lightBackground = Color(0xFFFFFFFF); // Pure white background
  static const lightBackgroundAlt = Color(0xFFFAFAFA); // Subtle warm gray for cards
  static const lightBackgroundLight = Color(0xFFF5F5F5); // Light gray for elevated surfaces
  static const lightBackgroundDark = Color(0xFFE5E5E5); // Richer darker gray for contrast

  // Primary Colors - Enhanced Robot Logo Charcoal (richer and more vibrant)
  static const lightPrimary = Color(0xFF171717); // Rich near-black for strong contrast
  static const lightPrimaryLight = Color(0xFF404040); // Vibrant dark gray
  static const lightPrimaryDark = Color(0xFF0A0A0A); // Deep black for maximum impact

  // Accent Colors - Enhanced Robot Logo Gold & Supporting Colors (more vibrant)
  static const lightAccent = Color(0xFFF59E0B); // Rich amber gold - more vibrant
  static const lightAccentSecondary = Color(0xFFD97706); // Deeper amber for contrast
  static const lightAccentTertiary = Color(0xFF6B7280); // Sophisticated gray from logo
  static const lightAccentQuaternary = Color(0xFF374151); // Rich robot charcoal

  // Gradient Colors - Enhanced Charcoal to Gold combinations (more vibrant)
  static const lightGradientStart = Color(0xFF374151); // Rich robot charcoal
  static const lightGradientEnd = Color(0xFF6B7280); // Vibrant lighter charcoal
  static const lightGradientSecondaryStart = Color(0xFFF59E0B); // Rich amber gold
  static const lightGradientSecondaryEnd = Color(0xFFD97706); // Deep amber

  // Text Colors for Light Theme - Enhanced for better readability and vibrancy
  static const lightText = Color(0xFF171717); // Rich near-black text for strong readability
  static const lightTextSecondary = Color(0xFF404040); // Vibrant dark gray text
  static const lightTextMuted = Color(0xFF737373); // Medium gray text with good contrast
  static const lightTextLight = Color(0xFFA3A3A3); // Light gray text that's still readable
  // Status Colors - Enhanced for better visibility
  static const lightSuccess = Color(0xFF22C55E); // Vibrant success green
  static const lightWarning = Color(0xFFF59E0B); // Rich amber warning (matches accent)
  static const lightError = Color(0xFFDC2626); // Strong error red
  static const lightInfo = Color(0xFF3B82F6); // Clear info blue
  // Button Colors for Light Theme - Enhanced solid buttons with goldish accent
  static const lightButton = Color(0xFFF59E0B); // Rich amber/gold for primary buttons (matches logo)
  static const lightButtonSecondary = Color(0xFFF7E6B8); // Light gold/cream for secondary buttons
  static const lightButtonHover = Color(0xFFD97706); // Darker amber on hover
  static const lightButtonText = Color(0xFF171717); // Dark text on gold buttons for contrast
  static const lightButtonTextSecondary = Color(0xFF92400E); // Darker amber text on light buttons
  static const lightInput = Color(0xFFFEFEFE);
  static const lightInputBorder = Color(0xFFA0AEC0); // Light gray from logo
  static const lightInputBorderFocus = Color(0xFFF59E0B); // Rich amber focus (matches accent)
  static const lightInputText = Color(0xFF1A202C); // Darker charcoal
  static const lightInputPlaceholder = Color(0xFF718096); // Medium gray from logo
  static const lightBorder = Color(0xFFE2E8F0); // Light borders
  static const lightBorderMuted = Color(0xFFF1F3F4); // Very light borders
  static const lightDivider = Color(0xFFE2E8F0); // Subtle dividers
  // Card and Surface Colors for Light Theme - Enhanced for better contrast
  static const lightCard = Color(0xFFFFFFFF); // Pure white cards
  static const lightCardBorder = Color(0xFFE2E8F0); // Light card borders with good contrast
  static const lightSurface = Color(0xFFF8FAFC); // Alternative surface color (slightly cooler)

  // Dark Theme - Professional & Sophisticated (ChatGPT/Notion style)
  static const darkBackground = Color(0xFF121212); // Professional dark background
  static const darkBackgroundAlt = Color(0xFF1F1F1F); // Card backgrounds
  static const darkBackgroundLight = Color(0xFF2C2C2C); // Elevated surfaces
  static const darkBackgroundDark = Color(0xFF000000); // Deeper contrast

  // Primary Colors - Professional charcoal for Dark Mode
  static const darkPrimary = Color(0xFF9CA3AF); // Light charcoal for primary elements
  static const darkPrimaryLight = Color(0xFFD1D5DB); // Lighter charcoal
  static const darkPrimaryDark = Color(0xFF6B7280); // Deeper charcoal

  // Accent Colors for Dark Mode - Enhanced Gold & Electric (more sophisticated)
  static const darkAccent = Color(0xFFF59E0B); // Rich amber gold - classy treasure
  static const darkAccentSecondary = Color(0xFF06B6D4); // Sophisticated cyan - robotic elegance
  static const darkAccentTertiary = Color(0xFFE2E8F0); // Light silver - metallic
  static const darkAccentQuaternary = Color(0xFF718096); // Medium gray - sophisticated

  // Gradient Colors for Dark Mode
  static const darkGradientStart = Color(0xFF818CF8);
  static const darkGradientEnd = Color(0xFFF472B6);
  static const darkGradientSecondaryStart = Color(0xFF22D3EE);
  static const darkGradientSecondaryEnd = Color(0xFF34D399);

  // Text Colors for Dark Mode - Professional and readable
  static const darkText = Color(0xFFF8FAFC); // Brighter white for body text
  static const darkTextSecondary = Color(0xFFE5E7EB); // Lighter gray for secondary text
  static const darkTextMuted = Color(0xFFD1D5DB); // Lighter muted gray for hints/placeholders
  static const darkTextLight = Color(0xFF4B5563); // Darker gray for disabled states
  // Status Colors for Dark Mode - Enhanced for better visibility
  static const darkSuccess = Color(0xFF16A34A); // Vibrant success green
  static const darkWarning = Color(0xFFF59E0B); // Rich amber warning (matches accent)
  static const darkError = Color(0xFFDC2626); // Strong error red
  static const darkInfo = Color(0xFF3B82F6); // Clear info blue
  // Button Colors for Dark Mode - Professional solid buttons with goldish accent
  static const darkButton = Color(0xFFF59E0B); // Rich amber/gold for primary buttons (matches logo)
  static const darkButtonSecondary = Color(0xFF451A03); // Dark amber for secondary buttons
  static const darkButtonHover = Color(0xFFFBBF24); // Brighter gold on hover
  static const darkButtonText = Color(0xFF1A1A1A); // Dark text on gold buttons for contrast
  static const darkButtonTextSecondary = Color(0xFFFEF3C7); // Light cream text on dark buttons
  static const darkInput = Color(0xFF1A1A1A);
  static const darkInputBorder = Color(0xFF404040);
  static const darkInputBorderFocus = Color(0xFFF59E0B); // Amber focus
  static const darkInputText = Color(0xFFE5E7EB);
  static const darkInputPlaceholder = Color(0xFF9CA3AF);
  static const darkBorder = Color(0xFF404040);
  static const darkBorderMuted = Color(0xFF333333);
  static const darkDivider = Color(0xFF404040);
  // Card and Surface Colors for Dark Mode - Professional contrast
  static const darkCard = Color(0xFF181818); // Darker card background for higher contrast
  static const darkCardBorder = Color(0xFF404040); // Subtle borders
  static const darkSurface = Color(0xFF2C2C2C); // Elevated surface color

  // Semantic Aliases
  static const lightPrimaryText = lightPrimary;
  static const lightSecondaryText = lightTextSecondary;
  static const lightMutedText = lightTextMuted;
  static const darkPrimaryText = Color(0xFF4A5568); // Robot charcoal for dark mode
  static const darkSecondaryText = darkTextSecondary;
  static const darkMutedText = darkTextMuted;

  // Spacing Constants
  static const double spacingXs = 4.0;
  static const double spacingSm = 8.0;
  static const double spacingMd = 16.0;
  static const double spacingLg = 24.0;
  static const double spacingXl = 32.0;

  // Border Radius Constants
  static const double borderRadiusSm = 8.0;
  static const double borderRadiusMd = 12.0;
  static const double borderRadiusLg = 16.0;
}
