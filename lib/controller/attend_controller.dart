import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hr_payroll_smartkidz/bloc/count_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/custom_bloc.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:intl/intl.dart';

class AttendController {
  CountBloc currentIndexAttend = CountBloc();
  CustomBloc reloadAttendanceData = CustomBloc();
  
  // Add BLoCs for date filtering
  CustomBloc startDateFilter = CustomBloc();
  CustomBloc endDateFilter = CustomBloc();
  
  // Add BLoCs for loading state
  CountBloc isLoading = CountBloc();
  
  // Method to update date filters
  updateDateFilters(String startDate, String endDate) {
    startDateFilter.changeVal(startDate);
    endDateFilter.changeVal(endDate);
    // Trigger reload
    reloadAttendanceData.changeVal('true');
  }
  
  // Method to clear date filters
  clearDateFilters() {
    startDateFilter.changeVal('');
    endDateFilter.changeVal('');
    // Trigger reload
    reloadAttendanceData.changeVal('true');
  }
  
  // Method to set loading state
  setLoading(bool isLoading) {
    this.isLoading.changeVal(isLoading ? 1 : 0);
  }
  
  // Method to load attendance data
  Future<void> loadAttendanceData() async {
    // Set loading state to true
    setLoading(true);
    
    // Get date filter values
    String startDateStr = startDateFilter.state.isNotEmpty 
        ? startDateFilter.state 
        : appController.tglAwalFilter.state;
        
    String endDateStr = endDateFilter.state.isNotEmpty 
        ? endDateFilter.state 
        : appController.tglAkhirFilter.state;
    
    // Add debug print
    print('Using date filters - Start: "$startDateStr", End: "$endDateStr"');
    
    try {
      // Check if categories are loaded, if not, load them
      if (appController.categoryListMap.isEmpty) {
        final masterApi = MasterApi();
        final categoryResponse = await masterApi.categoryAbsensi();

        if (categoryResponse['status'] == true &&
            categoryResponse['data'] != null) {
          appController.categoryLMB.removeAll();
          appController.categoryLMB.addAll(categoryResponse['data']);
          appController.categoryListMap = List<Map>.from(
            categoryResponse['data'],
          );
          print(
            'Categories loaded from API: ${appController.categoryListMap}',
          );
        } else {
          print('Failed to load categories: ${categoryResponse['message']}');
          // Use default categories if API fails
          appController.categoryListMap = [
            {'id': 1, 'name': 'Check In'},
            {'id': 2, 'name': 'Check Out'},
            {'id': 3, 'name': 'Cuti'},
          ];
        }
      }

      // Get the selected category
      final categories = appController.categoryListMap;

      final selectedIndex = currentIndexAttend.state;
      if (selectedIndex >= categories.length) {
        print(
          'Error: Selected index $selectedIndex is out of bounds for categories length ${categories.length}',
        );
        return;
      }

      final selectedCategory = categories[selectedIndex]['id'].toString();
      final selectedCategoryName = categories[selectedIndex]['name'];
      print(
        'Loading attendance data for category: $selectedCategoryName (ID: $selectedCategory)',
      );

      print('Filtering with date range: $startDateStr to $endDateStr');

      // Tambahkan filter tambahan jika diperlukan
      Map<String, dynamic> additionalFilters = {};

      // Fetch attendance data based on the selected category, date range, and additional filters
      final api = Api();
      final response = await api
          .getAbsensi(
            selectedCategory,
            startDateStr,
            endDateStr,
            additionalFilters: additionalFilters.isNotEmpty
                ? additionalFilters
                : null,
          )
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'Loading attendance data timed out. Please try again.',
              );
            },
          );

      print('API Response: $response');

      if (response['status'] == true && response['data'] != null) {
        // Process and enrich the data
        List<Map<String, dynamic>> enrichedData = [];

        for (var item in response['data']) {
          // Convert to Map<String, dynamic> if it's not already
          Map<String, dynamic> attendanceItem = Map<String, dynamic>.from(
            item,
          );

          // Add category information to each attendance record
          attendanceItem['category_id'] = selectedCategory;
          attendanceItem['category_name'] = selectedCategoryName;

          // Add any additional processing here if needed

          enrichedData.add(attendanceItem);
        }

        // Store the attendance data in appController
        appController.getAttendanceLMB.removeAll();
        appController.getAttendanceLMB.addAll(enrichedData);
        appController.getAttendanceListMap = enrichedData;

        print('Attendance data loaded: ${enrichedData.length} records');
        if (enrichedData.isNotEmpty) {
          print('Sample record: ${enrichedData.first}');
        }
      } else {
        // Handle error or empty response
        print(
          'Failed to load attendance data: ${response['message'] ?? "Unknown error"}',
        );
        appController.getAttendanceLMB.removeAll();
        appController.getAttendanceListMap = [];
      }
    } catch (e) {
      print('Error loading attendance data: $e');
      appController.getAttendanceLMB.removeAll();
      appController.getAttendanceListMap = [];
    } finally {
      // Set loading state to false
      setLoading(false);
    }
  }
  
  // Method to show date filter dialog
  void showDateFilterDialog(BuildContext context) {
    // Initialize with current filter values if any
    DateTime? filterStartDate;
    DateTime? filterEndDate;
    
    if (startDateFilter.state.isNotEmpty) {
      filterStartDate = DateFormat('yyyy-MM-dd').parse(
        startDateFilter.state
      );
    }

    if (endDateFilter.state.isNotEmpty) {
      filterEndDate = DateFormat('yyyy-MM-dd').parse(
        endDateFilter.state
      );
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Date Range'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Start Date
              ListTile(
                title: const Text('Start Date'),
                subtitle: Text(
                  filterStartDate == null
                      ? 'Not set'
                      : DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                          .format(filterStartDate!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: filterStartDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      filterStartDate = picked;
                    });
                  }
                },
              ),

              // End Date
              ListTile(
                title: const Text('End Date'),
                subtitle: Text(
                  filterEndDate == null
                      ? 'Not set'
                      : DateFormat('EEEE, d MMMM yyyy', 'id_ID')
                          .format(filterEndDate!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final DateTime? picked = await showDatePicker(
                    context: context,
                    initialDate: filterEndDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (picked != null) {
                    setState(() {
                      filterEndDate = picked;
                    });
                  }
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              filterStartDate = null;
              filterEndDate = null;
              Navigator.pop(context);

              // Clear date filters
              clearDateFilters();
              appController.tglAwalFilter.changeVal('');
              appController.tglAkhirFilter.changeVal('');
              loadAttendanceData();
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);

              // Format dates for API
              String startDateStr = filterStartDate != null
                  ? DateFormat('yyyy-MM-dd').format(filterStartDate!)
                  : '';
              String endDateStr = filterEndDate != null
                  ? DateFormat('yyyy-MM-dd').format(filterEndDate!)
                  : '';

              // Update filters
              updateDateFilters(startDateStr, endDateStr);
              appController.tglAwalFilter.changeVal(startDateStr);
              appController.tglAkhirFilter.changeVal(endDateStr);
              loadAttendanceData();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }
}

AttendController attendController = AttendController();