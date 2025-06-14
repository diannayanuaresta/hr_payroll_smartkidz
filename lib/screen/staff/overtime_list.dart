import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hr_payroll/controller/app_controller.dart';
import 'package:hr_payroll/controller/overtime_controller.dart';
import 'package:hr_payroll/services/api.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';
import 'package:hr_payroll/components/color_app.dart';

class OvertimeScreen extends StatefulWidget {
  const OvertimeScreen({super.key});

  @override
  State<OvertimeScreen> createState() => _OvertimeScreenState();
}

class _OvertimeScreenState extends State<OvertimeScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final Api _api = Api();
  final MasterApi _masterApi = MasterApi();
  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;
  
  // Data untuk jenis lembur dari API
  List<Map<String, dynamic>> _jenisLemburList = [];
  bool _isLoadingJenisLembur = false;
  
  // Form controllers
  final TextEditingController _keperluanController = TextEditingController();
  final TextEditingController _startTimeController = TextEditingController();
  final TextEditingController _endTimeController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  String _selectedOvertimeType = ''; // Will be set from API data
  
  @override
  void initState() {
    super.initState();
    _loadOvertimeData();
    _loadJenisLembur(); // Load jenis lembur data from API
    
    // Listen for reload requests from other screens
    overtimeController.reloadOvertimeData.stream.listen((value) {
      if (value == 'true') {
        _loadOvertimeData();
        // Reset the flag
        overtimeController.reloadOvertimeData.changeVal('false');
      }
    });
  }
  
  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    _keperluanController.dispose();
    _startTimeController.dispose();
    _endTimeController.dispose();
    _dateController.dispose();
    super.dispose();
  }
  
  Future<void> _loadOvertimeData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Add a timeout to prevent UI from hanging indefinitely
    Future<void> loadDataWithTimeout() async {
      try {
        // Format dates for API request
        String startDateStr = '';
        String endDateStr = '';
        
        // Check if there are date filters in appController
        if (appController.tglAwalFilter.state.isNotEmpty) {
          startDateStr = appController.tglAwalFilter.state;
        } else if (_startDate != null) {
          startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
        }
        
        if (appController.tglAkhirFilter.state.isNotEmpty) {
          endDateStr = appController.tglAkhirFilter.state;
        } else if (_endDate != null) {
          endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
        }
        
        print('Filtering overtime with date range: $startDateStr to $endDateStr');
        
        // Fetch overtime data with date filters
        // Add timeout to prevent hanging
        final response = await _api.getLembur(
        startDate: startDateStr,
        endDate: endDateStr
        ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('Loading overtime data timed out. Please try again.');
        });
        
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
            if (overtimeItem['jamMulai'] != null && overtimeItem['jamSelesai'] != null) {
              try {
                final startTimeParts = (overtimeItem['jamMulai'] as String).split(':');
                final endTimeParts = (overtimeItem['jamSelesai'] as String).split(':');
                
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
            if (overtimeItem['statusSupervisor'] != null && overtimeItem['statusHrd'] != null) {
              if (overtimeItem['statusSupervisor'] == true && overtimeItem['statusHrd'] == true) {
                overtimeStatus = 'Approved';
              } else if (overtimeItem['statusSupervisor'] == false || overtimeItem['statusHrd'] == false) {
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
          print('Failed to load overtime data: ${response['message'] ?? "Unknown error"}');
          appController.getAttendanceLMB.removeAll();
          appController.getAttendanceListMap = [];
          
          // Show error message if not empty response
          if (response['message'] != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('${response['message']}'))
            );
          }
        }
      } catch (e) {
        print('Error loading overtime data: $e');
        appController.getAttendanceLMB.removeAll();
        appController.getAttendanceListMap = [];
        
        // Show error message for timeout or other errors
        String errorMessage = 'Error loading data';
        if (e is TimeoutException) {
          errorMessage = 'Connection timed out. Please try again.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage))
        );
      }
    }
    
    // Execute the data loading with timeout
    await loadDataWithTimeout();
    
    // Update UI state regardless of success or failure
    setState(() {
      _isLoading = false;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    return ScreenTypeLayout.builder(
      mobile: (context) => _buildScaffold(context),
      tablet: (context) => _buildScaffold(context, isTablet: true),
      desktop: (context) => _buildScaffold(context, isDesktop: true),
      watch: (context) => _buildScaffold(context, isWatch: true),
    );
  }

  // Show form dialog for adding overtime
  Future<void> _showAddOvertimeForm(BuildContext context) async {
    // Reset form values
    _keperluanController.clear();
    _startTimeController.clear();
    _endTimeController.clear();
    _dateController.clear();
    _selectedOvertimeType = 'event';
    
    // Map for overtime types
    final Map<String, String> overtimeTypes = {
      'event': 'Event',
      'tahunan': 'Tahunan',
      'bulanan': 'Bulanan',
    };
    
    // Form key for validation
    final formKey = GlobalKey<FormState>();
    
    // Show dialog
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tambah Data Lembur'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overtime Type Dropdown
                  _isLoadingJenisLembur
                  ? const Center(child: CircularProgressIndicator())
                  : _jenisLemburList.isEmpty
                  ? const Text('Tidak ada data jenis lembur')
                  : Builder(builder: (context) {
                      // Pastikan nilai _selectedOvertimeType valid
                      bool valueExists = false;
                      if (_selectedOvertimeType.isNotEmpty) {
                        valueExists = _jenisLemburList.any((item) => 
                          item['id'].toString() == _selectedOvertimeType);
                      }
                      
                      // Jika nilai tidak valid, gunakan nilai pertama dari list
                      if (!valueExists && _jenisLemburList.isNotEmpty) {
                        _selectedOvertimeType = _jenisLemburList[0]['id'].toString();
                      }
                      
                      return DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Jenis Lembur',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedOvertimeType,
                        items: _jenisLemburList.map((item) {
                          return DropdownMenuItem<String>(
                            value: item['id'].toString(),
                            child: Text(item['name'] ?? 'Tidak ada nama'),
                          );
                        }).toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setState(() {
                              _selectedOvertimeType = value;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Pilih jenis lembur';
                          }
                          return null;
                        },
                      );
                    }),
                  const SizedBox(height: 16),
                  
                  // Date Picker
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Tanggal',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih tanggal lembur';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Start Time Picker
                  TextFormField(
                    controller: _startTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Jam Mulai',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        // Format time as HH:MM
                        _startTimeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih jam mulai';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // End Time Picker
                  TextFormField(
                    controller: _endTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Jam Selesai',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        // Format time as HH:MM
                        _endTimeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih jam selesai';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Notes TextField
                  TextFormField(
                    controller: _keperluanController,
                    decoration: const InputDecoration(
                      labelText: 'Keperluan',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Masukkan keperluan lembur';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  // Show loading indicator
                  showDialog(
                    context: context,
                    barrierDismissible: false,
                    builder: (BuildContext context) {
                      return const AlertDialog(
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Menyimpan data...'),
                          ],
                        ),
                      );
                    },
                  );
                  
                  try {
                    // Prepare data for API
                    Map<String, String> dataLembur = {
                      'jenisLembur': _selectedOvertimeType,
                      'jamMulai': _startTimeController.text,
                      'jamSelesai': _endTimeController.text,
                      'tanggal': _dateController.text,
                      'keperluan': _keperluanController.text,
                    };
                    
                    // Call API
                    final response = await _api.addLembur(dataLembur);
                    
                    // Close loading dialog
                    Navigator.of(context).pop();
                    
                    // Close form dialog
                    Navigator.of(context).pop();
                    
                    // Show success or error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(response['message'] ?? (response['status'] == true ? 'Data lembur berhasil ditambahkan' : 'Gagal menambahkan data lembur')),
                        backgroundColor: response['status'] == true ? Colors.green : Colors.red,
                      ),
                    );
                    
                    // Reload data if successful
                    if (response['status'] == true) {
                      _loadOvertimeData();
                    }
                  } catch (e) {
                    // Close loading dialog
                    Navigator.of(context).pop();
                    
                    // Show error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
  
  // Load jenis lembur data from API
  Future<void> _loadJenisLembur() async {
    setState(() {
      _isLoadingJenisLembur = true;
    });
    
    try {
      final response = await _masterApi.jenisLembur();
      
      if (response['status'] == true && response['data'] != null) {
        setState(() {
          _jenisLemburList = List<Map<String, dynamic>>.from(response['data']);
          // Set default selected value if list is not empty
          if (_jenisLemburList.isNotEmpty) {
            _selectedOvertimeType = _jenisLemburList[0]['id'].toString();
          }
        });
      } else {
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Gagal memuat data jenis lembur'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      // Handle exception
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isLoadingJenisLembur = false;
      });
    }
  }
  
  // Show form dialog for adding overtime
  Future<void> _showOvertimeFormDialog(BuildContext context) async {
    // Reset form values
    _keperluanController.clear();
    _startTimeController.clear();
    _endTimeController.clear();
    _dateController.clear();
    
    // Validasi nilai _selectedOvertimeType
    bool valueExists = false;
    if (_selectedOvertimeType.isNotEmpty) {
      valueExists = _jenisLemburList.any((item) => 
        item['id'].toString() == _selectedOvertimeType);
    }
    
    // Set default jenis lembur if available or current value is invalid
    if (_jenisLemburList.isNotEmpty && (_selectedOvertimeType.isEmpty || !valueExists)) {
      setState(() {
        _selectedOvertimeType = _jenisLemburList[0]['id'].toString();
      });
    }
    
    // Form key for validation
    final formKey = GlobalKey<FormState>();
    
    // Show dialog
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tambah Data Lembur'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Overtime Type Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Jenis Lembur',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedOvertimeType,
                    items: _jenisLemburList.map((item) {
                      return DropdownMenuItem<String>(
                        value: _selectedOvertimeType,
                        child: Text(item['name'] ?? 'Tidak ada nama'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _selectedOvertimeType = value;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih jenis lembur';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Date Picker
                  TextFormField(
                    controller: _dateController,
                    decoration: const InputDecoration(
                      labelText: 'Tanggal',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih tanggal lembur';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Start Time Picker
                  TextFormField(
                    controller: _startTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Jam Mulai',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        // Format time as HH:MM
                        _startTimeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih jam mulai';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // End Time Picker
                  TextFormField(
                    controller: _endTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Jam Selesai',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: TimeOfDay.now(),
                      );
                      if (picked != null) {
                        // Format time as HH:MM
                        _endTimeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih jam selesai';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Notes TextField
                  TextFormField(
                    controller: _keperluanController,
                    decoration: const InputDecoration(
                      labelText: 'Keperluan',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Masukkan keperluan lembur';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => _submitOvertimeForm(context, formKey),
              child: const Text('Simpan'),
            ),
          ],
        );
      },
    );
  }
  
  // Submit overtime form data to API
  Future<void> _submitOvertimeForm(BuildContext context, GlobalKey<FormState> formKey) async {
    if (formKey.currentState!.validate()) {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Menyimpan data...'),
              ],
            ),
          );
        },
      );
      
      try {
        // Prepare data for API
        Map<String, String> dataLembur = {
          'jenisLembur': _selectedOvertimeType,
          'jamMulai': _startTimeController.text,
          'jamSelesai': _endTimeController.text,
          'tanggal': _dateController.text,
          'keperluan': _keperluanController.text,
        };
        
        // Call API
        final response = await _api.addLembur(dataLembur);
        
        // Close loading dialog
        Navigator.of(context).pop();
        
        // Close form dialog
        Navigator.of(context).pop();
        
        // Show success or error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? (response['status'] == true ? 'Data lembur berhasil ditambahkan' : 'Gagal menambahkan data lembur')),
            backgroundColor: response['status'] == true ? Colors.green : Colors.red,
          ),
        );
        
        // Reload data if successful
        if (response['status'] == true) {
          _loadOvertimeData();
        }
      } catch (e) {
        // Close loading dialog
        Navigator.of(context).pop();
        
        // Show error message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  Widget _buildScaffold(
    BuildContext context, {
    bool isTablet = false,
    bool isDesktop = false,
    bool isWatch = false,
  }) {
    final horizontalPadding = isTablet || isDesktop ? 32.0 : 16.0;
    final avatarRadius = isTablet || isDesktop ? 28.0 : 20.0;

    // Wrap with Scaffold to provide Material context
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddOvertimeForm(context),
        backgroundColor: ColorApp.lightPrimary,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadOvertimeData();
                  },
                  child: appController.getAttendanceListMap.isEmpty
                    ? ListView(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        children: [
                          Container(
                            height: MediaQuery.of(context).size.height * 0.6,
                            alignment: Alignment.center,
                            child: Text('Tidak ada data lembur'),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        itemCount: appController.getAttendanceListMap.length,
                        itemBuilder: (context, index) {
                          final overtime = appController.getAttendanceListMap[index];
                          print('Rendering overtime item $index: $overtime');
                          
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: OvertimeCard(
                              name: overtime['name'] ?? 'Staff',
                              role: overtime['role'] ?? 'Employee',
                              date: overtime['tanggal'] ?? '-',
                              startTime: overtime['jamMulai'] ?? '-',
                              endTime: overtime['jamSelesai'] ?? '-',
                              status: overtime['status'] ?? 'Pending',
                              duration: overtime['duration'] ?? '-',
                              notes: overtime['keperluan'] ?? '-',
                              avatarLabel: 'O', // Overtime label
                              avatarRadius: avatarRadius,
                              overtimeData: overtime, // Pass the full overtime data
                            ),
                          );
                        },
                      ),
                ),
          ),
        ],
      ),
    );
  }
}

