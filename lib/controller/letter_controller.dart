import 'package:hr_payroll_smartkidz/bloc/count_bloc.dart' show CountBloc;
import 'package:hr_payroll_smartkidz/bloc/custom_bloc.dart' show CustomBloc;

class LetterController {
  CountBloc currentIndexLetter = CountBloc();
  CustomBloc reloadLetterData = CustomBloc();

  changeIndexLetter(int index) {
    currentIndexLetter.changeVal(index);
  }
}

LetterController letterController = LetterController();