import 'package:bloc/bloc.dart';

class ListBloc extends Cubit<List> {
  ListBloc() : super([]);

  defaultVal(int length) {
    state.addAll(List.generate(length, (index) => ''));
    return emit(state);
  }

  replaceVal(int index, String img) {
    state.replaceRange(index, 1 + index, [img]);
    return emit(state);
  }

  removeIndexVal(int index) {
    state.replaceRange(index, 1 + index, ['']);
    return emit(state);
  }

  defineVal(List data) {
    state.clear();
    state.addAll(data);
    return emit(state);
  }

  removeVal() {
    state.clear();
    return emit(state);
  }

  addList(val) {
    state.add(val);
    return emit(state);
  }
}
