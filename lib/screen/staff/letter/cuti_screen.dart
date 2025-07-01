import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show BlocBuilder;
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/controller/letter_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';
import 'package:hr_payroll_smartkidz/components/color_app.dart';

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
  DateTime? _startDate;
  DateTime? _endDate;

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

  Future<void> _loadCutiData() async {
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
          'Filtering cuti with date range: $startDateStr to $endDateStr',
        );

        // Fetch cuti data with date filters
        // Add timeout to prevent hanging
        final response = await _api
            .getCuti(startDate: startDateStr, endDate: endDateStr)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'Loading cuti data timed out. Please try again.',
                );
              },
            );

        print('API Response: $response');

        if (response['status'] == true && response['data'] != null) {
          // Process and enrich the data
          List<Map<String, dynamic>> enrichedData = [];

          for (var item in response['data']) {
            // Convert to Map<String, dynamic> if it's not already
            Map<String, dynamic> cutiItem = Map<String, dynamic>.from(item);

            // Calculate duration from start and end date
            String calculatedDuration = '-';
            if (cutiItem['tanggalAwal'] != null &&
                cutiItem['tanggalAkhir'] != null) {
              try {
                final startDate = DateTime.parse(cutiItem['tanggalAwal']);
                final endDate = DateTime.parse(cutiItem['tanggalAkhir']);
                
                final difference = endDate.difference(startDate).inDays + 1;
                calculatedDuration = '$difference hari';
              } catch (e) {
                print('Error calculating duration: $e');
              }
            }
            cutiItem['duration'] = calculatedDuration;

            // Determine status based on supervisor and HRD approval
            String cutiStatus = 'Pending';
            if (cutiItem['statusSupervisor'] != null &&
                cutiItem['statusHrd'] != null) {
              if (cutiItem['statusSupervisor'] == true &&
                  cutiItem['statusHrd'] == true) {
                cutiStatus = 'Approved';
              } else if (cutiItem['statusSupervisor'] == false ||
                  cutiItem['statusHrd'] == false) {
                cutiStatus = 'Rejected';
              }
            } else if (cutiItem['statusSupervisor'] == true) {
              cutiStatus = 'Approved by Supervisor';
            } else if (cutiItem['statusSupervisor'] == false) {
              cutiStatus = 'Rejected by Supervisor';
            }
            cutiItem['status'] = cutiStatus;

            enrichedData.add(cutiItem);
          }

          // Store the cuti data in appController
          appController.cutiLMB.removeAll();
          appController.cutiLMB.addAll(enrichedData);
          appController.cutiListMap = enrichedData;

          print('Cuti data loaded: ${enrichedData.length} records');
          if (enrichedData.isNotEmpty) {
            print('Sample record: ${enrichedData.first}');
          }
        } else {
          // Handle error or empty response
          print(
            'Failed to load cuti data: ${response['message'] ?? "Unknown error"}',
          );
          appController.cutiLMB.removeAll();
          appController.cutiListMap = [];

          // Show error message if not empty response
          if (response['message'] != null) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text('${response['message']}')));
          }
        }
      } catch (e) {
        print('Error loading cuti data: $e');
        appController.cutiLMB.removeAll();
        appController.cutiListMap = [];

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
        return AlertDialog(
          title: const Text('Tambah Surat Cuti'),
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
                        return 'Pilih tanggal mulai cuti';
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
                        return 'Pilih tanggal selesai cuti';
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
                        return 'Masukkan keperluan cuti';
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
                                  ? 'Data cuti berhasil ditambahkan'
                                  : 'Gagal menambahkan data cuti'),
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
  }

  // Show form dialog for editing cuti
  Future<void> _showEditCutiForm(
    BuildContext context,
    Map<dynamic, dynamic> cutiData,
  ) async {
    // Set form values from existing data
    final String id = cutiData['id']?.toString() ?? '';
    _keperluanController.text = cutiData['keterangan'] ?? '';
    _startDateController.text = cutiData['tanggalAwal'] ?? '';
    _endDateController.text = cutiData['tanggalAkhir'] ?? '';

    // Form key for validation
    final formKey = GlobalKey<FormState>();

    // Show dialog
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Surat Cuti'),
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
                        return 'Pilih tanggal mulai cuti';
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
                        return 'Pilih tanggal selesai cuti';
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
                        return 'Masukkan keperluan cuti';
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
                    Map<String, String> dataCuti = {
                      'tanggalAwal': _startDateController.text,
                      'tanggalAkhir': _endDateController.text,
                      'keterangan': _keperluanController.text,
                    };

                    // Call API to update
                    final response = await _api.updateCuti(dataCuti, id);

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
                                  ? 'Data cuti berhasil diperbarui'
                                  : 'Gagal memperbarui data cuti'),
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
    final horizontalPadding = isTablet || isDesktop ? 32.0 : 16.0;
    final avatarRadius = isTablet || isDesktop ? 28.0 : 20.0;

    // Wrap with Scaffold to provide Material context
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Cuti'),
        backgroundColor: ColorApp.lightPrimary,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddCutiForm(context),
        backgroundColor: ColorApp.lightPrimary,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          BlocBuilder(
            bloc: appController.userAccess,
            buildWhen: (previous, current) {
              if (previous != current) {
                return true;
              } else {
                return false;
              }
            },
            builder: (context, state) {
              return Container(
                child:
                    appController.userAccess.state['jabatanNama'] == 'HR' ||
                        appController.userAccess.state['divisiNama'] == 'HR' ||
                        appController.userAccess.state['divisiNama'] ==
                            'Supervisor' ||
                        appController.userAccess.state['jabatanNama'] ==
                            'Supervisor'
                    ? ListTile(
                        title: Text('Manage Approval'),
                        trailing: const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 16,
                        ),
                        onTap: () {
                          if(appController.userAccess.state['divisiNama'] == 'HR'){
                            Navigator.pushNamed(context, '/approval-list');
                          }else if(appController.userAccess.state['divisiNama'] == 'Supervisor'){
                            Navigator.pushNamed(context, '/approval-list');
                          }else if(appController.userAccess.state['jabatanNama'] == 'HR'){
                            Navigator.pushNamed(context, '/approval-list');
                          }else if(appController.userAccess.state['jabatanNama'] == 'Supervisor'){
                            Navigator.pushNamed(context, '/approval-list');
                          }
                        },
                      )
                    : SizedBox(),
              );
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: () async {
                      await _loadCutiData();
                    },
                    child: appController.cutiListMap.isEmpty
                        ? ListView(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                            ),
                            children: [
                              Container(
                                height:
                                    MediaQuery.of(context).size.height * 0.6,
                                alignment: Alignment.center,
                                child: Text('Tidak ada data cuti'),
                              ),
                            ],
                          )
                        : ListView.builder(
                            padding: EdgeInsets.symmetric(
                              horizontal: horizontalPadding,
                            ),
                            itemCount:
                                appController.cutiListMap.length,
                            itemBuilder: (context, index) {
                              final cuti =
                                  appController.cutiListMap[index];
                              print(
                                'Rendering cuti item $index: $cuti',
                              );

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 16),
                                child: CutiCard(
                                  name: cuti['name'] ?? 'Staff',
                                  role: cuti['role'] ?? 'Employee',
                                  startDate: cuti['tanggalAwal'] ?? '-',
                                  endDate: cuti['tanggalAkhir'] ?? '-',
                                  status: cuti['status'] ?? 'Pending',
                                  duration: cuti['duration'] ?? '-',
                                  notes: cuti['keterangan'] ?? '-',
                                  avatarLabel: 'C', // Cuti label
                                  avatarRadius: avatarRadius,
                                  cutiData:
                                      cuti, // Pass the full cuti data
                                  onEdit: (data) => _showEditCutiForm(context, data),
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

class CutiCard extends StatelessWidget {
  final String name;
  final String role;
  final String startDate;
  final String endDate;
  final String status;
  final String duration;
  final String notes;
  final String avatarLabel;
  final double avatarRadius;
  final Map<dynamic, dynamic> cutiData; // Full cuti data
  final Function(Map<dynamic, dynamic>) onEdit;

  const CutiCard({
    super.key,
    required this.name,
    required this.role,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.duration,
    this.notes = '-',
    this.avatarLabel = 'C',
    this.avatarRadius = 20.0,
    required this.cutiData,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    // Format date for better readability
    String formattedStartDate = _formatDate(startDate);
    String formattedEndDate = _formatDate(endDate);

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
                    Text(
                      role,
                      style: TextStyle(
                        color: Theme.of(context).textTheme.bodySmall?.color,
                      ),
                    ),
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
              Expanded(
                flex: 1,
                child: _infoColumn(context, 'Duration', duration),
              ),
              // Vertical column of buttons
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  InkWell(
                    onTap: () {
                      _showEditConfirmation(context);
                    },
                    child: Padding(
                      padding: EdgeInsets.all(4.0),
                      child: Icon(Icons.edit, color: Colors.blue, size: 16),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      _showDeleteConfirmation(context);
                    },
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
          style: TextStyle(color: Theme.of(context).textTheme.bodySmall?.color),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 14,
            color: Theme.of(context).textTheme.bodyMedium?.color,
          ),
        ),
      ],
    );
  }

  void _showEditConfirmation(BuildContext context) {
    final String id = cutiData['id']?.toString() ?? '';

    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit: Invalid cuti ID')),
      );
      return;
    }

    // Call the onEdit callback to show the edit form
    onEdit(cutiData);
  }

  void _showDeleteConfirmation(BuildContext context) {
    final String id = cutiData['id']?.toString() ?? '';

    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: Invalid cuti ID')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Cuti'),
        content: const Text(
          'Are you sure you want to delete this cuti record?',
        ),
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
          title: const Text('Deleting Cuti'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Please wait while we delete the cuti record...'),
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
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
            } catch (e) {
        print('Error showing snackbar: $e');
      }
    }

    // Execute the delete operation
    Future.delayed(Duration.zero, () async {
      try {
        final response = await Api()
            .delCuti(id)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () => {
                'status': false,
                'message': 'Request timed out. Please try again.',
              },
            );

        // Close the dialog
        safeCloseDialog();

        if (response['status'] == true) {
          // Show success message
          safeShowSnackBar('Cuti deleted successfully');

          // Trigger reload of cuti data
          letterController.reloadLetterData.changeVal('true');
        } else {
          // Show error message
          safeShowSnackBar(
            'Failed to delete: ${response['message'] ?? "Unknown error"}',
          );
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
    final String? photoBase64 = cutiData['photo'];

    // Check for invalid or placeholder data
    if (photoBase64 == null ||
        photoBase64.isEmpty ||
        photoBase64 == '-' ||
        photoBase64 == 'xxxx' ||
        photoBase64.contains('data:image/png;base64,xxxx')) {
      return _buildDefaultAvatar();
    }

    try {
      // Extract the base64 part if it contains the data URI prefix
      String base64String = photoBase64;
      if (photoBase64.contains('base64,')) {
        base64String = photoBase64.split('base64,')[1];
      }

      // Check if the extracted string is valid
      if (base64String.isEmpty || base64String == 'xxxx') {
        return _buildDefaultAvatar();
      }

      // Decode base64 string to image
      final Uint8List bytes = base64Decode(base64String);
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
      child: const Icon(Icons.beach_access, color: Colors.orange),
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
            dateTime = DateTime(
              int.parse(parts[2]),
              int.parse(parts[1]),
              int.parse(parts[0]),
            );
          }
        } catch (e) {
          print('Error parsing date: $e');
        }
      }

      if (dateTime != null) {
        // Format the date in Indonesian format
        // Use 'EEEE' for full day name (Senin, Selasa, etc.)
        // Use 'd MMMM yyyy' for date format (12 Agustus 2025)
        return DateFormat(
          'd MMMM yyyy',
          'id_ID',
        ).format(dateTime);
      }
    } catch (e) {
      print('Error formatting date: $e');
    }
    
    return dateStr; // Return original string if parsing fails
  }
}