class OvertimeCard extends StatelessWidget {
  final String name;
  final String role;
  final String date;
  final String startTime;
  final String endTime;
  final String status;
  final String duration;
  final String location;
  final String notes;
  final String avatarLabel;
  final double avatarRadius;
  final Map<dynamic, dynamic> overtimeData; // Full overtime data

  const OvertimeCard({
    super.key,
    required this.name,
    required this.role,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.duration,
    this.location = '-',
    this.notes = '-',
    this.avatarLabel = 'A',
    this.avatarRadius = 20.0,
    required this.overtimeData,
  });

  @override
  Widget build(BuildContext context) {
    // Extract additional data if available
    final String notes = overtimeData['keperluan'] ?? this.notes;
    
    // Use tanggal for date display if available, otherwise use date field
    final String dateToFormat = overtimeData['tanggal'] ?? date;
    
    // Format date and time for better readability
    String formattedDate = _formatDate(dateToFormat);
    String formattedStartTime = _formatTime(startTime);
    String formattedEndTime = _formatTime(endTime);
    
    // Determine status color based on approval status
    Color statusColor = Colors.orange; // Default pending color
    if (status.contains('Approved')) {
      statusColor = Colors.green;
    } else if (status.contains('Rejected')) {
      statusColor = Colors.red;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildProfileAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    Text(role, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
                  ],
                ),
              ),
              CircleAvatar(
                backgroundColor: Theme.of(context).brightness == Brightness.dark 
                    ? Theme.of(context).colorScheme.surface 
                    : const Color(0xFFF0F0F0),
                radius: 14,
                child: Text(
                  avatarLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoColumn(context, 'Date', formattedDate),
              _infoColumn(context, 'Duration', duration),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  _showDeleteConfirmation(context);
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Status indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: statusColor,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoColumn(context, 'Start Time', formattedStartTime),
              _infoColumn(context, 'End Time', formattedEndTime),
            ],
          ),

