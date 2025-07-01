import 'package:hr_payroll_smartkidz/bloc/count_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/custom_bloc.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'dart:async';

class OvertimeController {
  CountBloc currentIndexOvertime = CountBloc();
  CustomBloc reloadOvertimeData = CustomBloc();
  CustomBloc isLoadingData = CustomBloc(); // For loading state
  CustomBloc isLoadingJenisLembur = CustomBloc(); // For jenis lembur loading state
  
  final Api _api = Api();
  final MasterApi _masterApi = MasterApi();

  changeIndexOvertime(int index) {
    currentIndexOvertime.changeVal(index);
  }
  
  // Load overtime data with date filters
  Future<void> loadOvertimeData() async {
    isLoadingData.changeVal('true');

    // Add a timeout to prevent UI from hanging indefinitely
    try {
      // Format dates for API request
      String startDateStr = '';
      String endDateStr = '';

      // Check if there are date filters in appController
      if (appController.tglAwalFilter.state.isNotEmpty) {
        startDateStr = appController.tglAwalFilter.state;
      }

      if (appController.tglAkhirFilter.state.isNotEmpty) {
        endDateStr = appController.tglAkhirFilter.state;
      }

      print(
        'Filtering overtime with date range: $startDateStr to $endDateStr',
      );

      // Fetch overtime data with date filters
      // Add timeout to prevent hanging
      final response = await _api
          .getLembur(startDate: startDateStr, endDate: endDateStr)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Loading overtime data timed out. Please try again.',
              );
            },
          );

      print('API Response: $response');

      if (response['status'] == true && response['data'] != null) {
        // Process and enrich the data
        List<Map<String, dynamic>> enrichedData = [];

        for (var item in response['data']) {
          // Convert to Map<String, dynamic> if it's not already
          Map<String, dynamic> overtimeItem = Map<String, dynamic>.from(item);

          // Add additional fields for display purposes
          // Calculate duration from start and end time
          String calculatedDuration = '-';
          if (overtimeItem['jamMulai'] != null &&
              overtimeItem['jamSelesai'] != null) {
            try {
              final startTimeParts = (overtimeItem['jamMulai'] as String)
                  .split(':');
              final endTimeParts = (overtimeItem['jamSelesai'] as String)
                  .split(':');

              if (startTimeParts.length >= 2 && endTimeParts.length >= 2) {
                final startHour = int.parse(startTimeParts[0]);
                final startMinute = int.parse(startTimeParts[1]);
                final endHour = int.parse(endTimeParts[0]);
                final endMinute = int.parse(endTimeParts[1]);

                final startTotalMinutes = startHour * 60 + startMinute;
                final endTotalMinutes = endHour * 60 + endMinute;
                final durationMinutes = endTotalMinutes - startTotalMinutes;

                if (durationMinutes > 0) {
                  final hours = durationMinutes ~/ 60;
                  final minutes = durationMinutes % 60;
                  calculatedDuration = '${hours}h ${minutes}m';
                }
              }
            } catch (e) {
              print('Error calculating duration: $e');
            }
          }
          overtimeItem['duration'] = calculatedDuration;

          // Determine status based on supervisor and HRD approval
          String overtimeStatus = 'Pending';
          if (overtimeItem['statusSupervisor'] != null &&
              overtimeItem['statusHrd'] != null) {
            if (overtimeItem['statusSupervisor'] == true &&
                overtimeItem['statusHrd'] == true) {
              overtimeStatus = 'Approved';
            } else if (overtimeItem['statusSupervisor'] == false ||
                overtimeItem['statusHrd'] == false) {
              overtimeStatus = 'Rejected';
            }
          } else if (overtimeItem['statusSupervisor'] == true) {
            overtimeStatus = 'Approved by Supervisor';
          } else if (overtimeItem['statusSupervisor'] == false) {
            overtimeStatus = 'Rejected by Supervisor';
          }
          overtimeItem['status'] = overtimeStatus;

          enrichedData.add(overtimeItem);
        }

        // Store the overtime data in appController
        appController.getAttendanceLMB.removeAll();
        appController.getAttendanceLMB.addAll(enrichedData);
        appController.getAttendanceListMap = enrichedData;

        print('Overtime data loaded: ${enrichedData.length} records');
        if (enrichedData.isNotEmpty) {
          print('Sample record: ${enrichedData.first}');
        }
      } else {
        // Handle error or empty response
        print(
          'Failed to load overtime data: ${response['message'] ?? "Unknown error"}',
        );
        appController.getAttendanceLMB.removeAll();
        appController.getAttendanceListMap = [];
      }
    } catch (e) {
      print('Error loading overtime data: $e');
      appController.getAttendanceLMB.removeAll();
      appController.getAttendanceListMap = [];
    } finally {
      isLoadingData.changeVal('false');
    }
  }

  // Load jenis lembur data from API
  Future<void> loadJenisLembur() async {
    isLoadingJenisLembur.changeVal('true');

    try {
      final response = await _masterApi.jenisLembur();

      if (response['status'] == true && response['data'] != null) {
        List<Map<String, dynamic>> jenisLemburList = List<Map<String, dynamic>>.from(response['data']);
        // Simpan juga ke appController
        appController.jenisLemburLMB.removeAll();
        appController.jenisLemburLMB.addAll(jenisLemburList);
        appController.jenisLemburListMap = jenisLemburList;
      }
    } catch (e) {
      print('Error loading jenis lembur: $e');
    } finally {
      isLoadingJenisLembur.changeVal('false');
    }
  }
}

OvertimeController overtimeController = OvertimeController();