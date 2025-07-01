import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show BlocBuilder;
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/controller/letter_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';

class SakitScreen extends StatefulWidget {
  const SakitScreen({super.key});

  @override
  State<SakitScreen> createState() => _SakitScreenState();
}

class _SakitScreenState extends State<SakitScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final Api _api = Api();
  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;

  // Form controllers
  final TextEditingController _keperluanController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSakitData();

    // Listen for reload requests from other screens
    letterController.reloadLetterData.stream.listen((value) {
      if (value == 'true') {
        _loadSakitData();
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

  Future<void> _loadSakitData() async {
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

        print(
          'Filtering sakit with date range: $startDateStr to $endDateStr',
        );

        // Fetch sakit data with date filters
        // Add timeout to prevent hanging
        final response = await _api
            .getSakit(startDate: startDateStr, endDate: endDateStr)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'Loading sakit data timed out. Please try again.',
                );
              },
            );

        print('API Response: $response');

        if (response['status'] == true && response['data'] != null) {
          // Process and enrich the data
          List<Map<String, dynamic>> enrichedData = [];

          for (var item in response['data']) {
            // Convert to Map<String, dynamic> if it's not already
            Map<String, dynamic> sakitItem = Map<String, dynamic>.from(item);

            // Calculate duration from start and end date
            String calculatedDuration = '-';
            if (sakitItem['tanggalAwal'] != null &&
                sakitItem['tanggalAkhir'] != null) {
              try {
                final startDate = DateTime.parse(sakitItem['tanggalAwal']);
                final endDate = DateTime.parse(sakitItem['tanggalAkhir']);
                
                final difference = endDate.difference(startDate).inDays + 1;
                calculatedDuration = '$difference hari';
              } catch (e) {
                print('Error calculating duration: $e');
              }
            }
            sakitItem['duration'] = calculatedDuration;

            // Determine status based on supervisor and HRD approval
            String sakitStatus = 'Pending';
            if (sakitItem['statusSupervisor'] != null &&
                sakitItem['statusHrd'] != null) {
              if (sakitItem['statusSupervisor'] == true &&
                  sakitItem['statusHrd'] == true) {
                sakitStatus = 'Approved';
              } else if (sakitItem['statusSupervisor'] == false ||
                  sakitItem['statusHrd'] == false) {
                sakitStatus = 'Rejected';
              }
            } else if (sakitItem['statusSupervisor'] == true) {
              sakitStatus = 'Approved by Supervisor';
            } else if (sakitItem['statusSupervisor'] == false) {
              sakitStatus = 'Rejected by Supervisor';
            }
            sakitItem['status'] = sakitStatus;

            enrichedData.add(sakitItem);
          }

          // Store the sakit data in appController
          appController.sakitLMB.removeAll();
          appController.sakitLMB.addAll(enrichedData);
          appController.sakitListMap = enrichedData;

          print('Sakit data loaded: ${enrichedData.length} records');
          if (enrichedData.isNotEmpty) {
            print('Sample record: ${enrichedData.first}');
          }
        } else {
          // Handle error or empty response
          print(
            'Failed to load sakit data: ${response['message'] ?? "Unknown error"}',
          );
          appController.sakitLMB.removeAll();
          appController.sakitListMap = [];

          // Show error message if not empty response
          if (response['message'] != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('${response['message']}')));
          }
        }
      } catch (e) {
        print('Error loading sakit data: $e');
        appController.sakitLMB.removeAll();
        appController.sakitListMap = [];

        // Show error message for timeout or other errors
        String errorMessage = 'Error loading data';
        if (e is TimeoutException) {
          errorMessage = 'Connection timed out. Please try again.';
        }

        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(errorMessage)));
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

  // Show form dialog for adding sakit
  Future<void> _showAddSakitForm(BuildContext context) async {
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
        return AlertDialog(
          title: const Text('Tambah Surat Sakit'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Start Date Picker
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
                        _startDateController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih tanggal mulai sakit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // End Date Picker
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
                        _endDateController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih tanggal selesai sakit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notes TextField
                  TextFormField(
                    controller: _keperluanController,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Masukkan keterangan sakit';
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
                    Map<String, String> dataSakit = {
                      'tanggalAwal': _startDateController.text,
                      'tanggalAkhir': _endDateController.text,
                      'keterangan': _keperluanController.text,
                    };

                    // Call API
                    final response = await _api.addSakit(dataSakit);

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
                                  ? 'Data sakit berhasil ditambahkan'
                                  : 'Gagal menambahkan data sakit'),
                        ),
                        backgroundColor: response['status'] == true
                            ? Colors.green
                            : Colors.red,
                      ),
                    );

                    // Reload data if successful
                    if (response['status'] == true) {
                      _loadSakitData();
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

  // Show form dialog for editing sakit
  Future<void> _showEditSakitForm(
    BuildContext context,
    Map<dynamic, dynamic> sakitData,
  ) async {
    // Set form values from existing data
    final String id = sakitData['id']?.toString() ?? '';
    _keperluanController.text = sakitData['keterangan'] ?? '';
    _startDateController.text = sakitData['tanggalAwal'] ?? '';
    _endDateController.text = sakitData['tanggalAkhir'] ?? '';

    // Form key for validation
    final formKey = GlobalKey<FormState>();

    // Show dialog
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Surat Sakit'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Start Date Picker
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
                        initialDate:
                            DateTime.tryParse(_startDateController.text) ??
                            DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        _startDateController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih tanggal mulai sakit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // End Date Picker
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
                        initialDate:
                            DateTime.tryParse(_endDateController.text) ??
                            DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        _endDateController.text = DateFormat(
                          'yyyy-MM-dd',
                        ).format(picked);
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih tanggal selesai sakit';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Notes TextField
                  TextFormField(
                    controller: _keperluanController,
                    decoration: const InputDecoration(
                      labelText: 'Keterangan',
                      border: OutlineInputBorder(),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Masukkan keterangan sakit';
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
                            Text('Menyimpan perubahan...'),
                          ],
                        ),
                      );
                    },
                  );

                  try {
                    // Prepare data for API
                    Map<String, String> dataSakit = {
                      'tanggalAwal': _startDateController.text,
                      'tanggalAkhir': _endDateController.text,
                      'keterangan': _keperluanController.text,
                    };

                    // Call API to update
                    final response = await _api.updateSakit(dataSakit, id);

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
                                  ? 'Data sakit berhasil diperbarui'
                                  : 'Gagal memperbarui data sakit'),
                        ),
                        backgroundColor: response['status'] == true
                            ? Colors.green
                            : Colors.red,
                      ),
                    );

                    // Reload data if successful
                    if (response['status'] == true) {
                      letterController.reloadLetterData.changeVal('true');
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

  Widget _buildScaffold(
    BuildContext context, {
    bool isTablet = false,
    bool isDesktop = false,
    bool isWatch = false,
  }) {
    return Scaffold(
      body: RefreshIndicator(
        onRefresh: () => _loadSakitData(),
        child: Column(
          children: [
            // Header with filter and add button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Filter button
                  ElevatedButton.icon(
                    onPressed: () {
                      _showDateFilterDialog(context);
                    },
                    icon: const Icon(Icons.filter_list),
                    label: const Text('Filter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                  // Add button
                  ElevatedButton.icon(
                    onPressed: () {
                      _showAddSakitForm(context);
                    },
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Date filter chips
            if (_startDate != null || _endDate != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Row(
                  children: [
                    const Text('Filter: '),
                    const SizedBox(width: 8),
                    if (_startDate != null)
                      Chip(
                        label: Text(
                          'Dari: ${DateFormat('dd/MM/yyyy').format(_startDate!)}',
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _startDate = null;
                            appController.tglAwalFilter.changeVal('');
                            _loadSakitData();
                          });
                        },
                      ),
                    const SizedBox(width: 8),
                    if (_endDate != null)
                      Chip(
                        label: Text(
                          'Sampai: ${DateFormat('dd/MM/yyyy').format(_endDate!)}',
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _endDate = null;
                            appController.tglAkhirFilter.changeVal('');
                            _loadSakitData();
                          });
                        },
                      ),
                  ],
                ),
              ),

            // Main content - List of sakit data
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : BlocBuilder(
                      bloc: appController.sakitLMB,
                      builder: (context, state) {
                        if (appController.sakitListMap.isEmpty) {
                          return const Center(
                            child: Text('Tidak ada data surat sakit'),
                          );
                        }

                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: appController.sakitListMap.length,
                          itemBuilder: (context, index) {
                            final sakitData = appController.sakitListMap[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: SakitCard(
                                sakitData: sakitData,
                                onEdit: () {
                                  _showEditSakitForm(context, sakitData);
                                },
                                onDelete: () {
                                  _showDeleteConfirmationDialog(context, sakitData);
                                },
                              ),
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // Show date filter dialog
  void _showDateFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Date Range'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Start Date
            ListTile(
              title: const Text('Start Date'),
              subtitle: Text(
                _startDate == null
                    ? 'Not set'
                    : DateFormat('EEEE, d MMMM yyyy').format(_startDate!),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() {
                    _startDate = picked;
                    // Update appController value immediately
                    appController.tglAwalFilter.changeVal(
                      DateFormat('yyyy-MM-dd').format(picked),
                    );
                  });
                }
              },
            ),

            // End Date
            ListTile(
              title: const Text('End Date'),
              subtitle: Text(
                _endDate == null
                    ? 'Not set'
                    : DateFormat('EEEE, d MMMM yyyy').format(_endDate!),
              ),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final DateTime? picked = await showDatePicker(
                  context: context,
                  initialDate: _endDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (picked != null) {
                  setState(() {
                    _endDate = picked;
                    // Update appController value immediately
                    appController.tglAkhirFilter.changeVal(
                      DateFormat('yyyy-MM-dd').format(picked),
                    );
                  });
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() {
                _startDate = null;
                _endDate = null;
              });
              Navigator.pop(context);

              // Clear date filter in app controller
              appController.tglAwalFilter.changeVal('');
              appController.tglAkhirFilter.changeVal('');
              
              // Reload data
              _loadSakitData();
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
              _loadSakitData();
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmationDialog(
    BuildContext context,
    Map<dynamic, dynamic> sakitData,
  ) {
    final String id = sakitData['id']?.toString() ?? '';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi Hapus'),
          content: const Text(
            'Apakah Anda yakin ingin menghapus surat sakit ini?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
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
                          Text('Menghapus data...'),
                        ],
                      ),
                    );
                  },
                );

                try {
                  // Call API to delete
                  final response = await _api.delSakit(id);

                  // Close loading dialog
                  Navigator.of(context).pop();

                  // Close confirmation dialog
                  Navigator.of(context).pop();

                  // Show success or error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        response['message'] ??
                            (response['status'] == true
                                ? 'Data sakit berhasil dihapus'
                                : 'Gagal menghapus data sakit'),
                      ),
                      backgroundColor: response['status'] == true
                          ? Colors.green
                          : Colors.red,
                    ),
                  );

                  // Reload data if successful
                  if (response['status'] == true) {
                    _loadSakitData();
                  }
                } catch (e) {
                  // Close loading dialog
                  Navigator.of(context).pop();

                  // Close confirmation dialog
                  Navigator.of(context).pop();

                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  Widget _infoColumn(BuildContext context, String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    return CircleAvatar(
      radius: 20,
      backgroundColor: Colors.red.shade100,
      child: const Icon(
        Icons.medical_services,
        color: Colors.red,
      ),
    );
  }
}

// Card widget for displaying sakit data
class SakitCard extends StatelessWidget {
  final Map<dynamic, dynamic> sakitData;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const SakitCard({
    super.key,
    required this.sakitData,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Extract data from sakitData
    final String name = sakitData['name'] ?? 'User';
    final String role = sakitData['role'] ?? 'Staff';
    final String duration = sakitData['duration'] ?? '-';
    final String status = sakitData['status'] ?? 'Pending';
    final String notes = sakitData['keterangan'] ?? '-';
    
    // Format dates
    String formattedStartDate = '-';
    String formattedEndDate = '-';
    
    if (sakitData['tanggalAwal'] != null) {
      try {
        final startDate = DateTime.parse(sakitData['tanggalAwal']);
        formattedStartDate = DateFormat('dd MMM yyyy').format(startDate);
      } catch (e) {
        formattedStartDate = sakitData['tanggalAwal'];
      }
    }
    
    if (sakitData['tanggalAkhir'] != null) {
      try {
        final endDate = DateTime.parse(sakitData['tanggalAkhir']);
        formattedEndDate = DateFormat('dd MMM yyyy').format(endDate);
      } catch (e) {
        formattedEndDate = sakitData['tanggalAkhir'];
      }
    }

    // Determine avatar label
    final String avatarLabel = name.isNotEmpty ? name[0].toUpperCase() : 'U';

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
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.red.shade100,
                child: Text(
                  avatarLabel,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.bold,
                  ),
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
                    Text(
                      role,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
                  ],
                ),
              ),
              // Vertical column of buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: onEdit,
                    child: Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.edit, color: Colors.blue, size: 16),
                    ),
                  ),
                  InkWell(
                    onTap: onDelete,
                    child: Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.delete, color: Colors.red, size: 16),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoColumn(context, 'Duration', duration),
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
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _infoColumn(context, 'Start Date', formattedStartDate),
              _infoColumn(context, 'End Date', formattedEndDate),
            ],
          ),

          if (notes != '-') ...[  // Only show if notes are available
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.note,
                  color: Theme.of(context).textTheme.bodySmall?.color,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    notes,
                    style: TextStyle(
                      color: Theme.of(context).textTheme.bodySmall?.color,
                    ),
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
        Text(
          title,
          style: TextStyle(
            color: Theme.of(context).textTheme.bodySmall?.color,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}