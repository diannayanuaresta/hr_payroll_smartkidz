import 'package:hr_payroll/bloc/count_bloc.dart';

class MainController {
  CountBloc currentIndexMenu = CountBloc();
  
  changeIndexMenu(int index) {
    currentIndexMenu.changeVal(index);
  }

}

MainController mainController = MainController();