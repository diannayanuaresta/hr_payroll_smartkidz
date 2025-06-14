import 'package:bloc/bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/map_bloc.dart';

class DataMap {
  ///Sts = Students
  List listDataMap = [];
  DataMap({required this.listDataMap});
}

class ListMapBloc extends Cubit<DataMap> {
  ListMapBloc() : super(DataMap(listDataMap: []));

  addAll(List data) {
    state.listDataMap.addAll(data);
    return emit(DataMap(listDataMap: state.listDataMap));
  }

  addListString(String detailInvoiceId) {
    state.listDataMap.add(detailInvoiceId);
    return emit(DataMap(listDataMap: state.listDataMap));
  }

  addListInt(int detailInvoiceId) {
    state.listDataMap.add(detailInvoiceId);
    return emit(DataMap(listDataMap: state.listDataMap));
  }

  addListMap(Map detailInvoiceId) {
    state.listDataMap.add(detailInvoiceId);
    return emit(DataMap(listDataMap: state.listDataMap));
  }

  removeList(detailInvoiceId) {
    state.listDataMap.removeWhere((element) => element == detailInvoiceId);
    return emit(DataMap(listDataMap: state.listDataMap));
  }

  removeIndexList(int index) {
    state.listDataMap.removeAt(index);
    return emit(DataMap(listDataMap: state.listDataMap));
  }

  removeAll() {
    state.listDataMap.clear();
    return emit(DataMap(listDataMap: state.listDataMap));
  }

  void findMap(String field, String value, MapBloc mapBloc, {Function? funcSuccess, Function? funcFailed}) {
    mapBloc.removeVal();
    var data = state.listDataMap.firstWhere(
        (element) => element[field].toString() == value.toString(),
        orElse: () => {});

    if (data != {}) {
      mapBloc.changeVal(data);
      funcSuccess ?? (){};
    } else {
      mapBloc.changeVal({});
      funcFailed ?? (){};
    }

    print(data);
  }

  String findVal(String field, String value, String fieldShow) {
    var data = state.listDataMap
        .firstWhere((element) => element[field].toString() == value.toString());

    if (data != {}) {
      return data[fieldShow];
    } else {
      return '';
    }
  }

  void replaceVal(Map awal, Map akhir) {
    int index = state.listDataMap.indexOf(awal);
    int end = 1 + index;
    List<Map> data = [];
    data.add(akhir);
    state.listDataMap.replaceRange(index, end, data);
    emit(state);
  }

  @override
  void onChange(Change<DataMap> change) {
    // TODO: implement onChange
    super.onChange(change);
  }

  @override
  void onError(Object error, StackTrace stackTrace) {
    // TODO: implement onError
    super.onError(error, stackTrace);
  }

}
