import 'package:flutter/material.dart';
import 'package:hr_payroll_smartkidz/bloc/count_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/custom_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/list_map_bloc.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';

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
        // Proses data dengan format baru (leader dan members)
        final data = response['data'];
        List<Map<String, dynamic>> allTeamMembers = [];
        
        // Proses data leader
        if (data['leader'] != null) {
          Map<String, dynamic> leaderData = Map<String, dynamic>.from(data['leader']);
          leaderData['role'] = 'Leader';
          leaderData['status'] = leaderData['status'] ?? 'active';
          allTeamMembers.add(leaderData);
        }
        
        // Proses data members
        if (data['members'] != null && data['members'] is List) {
          for (var member in data['members']) {
            Map<String, dynamic> memberData = Map<String, dynamic>.from(member);
            memberData['role'] = 'Member';
            memberData['status'] = memberData['status'] ?? 'active';
            allTeamMembers.add(memberData);
          }
        }
        
        // Tambahkan semua data ke teamListData
        teamListData.addAll(allTeamMembers);
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