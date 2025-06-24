import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';

class OvertimeService {
  final Api _api = Api();
  final MasterApi _masterApi = MasterApi();
  
  // Load overtime data
  Future<Map<String, dynamic>> loadOvertimeData({
    String? startDate,
    String? endDate,
  }) async {
    try {
      final response = await _api.getLembur(
        startDate: startDate ?? '',
        endDate: endDate ?? ''
      ).timeout(const Duration(seconds: 15));
      
      if (response['status'] == true && response['data'] != null) {
        // Process and enrich the data
        List<Map<String, dynamic>> enrichedData = [];
        
        for (var item in response['data']) {
          Map<String, dynamic> overtimeItem = Map<String, dynamic>.from(item);
          
          // Calculate duration
          String calculatedDuration = _calculateDuration(
            overtimeItem['jamMulai'],
            overtimeItem['jamSelesai']
          );
          overtimeItem['duration'] = calculatedDuration;
          
          // Determine status
          overtimeItem['status'] = _determineStatus(
            overtimeItem['statusSupervisor'],
            overtimeItem['statusHrd']
          );
          
          enrichedData.add(overtimeItem);
        }
        
        // Store the overtime data in appController
        appController.getAttendanceLMB.removeAll();
        appController.getAttendanceLMB.addAll(enrichedData);
        appController.getAttendanceListMap = enrichedData;
        
        return {'success': true, 'data': enrichedData};
      } else {
        // Handle error or empty response
        appController.getAttendanceLMB.removeAll();
        appController.getAttendanceListMap = [];
        
        return {
          'success': false,
          'message': response['message'] ?? 'Failed to load overtime data'
        };
      }
    } catch (e) {
      appController.getAttendanceLMB.removeAll();
      appController.getAttendanceListMap = [];
      
      return {'success': false, 'message': 'Error: $e'};
    }
  }
  
  // Load jenis lembur data
  Future<Map<String, dynamic>> loadJenisLembur() async {
    try {
      final response = await _masterApi.jenisLembur();
      
      if (response['status'] == true && response['data'] != null) {
        final jenisLemburList = List<Map<String, dynamic>>.from(response['data']);
        
        // Store in appController
        appController.jenisLemburLMB.removeAll();
        appController.jenisLemburLMB.addAll(jenisLemburList);
        appController.jenisLemburListMap = jenisLemburList;
        
        return {'success': true, 'data': jenisLemburList};
      } else {
        return {
          'success': false,
          'message': response['message'] ?? 'Gagal memuat data jenis lembur'
        };
      }
    } catch (e) {
      return {'success': false, 'message': 'Error: $e'};
    }
  }
  
  // Add overtime
  Future<Map<String, dynamic>> addOvertime(Map<String, String> data) async {
    try {
      final response = await _api.addLembur(data);
      return response;
    } catch (e) {
      return {'status': false, 'message': 'Error: $e'};
    }
  }
  
  // Update overtime
  Future<Map<String, dynamic>> updateOvertime(Map<String, String> data, String id) async {
    try {
      final response = await _api.updateLembur(data, id);
      return response;
    } catch (e) {
      return {'status': false, 'message': 'Error: $e'};
    }
  }
  
  // Delete overtime
  Future<Map<String, dynamic>> deleteOvertime(String id) async {
    try {
      final response = await _api.delLembur(id);
      return response;
    } catch (e) {
      return {'status': false, 'message': 'Error: $e'};
    }
  }
  
  // Helper method to calculate duration
  String _calculateDuration(String? startTime, String? endTime) {
    if (startTime == null || endTime == null) return '-';
    
    try {
      final startTimeParts = startTime.split(':');
      final endTimeParts = endTime.split(':');
      
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
          return '${hours}h ${minutes}m';
        }
      }
    } catch (e) {
      // Ignore calculation error
    }
    
    return '-';
  }
  
  // Helper method to determine status
  String _determineStatus(dynamic supervisorStatus, dynamic hrdStatus) {
    String overtimeStatus = 'Pending';
    
    if (supervisorStatus != null && hrdStatus != null) {
      if (supervisorStatus == true && hrdStatus == true) {
        overtimeStatus = 'Approved';
      } else if (supervisorStatus == false || hrdStatus == false) {
        overtimeStatus = 'Rejected';
      }
    } else if (supervisorStatus == true) {
      overtimeStatus = 'Approved by Supervisor';
    } else if (supervisorStatus == false) {
      overtimeStatus = 'Rejected by Supervisor';
    }
    
    return overtimeStatus;
  }
}