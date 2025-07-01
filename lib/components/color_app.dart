import 'package:flutter/material.dart';

class ColorApp {
  // Light Mode Colors (First Image)
  // Primary Colors
  static const Color lightPrimary = Color(0xFF0ABAB5);  // #0ABAB5 - Teal
  static const Color lightSecondary = Color(0xFF56DFCF); // #56DFCF - Light Teal
  static const Color lightTertiary = Color(0xFFADEED9); // #ADEED9 - Mint
  static const Color lightBackground = Color(0xFFFEEDF3); // #FEEDF3 - Light Pink
  
  // Text Colors for Light Mode
  static const Color lightTextPrimary = Color(0xFF333333); // Dark Gray for primary text
  static const Color lightTextSecondary = Color(0xFF666666); // Medium Gray for secondary text
  static const Color lightTextOnPrimary = Colors.white; // White text on primary color
  
  // Accent Colors
  static const Color lightAccent = Color(0xFF3A7AFE); // Blue accent from attend_list.dart
  static const Color lightError = Colors.red; // Error color
  static const Color lightSuccess = Colors.green; // Success color
  
  // Dark Mode Colors (Second Image)
  // Primary Colors
  static const Color darkPrimary = Color(0xFF003C43);   // #003C43 - Dark Teal
  static const Color darkSecondary = Color(0xFF135D66); // #135D66 - Medium Teal
  static const Color darkTertiary = Color(0xFF77B0AA);  // #77B0AA - Light Teal
  static const Color darkBackground = Color(0xFF121212); // Dark gray for dark mode background
  
  // Text Colors for Dark Mode
  static const Color darkTextPrimary = Colors.white; // White for primary text
  static const Color darkTextSecondary = Color(0xFFCCCCCC); // Light Gray for secondary text
  static const Color darkTextOnPrimary = Colors.white; // White text on primary color
  
  // Accent Colors
  static const Color darkAccent = Color(0xFF3A7AFE); // Blue accent from attend_list.dart
  static const Color darkError = Color(0xFFFF5252); // Lighter red for dark mode
  static const Color darkSuccess = Color(0xFF4CAF50); // Green for dark mode
  
  // Additional UI Colors
  static const Color cardLight = Colors.white;
  static const Color cardDark = Color(0xFF1E2D3A);
  
  // Get color based on brightness
  static Color getPrimary(Brightness brightness) {
    return brightness == Brightness.light ? lightPrimary : darkPrimary;
  }
  
  static Color getSecondary(Brightness brightness) {
    return brightness == Brightness.light ? lightSecondary : darkSecondary;
  }
  
  static Color getTertiary(Brightness brightness) {
    return brightness == Brightness.light ? lightTertiary : darkTertiary;
  }
  
  static Color getBackground(Brightness brightness) {
    return brightness == Brightness.light ? lightBackground : darkBackground;
  }
  
  static Color getTextPrimary(Brightness brightness) {
    return brightness == Brightness.light ? lightTextPrimary : darkTextPrimary;
  }
  
  static Color getTextSecondary(Brightness brightness) {
    return brightness == Brightness.light ? lightTextSecondary : darkTextSecondary;
  }
  
  static Color getTextOnPrimary(Brightness brightness) {
    return brightness == Brightness.light ? lightTextOnPrimary : darkTextOnPrimary;
  }
  
  static Color getAccent(Brightness brightness) {
    return brightness == Brightness.light ? lightAccent : darkAccent;
  }
  
  static Color getError(Brightness brightness) {
    return brightness == Brightness.light ? lightError : darkError;
  }
  
  static Color getSuccess(Brightness brightness) {
    return brightness == Brightness.light ? lightSuccess : darkSuccess;
  }
  
  static Color getCardColor(Brightness brightness) {
    return brightness == Brightness.light ? cardLight : cardDark;
  }
  
