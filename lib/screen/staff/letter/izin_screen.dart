import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show BlocBuilder;
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/controller/letter_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';

class IzinScreen extends StatefulWidget {
  const IzinScreen({super.key});

  @override
  State<IzinScreen> createState() => _IzinScreenState();
}

class _IzinScreenState extends State<IzinScreen>
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
    _loadIzinData();

    // Listen for reload requests from other screens
    letterController.reloadLetterData.stream.listen((value) {
      if (value == 'true') {
        _loadIzinData();
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

  Future<void> _loadIzinData() async {
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
          'Filtering izin with date range: $startDateStr to $endDateStr',
        );

        // Fetch izin data with date filters
        // Add timeout to prevent hanging
        final response = await _api
            .getIzin(startDate: startDateStr, endDate: endDateStr)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'Loading izin data timed out. Please try again.',
                );
              },
            );

        print('API Response: $response');

        if (response['status'] == true && response['data'] != null) {
          // Process and enrich the data
          List<Map<String, dynamic>> enrichedData = [];

          for (var item in response['data']) {
            // Convert to Map<String, dynamic> if it's not already
            Map<String, dynamic> izinItem = Map<String, dynamic>.from(item);

            // Calculate duration from start and end date
            String calculatedDuration = '-';
            if (izinItem['tanggalAwal'] != null &&
                izinItem['tanggalAkhir'] != null) {
              try {
                final startDate = DateTime.parse(izinItem['tanggalAwal']);
                final endDate = DateTime.parse(izinItem['tanggalAkhir']);
                
                final difference = endDate.difference(startDate).inDays + 1;
                calculatedDuration = '$difference hari';
              } catch (e) {
                print('Error calculating duration: $e');
              }
            }
            izinItem['duration'] = calculatedDuration;

            // Determine status based on supervisor and HRD approval
            String izinStatus = 'Pending';
            if (izinItem['statusSupervisor'] != null &&
                izinItem['statusHrd'] != null) {
              if (izinItem['statusSupervisor'] == true &&
                  izinItem['statusHrd'] == true) {
                izinStatus = 'Approved';
              } else if (izinItem['statusSupervisor'] == false ||
                  izinItem['statusHrd'] == false) {
                izinStatus = 'Rejected';
              }
            } else if (izinItem['statusSupervisor'] == true) {
              izinStatus = 'Approved by Supervisor';
            } else if (izinItem['statusSupervisor'] == false) {
              izinStatus = 'Rejected by Supervisor';
            }
            izinItem['status'] = izinStatus;

            enrichedData.add(izinItem);
          }

          // Store the izin data in appController
          appController.izinLMB.removeAll();
          appController.izinLMB.addAll(enrichedData);
          appController.izinListMap = enrichedData;

          print('Izin data loaded: ${enrichedData.length} records');
          if (enrichedData.isNotEmpty) {
            print('Sample record: ${enrichedData.first}');
          }
        } else {
          // Handle error or empty response
          print(
            'Failed to load izin data: ${response['message'] ?? "Unknown error"}',
          );
          appController.izinLMB.removeAll();
          appController.izinListMap = [];

          // Show error message if not empty response
          if (response['message'] != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('${response['message']}')));
          }
        }
      } catch (e) {
        print('Error loading izin data: $e');
        appController.izinLMB.removeAll();
        appController.izinListMap = [];

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

  // Show form dialog for adding izin
  Future<void> _showAddIzinForm(BuildContext context) async {
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
          title: const Text('Tambah Surat Izin'),
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
                        return 'Pilih tanggal mulai izin';
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
                        return 'Pilih tanggal selesai izin';
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
                        return 'Masukkan keperluan izin';
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
                    Map<String, String> dataIzin = {
                      'tanggalAwal': _startDateController.text,
                      'tanggalAkhir': _endDateController.text,
                      'keterangan': _keperluanController.text,
                    };

                    // Call API
                    final response = await _api.addIzin(dataIzin);

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
                                  ? 'Data izin berhasil ditambahkan'
                                  : 'Gagal menambahkan data izin'),
                        ),
                        backgroundColor: response['status'] == true
                            ? Colors.green
                            : Colors.red,
                      ),
                    );

                    // Reload data if successful
                    if (response['status'] == true) {
                      _loadIzinData();
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

  // Show form dialog for editing izin
  Future<void> _showEditIzinForm(
    BuildContext context,
    Map<dynamic, dynamic> izinData,
  ) async {
    // Set form values from existing data
    final String id = izinData['id']?.toString() ?? '';
    _keperluanController.text = izinData['keterangan'] ?? '';
    _startDateController.text = izinData['tanggalAwal'] ?? '';
    _endDateController.text = izinData['tanggalAkhir'] ?? '';

    // Form key for validation
    final formKey = GlobalKey<FormState>();

    // Show dialog
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Surat Izin'),
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
                        return 'Pilih tanggal mulai izin';
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
                        return 'Pilih tanggal selesai izin';
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
                        return 'Masukkan keperluan izin';
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
                    Map<String, String> dataIzin = {
                      'tanggalAwal': _startDateController.text,
                      'tanggalAkhir': _endDateController.text,
                      'keterangan': _keperluanController.text,
                    };

                    // Call API to update
                    final response = await _api.updateIzin(dataIzin, id);

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
                                  ? 'Data izin berhasil diperbarui'
                                  : 'Gagal memperbarui data izin'),
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
        onRefresh: () => _loadIzinData(),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with title and filter button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Surat Izin',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Row(
                    children: [
                      // Date filter button
                      IconButton(
                        icon: const Icon(Icons.filter_list),
                        onPressed: () {
                          _showDateFilterDialog(context);
                        },
                        tooltip: 'Filter by date',
                      ),
                      // Add button
                      IconButton(
                        icon: const Icon(Icons.add),
                        onPressed: () {
                          _showAddIzinForm(context);
                        },
                        tooltip: 'Add new izin',
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Date filter chips
              if (_startDate != null || _endDate != null)
                Wrap(
                  spacing: 8,
                  children: [
                    if (_startDate != null)
                      Chip(
                        label: Text(
                          'From: ${DateFormat('dd MMM yyyy').format(_startDate!)}',
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _startDate = null;
                            appController.tglAwalFilter.changeVal('');
                            _loadIzinData();
                          });
                        },
                      ),
                    if (_endDate != null)
                      Chip(
                        label: Text(
                          'To: ${DateFormat('dd MMM yyyy').format(_endDate!)}',
                        ),
                        deleteIcon: const Icon(Icons.close, size: 16),
                        onDeleted: () {
                          setState(() {
                            _endDate = null;
                            appController.tglAkhirFilter.changeVal('');
                            _loadIzinData();
                          });
                        },
                      ),
                  ],
                ),

              const SizedBox(height: 16),

              // Izin list
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : BlocBuilder(
                        bloc: appController.izinLMB,
                        builder: (context, state) {
                          if (appController.izinListMap.isEmpty) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_note,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Tidak ada data izin',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  const SizedBox(height: 8),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      _showAddIzinForm(context);
                                    },
                                    icon: const Icon(Icons.add),
                                    label: const Text('Tambah Izin'),
                                  ),
                                ],
                              ),
                            );
                          }

                          return ListView.builder(
                            itemCount: appController.izinListMap.length,
                            itemBuilder: (context, index) {
                              final izinData = appController.izinListMap[index];
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16.0),
                                child: IzinCard(
                                  izinData: izinData,
                                  onEdit: () {
                                    _showEditIzinForm(context, izinData);
                                  },
                                  onDelete: () async {
                                    // Show confirmation dialog
                                    bool confirm = await _showDeleteConfirmationDialog(
                                      context,
                                      'Hapus Izin',
                                      'Apakah Anda yakin ingin menghapus data izin ini?',
                                    );

                                    if (confirm) {
                                      try {
                                        // Show loading
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

                                        // Call API to delete
                                        final response = await _api.delIzin(
                                          izinData['id'].toString(),
                                        );

                                        // Close loading dialog
                                        Navigator.of(context).pop();

                                        // Show result
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              response['message'] ??
                                                  (response['status'] == true
                                                      ? 'Data izin berhasil dihapus'
                                                      : 'Gagal menghapus data izin'),
                                            ),
                                            backgroundColor: response['status'] == true
                                                ? Colors.green
                                                : Colors.red,
                                          ),
                                        );

                                        // Reload data if successful
                                        if (response['status'] == true) {
                                          _loadIzinData();
                                        }
                                      } catch (e) {
                                        // Close loading dialog if open
                                        Navigator.of(context).pop();

                                        // Show error
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Error: $e'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                    }
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
              Navigator.of(context).pop();
            },
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _loadIzinData(); // Reload with new filters
            },
            child: const Text('Apply'),
          ),
        ],
      ),
    );
  }

  // Show delete confirmation dialog
  Future<bool> _showDeleteConfirmationDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    bool result = false;
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                result = false;
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.of(context).pop();
                result = true;
              },
              child: const Text(
                'Hapus',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
    return result;
  }
}

