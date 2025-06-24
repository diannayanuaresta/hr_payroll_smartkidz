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
  
  // Untuk menyimpan data ulang tahun tim
  ListMapBloc birthdayListData = ListMapBloc();
  
  // Untuk menandai apakah ada anggota tim yang berulang tahun hari ini
  CustomBloc hasBirthdayToday = CustomBloc();
  
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
      
      // Ambil data ulang tahun tim
      await getTeamBirthdayData();
      
    } catch (e) {
      // Tangani error jika terjadi
      debugPrint('Error getting team data: $e');
    } finally {
      // Set status reload menjadi false
      reloadTimData.changeVal('done');
    }
  }
  
  // Method untuk mengambil data ulang tahun tim dari API
  Future<void> getTeamBirthdayData() async {
    try {
      // Panggil API untuk mendapatkan data ulang tahun tim
      final response = await Api().getTeamBirthday();
      
      // Hapus data lama
      birthdayListData.removeAll();
      hasBirthdayToday.changeVal('false');
      
      // Periksa apakah response berhasil dan memiliki data
      if (response != null && response['data'] != null && response['data'] is List) {
        final List<dynamic> data = response['data'];
        List<Map<String, dynamic>> birthdayMembers = [];
        
        // Proses data ulang tahun
        for (var member in data) {
          Map<String, dynamic> memberData = Map<String, dynamic>.from(member);
          birthdayMembers.add(memberData);
        }
        
        // Tambahkan semua data ke birthdayListData
        birthdayListData.addAll(birthdayMembers);
        
        // Periksa apakah ada anggota tim yang berulang tahun hari ini
        checkBirthdayToday();
      }
    } catch (e) {
      // Tangani error jika terjadi
      debugPrint('Error getting team birthday data: $e');
    }
  }
  
  // Method untuk memeriksa apakah ada anggota tim yang berulang tahun hari ini
  void checkBirthdayToday() {
    final today = DateTime.now();
    final todayDay = today.day;
    final todayMonth = today.month;
    
    bool hasBirthday = false;
    
    // Periksa setiap anggota tim
    for (var member in birthdayListData.state.listDataMap) {
      if (member['tanggal_lahir'] != null) {
        try {
          final birthDate = DateTime.parse(member['tanggal_lahir']);
          if (birthDate.day == todayDay && birthDate.month == todayMonth) {
            hasBirthday = true;
            break;
          }
        } catch (e) {
          debugPrint('Error parsing birth date: $e');
        }
      }
    }
    
    // Update status ulang tahun
    hasBirthdayToday.changeVal(hasBirthday ? 'true' : 'false');
  }
  
  // Method untuk mendapatkan daftar anggota tim yang berulang tahun hari ini
  List getBirthdayMembersToday() {
    final today = DateTime.now();
    final todayDay = today.day;
    final todayMonth = today.month;
    
    return birthdayListData.state.listDataMap.where((member) {
      if (member['tanggal_lahir'] != null) {
        try {
          final birthDate = DateTime.parse(member['tanggal_lahir'] as String);
          return birthDate.day == todayDay && birthDate.month == todayMonth;
        } catch (e) {
          debugPrint('Error parsing birth date: $e');
        }
      }
      return false;
    }).toList(); // Menambahkan .toList() untuk mengkonversi Iterable menjadi List
  }
}

TimController timController = TimController();