  // Get ThemeData for the app
  // Add this method to get DatePickerThemeData
  static DatePickerThemeData getDatePickerTheme(Brightness brightness) {
    return DatePickerThemeData(
      backgroundColor: getCardColor(brightness),
      headerBackgroundColor: getPrimary(brightness),
      headerForegroundColor: getTextOnPrimary(brightness),
      dayForegroundColor: MaterialStateProperty.resolveWith<Color>(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return getTextOnPrimary(brightness);
          }
          return getTextPrimary(brightness);
        },
      ),
      dayBackgroundColor: MaterialStateProperty.resolveWith<Color>(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return brightness == Brightness.dark ? darkTertiary : lightPrimary;
          }
          return Colors.transparent;
        },
      ),
      todayForegroundColor: MaterialStateProperty.resolveWith<Color>(
        (Set<MaterialState> states) {
          return brightness == Brightness.dark ? darkTertiary : lightPrimary;
        },
      ),
      todayBackgroundColor: MaterialStateProperty.resolveWith<Color>(
        (Set<MaterialState> states) {
          if (states.contains(MaterialState.selected)) {
            return brightness == Brightness.dark ? darkTertiary : lightPrimary;
          }
          return Colors.transparent;
        },
      ),
      confirmButtonStyle: ButtonStyle(
        foregroundColor: MaterialStateProperty.all<Color>(
          brightness == Brightness.dark ? darkTertiary : lightPrimary
        ),
      ),
      cancelButtonStyle: ButtonStyle(
        foregroundColor: MaterialStateProperty.all<Color>(
          brightness == Brightness.dark ? darkTertiary : lightPrimary
        ),
      ),
    );
  }
  
  // Update the getTheme method to include datePickerTheme
  static ThemeData getTheme(BuildContext context, bool isDarkMode) {
    final brightness = isDarkMode ? Brightness.dark : Brightness.light;
    
    return ThemeData(
      brightness: brightness,
      primaryColor: getPrimary(brightness),
      scaffoldBackgroundColor: getBackground(brightness),
      cardColor: getCardColor(brightness),
      datePickerTheme: getDatePickerTheme(brightness), // Add this line
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: getPrimary(brightness),
        onPrimary: getTextOnPrimary(brightness),
        secondary: getSecondary(brightness),
        onSecondary: getTextOnPrimary(brightness),
        tertiary: getTertiary(brightness),
        onTertiary: getTextOnPrimary(brightness),
        error: getError(brightness),
        onError: getTextOnPrimary(brightness),
        surface: getCardColor(brightness),
        onSurface: getTextPrimary(brightness),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: getTextPrimary(brightness)),
        displayMedium: TextStyle(color: getTextPrimary(brightness)),
        displaySmall: TextStyle(color: getTextPrimary(brightness)),
        headlineLarge: TextStyle(color: getTextPrimary(brightness)),
        headlineMedium: TextStyle(color: getTextPrimary(brightness)),
        headlineSmall: TextStyle(color: getTextPrimary(brightness)),
        titleLarge: TextStyle(color: getTextPrimary(brightness)),
        titleMedium: TextStyle(color: getTextPrimary(brightness)),
        titleSmall: TextStyle(color: getTextPrimary(brightness)),
        bodyLarge: TextStyle(color: getTextPrimary(brightness)),
        bodyMedium: TextStyle(color: getTextPrimary(brightness)),
        bodySmall: TextStyle(color: getTextSecondary(brightness)),
        labelLarge: TextStyle(color: getTextPrimary(brightness)),
        labelMedium: TextStyle(color: getTextPrimary(brightness)),
        labelSmall: TextStyle(color: getTextSecondary(brightness)),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: getPrimary(brightness),
        foregroundColor: getTextOnPrimary(brightness),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: getPrimary(brightness),
          foregroundColor: getTextOnPrimary(brightness),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: getPrimary(brightness),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: getPrimary(brightness),
          side: BorderSide(color: getPrimary(brightness)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: getCardColor(brightness),
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: getPrimary(brightness)),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: getCardColor(brightness),
        contentTextStyle: TextStyle(color: getTextPrimary(brightness)),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}