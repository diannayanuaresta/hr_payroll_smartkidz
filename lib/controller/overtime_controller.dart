import 'package:hr_payroll_smartkidz/bloc/count_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/custom_bloc.dart';

class OvertimeController {
  CountBloc currentIndexOvertime = CountBloc();
  CustomBloc reloadOvertimeData = CustomBloc();

  changeIndexOvertime(int index) {
    currentIndexOvertime.changeVal(index);
  }
}

OvertimeController overtimeController = OvertimeController();