// Card widget for displaying izin data
class IzinCard extends StatelessWidget {
  final Map<dynamic, dynamic> izinData;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const IzinCard({
    super.key,
    required this.izinData,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Extract data from izinData
    final String name = izinData['name'] ?? 'Staff';
    final String role = izinData['role'] ?? 'Employee';
    final String status = izinData['status'] ?? 'Pending';
    final String startDate = izinData['tanggalAwal'] ?? '-';
    final String endDate = izinData['tanggalAkhir'] ?? '-';
    final String duration = izinData['duration'] ?? '-';
    final String notes = izinData['keterangan'] ?? '-';

    // Format dates for display
    String formattedStartDate = startDate;
    String formattedEndDate = endDate;

    try {
      if (startDate != '-') {
        final DateTime parsedStartDate = DateTime.parse(startDate);
        formattedStartDate = DateFormat('dd MMM yyyy').format(parsedStartDate);
      }

      if (endDate != '-') {
        final DateTime parsedEndDate = DateTime.parse(endDate);
        formattedEndDate = DateFormat('dd MMM yyyy').format(parsedEndDate);
      }
    } catch (e) {
      print('Error formatting dates: $e');
    }

    // Determine status color
    Color statusColor = Colors.orange; // Default pending color
    if (status.contains('Approved')) {
      statusColor = Colors.green;
    } else if (status.contains('Rejected')) {
      statusColor = Colors.red;
    }

    // Create avatar label from name
    String avatarLabel = 'U';
    if (name.isNotEmpty) {
      avatarLabel = name[0].toUpperCase();
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
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Avatar
              CircleAvatar(
                backgroundColor: Colors.purple.withOpacity(0.2),
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
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              // Icon for izin
              Icon(
                Icons.event_note,
                color: Colors.purple,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 1,
                child: _infoColumn(context, 'Duration', duration),
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