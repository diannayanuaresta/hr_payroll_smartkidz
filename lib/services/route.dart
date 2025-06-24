import 'package:flutter/material.dart';
import 'package:hr_payroll_smartkidz/screen/login.dart';
import 'package:hr_payroll_smartkidz/screen/register.dart';
import 'package:hr_payroll_smartkidz/screen/main_menu.dart';
import 'package:hr_payroll_smartkidz/screen/staff/account_list.dart';
import 'package:hr_payroll_smartkidz/screen/staff/approval_list.dart';
import 'package:hr_payroll_smartkidz/screen/staff/attend_list.dart';
import 'package:hr_payroll_smartkidz/screen/dashboard.dart';
import 'package:hr_payroll_smartkidz/screen/staff/tim_list.dart';
import 'package:hr_payroll_smartkidz/screen/staff/document_list.dart';

class MyRoute {
  Route onRoute(RouteSettings settings) {
    switch (settings.name) {
      case "/":
        return MaterialPageRoute(
          builder: (BuildContext context) => const LoginScreen(),
        );
      case "/register":
        return MaterialPageRoute(
          builder: (BuildContext context) => const RegisterScreen(),
        );
      case "/main":
        return MaterialPageRoute(
          builder: (BuildContext context) => const MainMenuScreen(),
        );
      case "/attend-list":
        return MaterialPageRoute(
          builder: (BuildContext context) => const AttendanceScreen(),
        );
      case "/approval-list":
        return MaterialPageRoute(
          builder: (BuildContext context) => const ApprovalList(),
        );
      case "/document-list":
        return MaterialPageRoute(
          builder: (BuildContext context) => const DocumentList(),
        );
      case "/team-list":
        return MaterialPageRoute(
          builder: (BuildContext context) => const TeamListScreen(),
        );
      case "/account-list":
        return MaterialPageRoute(
          builder: (BuildContext context) => const MyAccountPage(),
        );
      default:
        return MaterialPageRoute(
          builder: (BuildContext context) => const HRMDashboard(),
        );
    }
  }
}
