// Change all imports from:
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/count_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/custom_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/list_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/list_map_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/map_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/theme_bloc.dart';
import 'package:hr_payroll_smartkidz/components/color_app.dart';
import 'package:hr_payroll_smartkidz/services/route.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initialize();
  
  // Initialize the Indonesian locale for date formatting
  initializeDateFormatting('id_ID', null).then((_) {
    runApp(const MyApp());
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    final router = MyRoute();

    return MultiBlocProvider(
        providers: [
          BlocProvider(create: (context) => CustomBloc()),
          BlocProvider(create: (context) => ListMapBloc()),
          BlocProvider(create: (context) => MapBloc()),
          BlocProvider(create: (context) => CountBloc()),
          BlocProvider(create: (context) => ListBloc()),
          BlocProvider(create: (context) => ThemeBloc()),
        ],
        child: BlocBuilder<ThemeBloc, bool>(
          builder: (context, isDarkMode) {
            return MaterialApp(
              initialRoute: "/",
              onGenerateRoute: router.onRoute,
              title: 'Smartkidz Apps',
              debugShowCheckedModeBanner: false,
              navigatorKey: navigatorKey,
              theme: ColorApp.getTheme(context, false), // Light theme
              darkTheme: ColorApp.getTheme(context, true), // Dark theme
              themeMode: isDarkMode ? ThemeMode.dark : ThemeMode.light,
            );
          },
        ));
  }
}