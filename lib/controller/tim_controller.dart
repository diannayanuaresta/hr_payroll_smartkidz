import 'package:flutter/material.dart';
import 'package:hr_payroll/bloc/count_bloc.dart';
import 'package:hr_payroll/bloc/custom_bloc.dart';
import 'package:hr_payroll/bloc/list_map_bloc.dart';
import 'package:hr_payroll/services/api.dart';

class TimController {
  // Untuk menyimpan indeks tim yang dipilih
  CountBloc currentIndexTim = CountBloc();
  
  // Untuk mengelola status reload data tim
  CustomBloc reloadTimData = CustomBloc();
  
  // Untuk menyimpan data tim dari API
  ListMapBloc teamListData = ListMapBloc();
  
  // Method untuk mengubah index tim
  void changeIndexTim(int index) {
    currentIndexTim.changeVal(index);
  }
  
  // Method untuk mengambil data tim dari API
  Future<void> getTeamData() async {
    try {
      // Set status reload menjadi true
      reloadTimData.changeVal('loading');
      
      // Panggil API untuk mendapatkan data tim
      final response = await Api().getTeam();
      
      // Hapus data lama
      teamListData.removeAll();
      
      // Periksa apakah response berhasil dan memiliki data
      if (response != null && response['data'] != null) {
        // Tambahkan data baru
        teamListData.addAll(response['data']);
        
        // Tambahkan status 'active' ke setiap item jika belum ada
        for (var i = 0; i < teamListData.state.listDataMap.length; i++) {
          if (!teamListData.state.listDataMap[i].containsKey('status')) {
            teamListData.state.listDataMap[i]['status'] = 'active';
          }
        }
      }
    } catch (e) {
      // Tangani error jika terjadi
      debugPrint('Error getting team data: $e');
    } finally {
      // Set status reload menjadi false
      reloadTimData.changeVal('done');
    }
  }
}

TimController timController = TimController();