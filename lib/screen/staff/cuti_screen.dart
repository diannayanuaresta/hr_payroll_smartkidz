import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show BlocBuilder, BlocBase;
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/controller/letter_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';

class CutiScreen extends StatefulWidget {
  const CutiScreen({super.key});

  @override
  State<CutiScreen> createState() => _CutiScreenState();
}

class _CutiScreenState extends State<CutiScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final Api _api = Api();
  bool _isLoading = false;

  // Form controllers
  final TextEditingController _keperluanController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCutiData();

    // Listen for reload requests from other screens
    letterController.reloadLetterData.stream.listen((value) {
      if (value == 'true') {
        _loadCutiData();
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
    _endDateController.dispose();
    super.dispose();
  }

  // Load cuti data from API
  Future<void> _loadCutiData() async {
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
        // Fetch Cuti data from API with date filters
        final response = await _api.getCuti(
          startDate: startDateStr,
          endDate: endDateStr,
        );

        if (response['status'] == true && response['data'] != null) {
          final List<dynamic> cutiData = response['data'];

          letterData = cutiData.map((item) {
            return {
              'id': item['id'],
              'name': item['pegawaiNama'] ?? 'Staff',
              'role': item['pegawaiJabatan'] ?? 'Employee',
              'letterType': 'Surat Cuti',
              'tanggal': item['createdAt']?.toString().split(' ')[0] ?? '',
              'startDate': item['tanggalAwal'] ?? '',
              'endDate': item['tanggalAkhir'] ?? '',
              'status': _getStatusText(
                item['verifSupervisor'],
                item['verifHrd'],
              ),
              'keperluan': item['keterangan'] ?? '',
              'category_id': '2',
              'category_name': 'Surat Cuti',
            };
          }).toList();
        } else {
          // Handle error or empty response
          letterData = [];
        }
      } catch (e) {
        print('Error fetching cuti data: $e');
        // Jika terjadi error, gunakan array kosong
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

  // Helper method to determine status text based on verification status
  String _getStatusText(dynamic supervisorStatus, dynamic hrdStatus) {
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

  // Show form dialog for adding cuti
  Future<void> _showAddCutiForm(BuildContext context) async {
    // Reset form values
    _keperluanController.clear();
    _startDateController.clear();
    _endDateController.clear();

    // Form key for validation
    final formKey = GlobalKey<FormState>();

    // Show dialog
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Tambah Surat Cuti'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Start Date Picker untuk Surat Cuti
                      TextFormField(
                        controller: _startDateController,
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Mulai',
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
                            return 'Pilih tanggal mulai';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // End Date Picker untuk Surat Cuti
                      TextFormField(
                        controller: _endDateController,
                        decoration: const InputDecoration(
                          labelText: 'Tanggal Selesai',
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
                              _endDateController.text = DateFormat(
                                'yyyy-MM-dd',
                              ).format(picked);
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Pilih tanggal selesai';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Keterangan untuk Surat Cuti
                      TextFormField(
                        controller: _keperluanController,
                        decoration: const InputDecoration(
                          labelText: 'Keterangan',
                          border: OutlineInputBorder(),
                          hintText: 'Masukkan keterangan cuti',
                        ),
                        maxLines: 3,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Keterangan tidak boleh kosong';
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
                        Map<String, String> dataCuti = {
                          'tanggalAwal': _startDateController.text,
                          'tanggalAkhir': _endDateController.text,
                          'keterangan': _keperluanController.text,
                        };

                        // Call API
                        final response = await _api.addCuti(dataCuti);

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
                          _loadCutiData();
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
        title: const Text('Surat Cuti'),
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
        onPressed: () => _showAddCutiForm(context),
        child: Icon(Icons.add, color: Theme.of(context).colorScheme.onPrimary),
      ),
    );
  }

  Widget _buildLetterList(BuildContext context) {
    return BlocBuilder(
      bloc: appController.getAttendanceLMB,
      builder: (context, state) {
        if (appController.getAttendanceListMap.isEmpty) {
          return const Center(child: Text('Tidak ada data surat cuti'));
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
            _buildInfoRow('Tanggal Mulai', _formatDate(startDate)),
            _buildInfoRow('Tanggal Selesai', _formatDate(endDate)),
            _buildInfoRow('Keterangan', notes),
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
            width: 120,
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