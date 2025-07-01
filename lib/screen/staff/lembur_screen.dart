import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show BlocBuilder, BlocBase;
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/controller/letter_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';

class LemburScreen extends StatefulWidget {
  const LemburScreen({super.key});

  @override
  State<LemburScreen> createState() => _LemburScreenState();
}

class _LemburScreenState extends State<LemburScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final Api _api = Api();
  bool _isLoading = false;

  // Form controllers
  final TextEditingController _keperluanController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadLemburData();

    // Listen for reload requests from other screens
    letterController.reloadLetterData.stream.listen((value) {
      if (value == 'true') {
        _loadLemburData();
        // Reset the flag
        letterController.reloadLetterData.changeVal('false');
      }
    });
  }

  @override
  void dispose() {
    // Clean up controllers when the widget is disposed
    _keperluanController.dispose();
    _startDateController.dispose();
    super.dispose();
  }

  // Load lembur data from API
  Future<void> _loadLemburData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get date filter values from appController
      String startDateStr = appController.tglAwalFilter.state;
      String endDateStr = appController.tglAkhirFilter.state;

      // Set default values if empty
      if (startDateStr.isEmpty) {
        // Default startDate: 1 month ago from today
        final DateTime defaultStartDate = DateTime.now().subtract(
          const Duration(days: 30),
        );
        startDateStr = DateFormat('yyyy-MM-dd').format(defaultStartDate);
        // Update the appController value
        appController.tglAwalFilter.changeVal(startDateStr);
      }

      if (endDateStr.isEmpty) {
        // Default endDate: today
        final DateTime defaultEndDate = DateTime.now();
        endDateStr = DateFormat('yyyy-MM-dd').format(defaultEndDate);
        // Update the appController value
        appController.tglAkhirFilter.changeVal(endDateStr);
      }

      print('Using date range: $startDateStr to $endDateStr');

      // Create data container for letters
      List<Map<String, dynamic>> letterData = [];

      try {
        // Fetch overtime data with date filters
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

        print('API Response for Lembur: $response');

        if (response['status'] == true && response['data'] != null) {
          // Process and enrich the data
          for (var item in response['data']) {
            // Convert to Map<String, dynamic> if it's not already
            Map<String, dynamic> overtimeItem = Map<String, dynamic>.from(
              item,
            );

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

            // Transform the overtime data to match the letter data structure
            Map<String, dynamic> letterItem = {
              'id': overtimeItem['id'],
              'name': overtimeItem['pegawaiNama'] ?? 'Unknown',
              'role': overtimeItem['pegawaiJabatan'] ?? 'Employee',
              'letterType': 'Surat Lembur',
              'tanggal': overtimeItem['tanggal'] ?? '',
              'startDate': overtimeItem['tanggal'] ?? '',
              'endDate': overtimeItem['tanggal'] ?? '',
              'status': _determineStatus(
                overtimeItem['statusSupervisor'],
                overtimeItem['statusHrd'],
              ),
              'keperluan': overtimeItem['keperluan'] ?? '-',
              'category_id': '1',
              'category_name': 'Surat Lembur',
              // Add additional fields from the API that might be useful
              'jamMulai': overtimeItem['jamMulai'],
              'jamSelesai': overtimeItem['jamSelesai'],
              'duration': calculatedDuration,
              'createdAt': overtimeItem['createdAt'],
              'jenisLembur': overtimeItem['jenisLembur'],
              // Tambahkan status supervisor dan HRD untuk badge
              'statusSupervisor': overtimeItem['statusSupervisor'],
              'statusHrd': overtimeItem['statusHrd'],
            };

            letterData.add(letterItem);
          }
        } else {
          // If API returns error or no data
          print('No overtime data found or API error');
          letterData = [];
        }
      } catch (e) {
        print('Error fetching overtime data: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading overtime data: $e')),
        );
        letterData = [];
      }

      // Store the letter data in appController
      appController.getAttendanceLMB.removeAll();
      appController.getAttendanceLMB.addAll(letterData);
      appController.getAttendanceListMap = letterData;
    } catch (e) {
      print('Error loading letter data: $e');
      appController.getAttendanceLMB.removeAll();
      appController.getAttendanceListMap = [];

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper method to determine status text based on supervisor and HRD status
  String _determineStatus(dynamic supervisorStatus, dynamic hrdStatus) {
    if (supervisorStatus == 0 || supervisorStatus == '0') {
      return 'Pending';
    } else if (supervisorStatus == 2 || supervisorStatus == '2') {
      return 'Rejected';
    } else if (supervisorStatus == 1 || supervisorStatus == '1') {
      if (hrdStatus == 0 || hrdStatus == '0') {
        return 'Approved by Supervisor';
      } else if (hrdStatus == 2 || hrdStatus == '2') {
        return 'Rejected by HRD';
      } else if (hrdStatus == 1 || hrdStatus == '1') {
        return 'Approved';
      }
    }
    return 'Unknown';
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

  // Show form dialog for adding letter
  Future<void> _showAddLemburForm(BuildContext context) async {
    // Reset form values
    _keperluanController.clear();
    _startDateController.clear();

    // Tambahan untuk lembur
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();
    String selectedOvertimeType = '';
    List<Map<String, dynamic>> jenisLemburData = [];

    // Ambil data jenis lembur jika tersedia di appController
    if (appController.jenisLemburListMap.isNotEmpty) {
      jenisLemburData = List<Map<String, dynamic>>.from(
        appController.jenisLemburListMap,
      );
      if (jenisLemburData.isNotEmpty) {
        selectedOvertimeType = jenisLemburData[0]['id'].toString();
      }
    }

    // Form key for validation
    final formKey = GlobalKey<FormState>();

    // Show dialog
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Tambah Surat Lembur'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Jenis Lembur Dropdown
                      Builder(
                        builder: (context) {
                          // Validasi nilai yang dipilih
                          bool valueExists = false;
                          if (selectedOvertimeType.isNotEmpty) {
                            valueExists = jenisLemburData.any(
                              (item) =>
                                  item['id'].toString() == selectedOvertimeType,
                            );
                          }

                          // Jika nilai tidak valid, gunakan nilai pertama dari list
                          if (!valueExists && jenisLemburData.isNotEmpty) {
                            selectedOvertimeType = jenisLemburData[0]['id']
                                .toString();
                          }

                          return DropdownButtonFormField<String>(
                            decoration: const InputDecoration(
                              labelText: 'Jenis Lembur',
                              border: OutlineInputBorder(),
                            ),
                            value: selectedOvertimeType,
                            items: jenisLemburData.map((item) {
                              return DropdownMenuItem<String>(
                                value: item['id'].toString(),
                                child: Text(item['name'] ?? 'Tidak ada nama'),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  selectedOvertimeType = value;
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
                        },
                      ),
                      const SizedBox(height: 16),

                      // Tanggal untuk Surat Lembur
                      TextFormField(
                        controller: _startDateController,
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
                            setState(() {
                              _startDateController.text = DateFormat(
                                'yyyy-MM-dd',
                              ).format(picked);
                            });
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

                      // Start Time Picker untuk Surat Lembur
                      TextFormField(
                        controller: startTimeController,
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
                            setState(() {
                              startTimeController.text =
                                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                            });
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

                      // End Time Picker untuk Surat Lembur
                      TextFormField(
                        controller: endTimeController,
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
                            setState(() {
                              endTimeController.text =
                                  '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
                            });
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

                      // Keperluan untuk Surat Lembur
                      TextFormField(
                        controller: _keperluanController,
                        decoration: const InputDecoration(
                          labelText: 'Keperluan',
                          border: OutlineInputBorder(),
                          hintText: 'Masukkan keperluan lembur',
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Keperluan tidak boleh kosong';
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
                    Navigator.pop(context);
                  },
                  child: const Text('Batal'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      // Tampilkan loading indicator
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
                          'jenisLembur': selectedOvertimeType,
                          'jamMulai': startTimeController.text,
                          'jamSelesai': endTimeController.text,
                          'tanggal': _startDateController.text,
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
                            content: Text(
                              response['message'] ??
                                  (response['status'] == true
                                      ? 'Data berhasil ditambahkan'
                                      : 'Gagal menambahkan data'),
                            ),
                            backgroundColor: response['status'] == true
                                ? Colors.green
                                : Colors.red,
                          ),
                        );

                        // Reload data if successful
                        if (response['status'] == true) {
                          _loadLemburData();
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
      },
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    bool isTablet = false,
    bool isDesktop = false,
    bool isWatch = false,
  }) {
    final horizontalPadding = isTablet || isDesktop ? 32.0 : 16.0;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Surat Lembur'),
        backgroundColor: Theme.of(context).primaryColor,
      ),
      body: Column(
        children: [
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _buildLetterList(context),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Theme.of(context).primaryColor,
        onPressed: () => _showAddLemburForm(context),
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }

  Widget _buildLetterList(BuildContext context) {
    return BlocBuilder(
      bloc: appController.getAttendanceLMB,
      builder: (context, state) {
        if (appController.getAttendanceListMap.isEmpty) {
          return const Center(child: Text('Tidak ada data surat lembur'));
        }

        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: ListView.builder(
                  itemCount: appController.getAttendanceListMap.length,
                  itemBuilder: (context, index) {
                    final letterData =
                        appController.getAttendanceListMap[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: LetterCard(
                        name: letterData['name'] ?? 'Unknown',
                        role: letterData['role'] ?? 'Unknown',
                        date: letterData['tanggal'] ?? '',
                        startDate: letterData['startDate'] ?? '',
                        endDate: letterData['endDate'] ?? '',
                        status: letterData['status'] ?? 'Pending',
                        letterType: letterData['letterType'] ?? 'Unknown',
                        notes: letterData['keperluan'] ?? '-',
                        letterData: letterData,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class LetterCard extends StatelessWidget {
  final String name;
  final String role;
  final String date;
  final String startDate;
  final String endDate;
  final String status;
  final String letterType;
  final String notes;
  final String avatarLabel;
  final double avatarRadius;
  final Map<dynamic, dynamic> letterData; // Full letter data

  const LetterCard({
    super.key,
    required this.name,
    required this.role,
    required this.date,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.letterType,
    this.notes = '-',
    this.avatarLabel = 'S',
    this.avatarRadius = 20.0,
    required this.letterData,
  });

  // Helper method to format date
  String _formatDate(String dateStr) {
    try {
      final DateTime date = DateTime.parse(dateStr);
      return DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: avatarRadius,
                  backgroundColor: Theme.of(context).primaryColor,
                  child: Text(
                    avatarLabel,
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
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
                      Text(role, style: const TextStyle(fontSize: 14)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: status.toLowerCase().contains('approved')
                        ? Colors.green[100]
                        : status.toLowerCase().contains('rejected')
                            ? Colors.red[100]
                            : Colors.orange[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: status.toLowerCase().contains('approved')
                          ? Colors.green[800]
                          : status.toLowerCase().contains('rejected')
                              ? Colors.red[800]
                              : Colors.orange[800],
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildInfoRow('Tanggal', _formatDate(date)),
            if (letterData['jamMulai'] != null)
              _buildInfoRow('Jam Mulai', letterData['jamMulai']),
            if (letterData['jamSelesai'] != null)
              _buildInfoRow('Jam Selesai', letterData['jamSelesai']),
            if (letterData['duration'] != null)
              _buildInfoRow('Durasi', letterData['duration']),
            _buildInfoRow('Keperluan', notes),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          const Text(': '),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
}