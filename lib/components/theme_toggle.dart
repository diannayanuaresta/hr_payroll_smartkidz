import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hr_payroll/bloc/theme_bloc.dart';
import 'package:hr_payroll/components/color_app.dart';

class ThemeToggle extends StatelessWidget {
  final bool showLabel;
  final double size;
  
  const ThemeToggle({
    Key? key,
    this.showLabel = true,
    this.size = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, bool>(
      builder: (context, isDarkMode) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLabel) 
              Text(
                isDarkMode ? 'Dark Mode' : 'Light Mode',
                style: TextStyle(
                  color: Theme.of(context).textTheme.bodyMedium?.color,
                  fontSize: size * 0.7,
                ),
              ),
            if (showLabel) const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                isDarkMode ? Icons.dark_mode : Icons.light_mode,
                color: isDarkMode 
                    ? ColorApp.darkPrimary 
                    : ColorApp.lightPrimary,
                size: size,
              ),
              onPressed: () {
                context.read<ThemeBloc>().add(ThemeEvent.toggleTheme);
              },
              tooltip: isDarkMode ? 'Switch to Light Mode' : 'Switch to Dark Mode',
            ),
          ],
        );
      },
    );
  }
}

class ThemeToggleSwitch extends StatelessWidget {
  final bool showLabel;
  
  const ThemeToggleSwitch({
    Key? key,
    this.showLabel = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeBloc, bool>(
      builder: (context, isDarkMode) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (showLabel) 
              Icon(
                Icons.light_mode,
                color: !isDarkMode 
                    ? Theme.of(context).primaryColor 
                    : Theme.of(context).textTheme.bodyMedium?.color,
                size: 20,
              ),
            const SizedBox(width: 8),
            Switch(
              value: isDarkMode,
              activeColor: ColorApp.darkPrimary,
              inactiveThumbColor: ColorApp.lightPrimary,
              onChanged: (value) {
                context.read<ThemeBloc>().add(ThemeEvent.toggleTheme);
              },
            ),
            const SizedBox(width: 8),
            if (showLabel) 
              Icon(
                Icons.dark_mode,
                color: isDarkMode 
                    ? Theme.of(context).primaryColor 
                    : Theme.of(context).textTheme.bodyMedium?.color,
                size: 20,
              ),
          ],
        );
      },
    );
  }
}