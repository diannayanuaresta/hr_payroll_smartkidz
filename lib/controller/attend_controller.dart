import 'package:hr_payroll/bloc/count_bloc.dart';
import 'package:hr_payroll/bloc/custom_bloc.dart';

class AttendController {
  CountBloc currentIndexAttend = CountBloc();
  CustomBloc reloadAttendanceData = CustomBloc();

  changeIndexAttend(int index) {
    currentIndexAttend.changeVal(index);
  }

}

AttendController attendController = AttendController();