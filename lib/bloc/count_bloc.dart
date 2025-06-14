import 'package:bloc/bloc.dart';

class CountBloc extends Cubit<int> {
  CountBloc() : super(0);

  changeVal(int val) {
    emit(val);
  }

  defaultVal() {
    emit(0);
  }

  increment() {
    emit(state + 1);
  }

  decrement() {
    emit(state - 1);
  }
}
