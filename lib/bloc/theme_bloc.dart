import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ThemeEvent { toggleTheme, setLightTheme, setDarkTheme }

class ThemeBloc extends Bloc<ThemeEvent, bool> {
  static const String _themePreferenceKey = 'isDarkMode';
  
  ThemeBloc() : super(false) {
    on<ThemeEvent>((event, emit) async {
      switch (event) {
        case ThemeEvent.toggleTheme:
          emit(!state);
          await _saveThemePreference(!state);
          break;
        case ThemeEvent.setLightTheme:
          emit(false);
          await _saveThemePreference(false);
          break;
        case ThemeEvent.setDarkTheme:
          emit(true);
          await _saveThemePreference(true);
          break;
      }
    });
    
    // Load saved theme preference
    _loadThemePreference();
  }
  
  Future<void> _saveThemePreference(bool isDarkMode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_themePreferenceKey, isDarkMode);
  }
  
  Future<void> _loadThemePreference() async {
    final prefs = await SharedPreferences.getInstance();
    final isDarkMode = prefs.getBool(_themePreferenceKey) ?? false;
    add(isDarkMode ? ThemeEvent.setDarkTheme : ThemeEvent.setLightTheme);
  }
}