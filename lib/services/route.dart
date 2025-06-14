import 'package:flutter/material.dart';
import 'package:hr_payroll/screen/login.dart';
import 'package:hr_payroll/screen/register.dart';
import 'package:hr_payroll/screen/main_menu.dart';
import 'package:hr_payroll/screen/staff/account_list.dart';
import 'package:hr_payroll/screen/staff/attend_list.dart';
import 'package:hr_payroll/screen/dashboard.dart';
import 'package:hr_payroll/screen/staff/tim_list.dart';
import 'package:hr_payroll/screen/staff/document_list.dart';

class MyRoute {
  Route onRoute(RouteSettings settings) {
    switch (settings.name) {
      case "/":
        return MaterialPageRoute(
            builder: (BuildContext context) => const LoginScreen());
      case "/register":
        return MaterialPageRoute(
            builder: (BuildContext context) => const RegisterScreen());
      case "/main":
        return MaterialPageRoute(
            builder: (BuildContext context) => const MainMenuScreen());
      case "/attend-list":
        return MaterialPageRoute(
            builder: (BuildContext context) => const AttendanceScreen());
      case "/document-list":
        return MaterialPageRoute(
            builder: (BuildContext context) => const DocumentList());
      case "/team-list":
        return MaterialPageRoute(
            builder: (BuildContext context) => const TeamListScreen());
      case "/account-list":
        return MaterialPageRoute(
            builder: (BuildContext context) => const MyAccountPage());
      default:
        return MaterialPageRoute(
            builder: (BuildContext context) => const HRMDashboard());
    }
  }
}