          // Location section removed as it's not in the overtime data
          if (notes != '-') ...[  // Only show if notes are available
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.note, color: Theme.of(context).textTheme.bodySmall?.color, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    notes,
                    style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 3,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoColumn(BuildContext context, String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color)),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14, color: Theme.of(context).textTheme.bodyMedium?.color),
        ),
      ],
    );
  }
  
  void _showDeleteConfirmation(BuildContext context) {
    final String id = overtimeData['id']?.toString() ?? '';
    
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: Invalid overtime ID')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Overtime'),
        content: const Text('Are you sure you want to delete this overtime record?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close confirmation dialog
              _performDelete(context, id);
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
  
  void _performDelete(BuildContext parentContext, String id) {
    // Store a reference to the context that will be used throughout the method
    // This helps prevent issues with deactivated widgets
    final BuildContext context = parentContext;
    
    // Create a flag to track if the operation has completed
    bool isOperationCompleted = false;
    
    // Reference to store the dialog context
    BuildContext? dialogContext;
    
    // Create a stateful dialog to show progress and status
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        // Store the dialog context for later use
        dialogContext = ctx;
        return AlertDialog(
          title: const Text('Deleting Overtime'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Please wait while we delete the overtime record...'),
            ],
          ),
        );
      },
    );
    
    // Function to safely close the dialog
    void safeCloseDialog() {
      if (!isOperationCompleted) {
        isOperationCompleted = true;
        
        // Use the stored dialog context to close the dialog
        if (dialogContext != null && Navigator.canPop(dialogContext!)) {
          Navigator.of(dialogContext!, rootNavigator: true).pop();
        }
      }
    }
    
    // Function to safely show a snackbar
    void safeShowSnackBar(String message) {
      try {
        // Only show the snackbar if the context is still valid
        if (context != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        }
      } catch (e) {
        print('Error showing snackbar: $e');
      }
    }
    
    // Execute the delete operation
    Future.delayed(Duration.zero, () async {
      try {
        // Add a local timeout to ensure the API call doesn't hang indefinitely
        final response = await Api().delAbsensi(id).timeout(
          const Duration(seconds: 10),
          onTimeout: () => {
            'status': false,
            'message': 'Request timed out. Please try again.'
          },
        );
        
        // Close the dialog
        safeCloseDialog();
        
        if (response['status'] == true) {
          // Show success message
          safeShowSnackBar('Overtime deleted successfully');
          
          // Trigger reload of overtime data
          overtimeController.reloadOvertimeData.changeVal('true');
        } else {
          // Show error message
          safeShowSnackBar('Failed to delete: ${response['message'] ?? "Unknown error"}');
        }
      } catch (e) {
        print('Error in _performDelete: $e');
        
        // Close the dialog
        safeCloseDialog();
        
        // Show error message
        safeShowSnackBar('Error: $e');
      }
    });
    
    // Add a safety timeout to dismiss the dialog if the operation takes too long
    Future.delayed(const Duration(seconds: 15), () {
      // Only dismiss if the operation hasn't completed yet
      if (!isOperationCompleted) {
        print('Safety timeout triggered for delete operation');
        
        // Close the dialog
        safeCloseDialog();
        
        // Show timeout message
        safeShowSnackBar('Operation timed out. Please try again.');
      }
    });
    
  }
  
  Widget _buildProfileAvatar() {
    // Check if photo data is available in base64 format
    final String? photoBase64 = overtimeData['photo'];
    
    // Safe substring to avoid errors with null or empty strings
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      print('Photo data: ${photoBase64.substring(0, photoBase64.length > 30 ? 30 : photoBase64.length)}...');
    } else {
      print('Photo data is null or empty');
    }
    
    // Check for invalid or placeholder data
    if (photoBase64 == null || photoBase64.isEmpty || photoBase64 == '-' || 
        photoBase64 == 'xxxx' || photoBase64.contains('data:image/png;base64,xxxx')) {
      print('Invalid or placeholder image data, using default avatar');
      return _buildDefaultAvatar();
    }
    
    try {
      // Extract the base64 part if it contains the data URI prefix
      String base64String = photoBase64;
      if (photoBase64.contains('base64,')) {
        print('Found base64 prefix, extracting actual base64 data');
        base64String = photoBase64.split('base64,')[1];
        print('Extracted base64 data length: ${base64String.length}');
      }
      
      // Check if the extracted string is valid
      if (base64String.isEmpty || base64String == 'xxxx') {
        print('Empty or placeholder base64 data, using default avatar');
        return _buildDefaultAvatar();
      }
      
      // Decode base64 string to image
      print('Attempting to decode base64 string of length: ${base64String.length}');
      final Uint8List bytes = base64Decode(base64String);
      print('Successfully decoded base64 image, byte length: ${bytes.length}');
      return CircleAvatar(
        backgroundColor: const Color(0xFFE0E0E0),
        radius: avatarRadius,
        backgroundImage: MemoryImage(bytes),
      );
    } catch (e) {
      print('Error decoding base64 image: $e');
      // Fallback to default avatar if decoding fails
      return _buildDefaultAvatar();
    }
  }
  
  Widget _buildDefaultAvatar() {
    return CircleAvatar(
      backgroundColor: const Color(0xFFE0E0E0),
      radius: avatarRadius,
      child: const Icon(Icons.person, color: Colors.purple),
    );
  }
  
  String _formatDate(String dateStr) {
    if (dateStr == '-' || dateStr.isEmpty) return '-';
    
    try {
      // Try to parse the date string
      DateTime? dateTime;
      
      // Handle different date formats
      try {
        // Try ISO format first (yyyy-MM-dd)
        dateTime = DateTime.parse(dateStr);
      } catch (e) {
        try {
          // Try dd/MM/yyyy format
          final parts = dateStr.split('/');
          if (parts.length == 3) {
            dateTime = DateTime(int.parse(parts[2]), int.parse(parts[1]), int.parse(parts[0]));
          }
        } catch (e) {
          print('Error parsing date: $e');
        }
      }
      
      if (dateTime != null) {
        // Format the date in Indonesian format
        // Use 'EEEE' for full day name (Senin, Selasa, etc.)
        // Use 'd MMMM yyyy' for date format (12 Agustus 2025)
        return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(dateTime); // e.g., "Senin, 12 Agustus 2025"
      }
    } catch (e) {
      print('Error formatting date: $e');
    }
    
    return dateStr; // Return original string if parsing fails
  }
  
  String _formatTime(String timeStr) {
    if (timeStr == '-' || timeStr.isEmpty) return '-';
    
    try {
      // Try to parse the time string
      TimeOfDay? timeOfDay;
      
      // Handle different time formats
      if (timeStr.contains(':')) {
        final parts = timeStr.split(':');
        if (parts.length >= 2) {
          int hour = int.parse(parts[0]);
          int minute = int.parse(parts[1].split(' ')[0]); // Handle cases like "14:30:00"
          
          // Check for AM/PM format
          if (timeStr.toLowerCase().contains('pm') && hour < 12) {
            hour += 12;
          } else if (timeStr.toLowerCase().contains('am') && hour == 12) {
            hour = 0;
          }
          
          timeOfDay = TimeOfDay(hour: hour, minute: minute);
        }
      }
      
      if (timeOfDay != null) {
        // Format in 24-hour format with 'pukul' prefix in Indonesian style
        return 'pukul ${timeOfDay.hour.toString().padLeft(2, '0')}.${timeOfDay.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      print('Error formatting time: $e');
    }
    
    return timeStr; // Return original string if parsing fails
  }
}