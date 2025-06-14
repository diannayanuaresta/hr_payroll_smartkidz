import 'package:hr_payroll_smartkidz/bloc/count_bloc.dart';

class MainController {
  CountBloc currentIndexMenu = CountBloc();
  
  changeIndexMenu(int index) {
    currentIndexMenu.changeVal(index);
  }

}

MainController mainController = MainController();