import 'package:hr_payroll_smartkidz/bloc/count_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/list_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/list_map_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/map_bloc.dart';
import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';

import '../bloc/custom_bloc.dart';

class AppController{
  
  GetStorage modeApplication = GetStorage();
  CustomBloc darkModeCB = CustomBloc();
  CustomBloc tglAwalFilter = CustomBloc();
  CustomBloc tglAkhirFilter = CustomBloc();
  CustomBloc isJailBroken = CustomBloc();
  CustomBloc isMockLocation = CustomBloc();
  CustomBloc isRealDevice = CustomBloc();
  CustomBloc isOnExternalStorage = CustomBloc();
  CustomBloc isSafeDevice = CustomBloc();
  CustomBloc isDevelopmentModeEnable = CustomBloc();
  MapBloc userProfile = MapBloc();
  MapBloc userDetailProfile = MapBloc();
  MapBloc userAccess = MapBloc();
  
  // Add isLoadingProfile as a class property
  CustomBloc? isLoadingProfile;
  
  //latitude longitude
  CustomBloc latitudeCB = CustomBloc();
  CustomBloc longitudeCB = CustomBloc();

  //ListMapBloc
  ListMapBloc approvalLemburLMB = ListMapBloc();
  List<Map> approvalLemburListMap = [];

  ListMapBloc categoryLMB = ListMapBloc();
  List<Map> categoryListMap = [];
  
  // Letter categories
  ListMapBloc letterCategoryLMB = ListMapBloc();
  List<Map> letterCategoryListMap = [];
  
  // Add this line for cuti data
  ListMapBloc cutiLMB = ListMapBloc();
  List<Map> cutiListMap = [];
  
  // Add this line for izin data
  ListMapBloc izinLMB = ListMapBloc();
  List<Map> izinListMap = [];
  
  // Add this line for sakit data
  ListMapBloc sakitLMB = ListMapBloc();
  List<Map> sakitListMap = [];
  
  //Master Data ListMapBloc
  ListMapBloc jabatanLMB = ListMapBloc();
  List<Map> jabatanListMap = [];
  
  ListMapBloc divisiLMB = ListMapBloc();
  List<Map> divisiListMap = [];
  
  ListMapBloc jenisLemburLMB = ListMapBloc();
  List<Map> jenisLemburListMap = [];

  //ListMapBloc
  ListMapBloc getAttendanceLMB = ListMapBloc();
  List<Map> getAttendanceListMap = [];
  

  CustomBloc successMessage = CustomBloc();

  //login
  TextEditingController emailLogController = TextEditingController();
  TextEditingController passwordLogController = TextEditingController();
  final loginFormKey = GlobalKey<FormState>();

  CountBloc isProcess= CountBloc();

  //forgot-Pass
  TextEditingController emailForgotPassController = TextEditingController();

  //foto profile
  CustomBloc imgProfile = CustomBloc();

  //mainPage
  CountBloc mainPageIndex = CountBloc();

  //List page stack
  ListBloc pageListStack = ListBloc();
  
}

// Remove the global variable declaration
// CustomBloc? isLoadingProfile;
AppController appController = AppController();
