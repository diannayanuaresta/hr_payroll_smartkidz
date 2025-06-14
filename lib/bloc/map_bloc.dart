import 'package:bloc/bloc.dart';

class MapBloc extends Cubit<Map> {
  MapBloc() : super({});

  changeVal(Map val) {
    emit(val);
  }

  removeVal() {
    emit({});
  }
}
