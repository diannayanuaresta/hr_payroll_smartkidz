import 'package:bloc/bloc.dart';

class CustomBloc extends Cubit<String> {
  CustomBloc() : super('');

  changeVal(String val) {
    emit(val);
  }

  defaultVal() {
    emit('');
  }
}
