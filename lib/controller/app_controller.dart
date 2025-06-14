import 'package:hr_payroll/bloc/count_bloc.dart';
import 'package:hr_payroll/bloc/list_bloc.dart';
import 'package:hr_payroll/bloc/list_map_bloc.dart';
import 'package:hr_payroll/bloc/map_bloc.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
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

  //latitude longitude
  CustomBloc latitudeCB = CustomBloc();
  CustomBloc longitudeCB = CustomBloc();

  //ListMapBloc
  ListMapBloc categoryLMB = ListMapBloc();
  List<Map> categoryListMap = [];

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

AppController appController = AppController();