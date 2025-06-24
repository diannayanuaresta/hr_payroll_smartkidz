import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show BlocBuilder, BlocBase;
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/controller/letter_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';
import 'package:hr_payroll_smartkidz/components/color_app.dart';

class LetterScreen extends StatefulWidget {
  const LetterScreen({super.key});

  @override
  State<LetterScreen> createState() => _LetterScreenState();
}

class _LetterScreenState extends State<LetterScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final Api _api = Api();
  final MasterApi _masterApi = MasterApi();
  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;

  // Data untuk jenis surat
  List<Map<String, dynamic>> _letterTypeList = [
    {'id': 1, 'name': 'Surat Lembur'},
    {'id': 2, 'name': 'Surat Cuti'},
    {'id': 3, 'name': 'Surat Sakit'},
    {'id': 4, 'name': 'Surat Izin'},
  ];
  bool _isLoadingLetterTypes = false;

  // Form controllers
  final TextEditingController _keperluanController = TextEditingController();
  final TextEditingController _startDateController = TextEditingController();
  final TextEditingController _endDateController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String _selectedLetterType = '1'; // Default to first type

  @override
  void initState() {
    super.initState();
    _loadLetterCategories();
    _loadLetterData();
    
    // Listen for reload requests from other screens
    letterController.reloadLetterData.stream.listen((value) {
      if (value == 'true') {
        _loadLetterData();
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
    _descriptionController.dispose();
    super.dispose();
  }

  // Load letter categories
  Future<void> _loadLetterCategories() async {
    // If categories are already loaded, don't reload
    if (appController.letterCategoryListMap.isNotEmpty) {
      return;
    }

    setState(() {
      _isLoadingLetterTypes = true;
    });

    try {
      // In a real app, you would fetch categories from API
      // final categoryResponse = await _masterApi.letterCategories();
      
      // For now, we'll use the letter types as categories
      appController.letterCategoryLMB.removeAll();
      appController.letterCategoryLMB.addAll(_letterTypeList);
      appController.letterCategoryListMap = List<Map>.from(_letterTypeList);
      
      print('Letter categories loaded: ${appController.letterCategoryListMap}');
    } catch (e) {
      print('Error loading letter categories: $e');
      // Use default categories if API fails
      appController.letterCategoryListMap = _letterTypeList;
    } finally {
      setState(() {
        _isLoadingLetterTypes = false;
      });
    }
  }

  // Load letter data from API
  Future<void> _loadLetterData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get date filter values from appController
      String startDateStr = appController.tglAwalFilter.state;
      String endDateStr = appController.tglAkhirFilter.state;
      
      // Update local date objects if filter values exist
      if (startDateStr.isNotEmpty) {
        _startDate = DateFormat('yyyy-MM-dd').parse(startDateStr);
      } else if (_startDate != null) {
        startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      }
      
      if (endDateStr.isNotEmpty) {
        _endDate = DateFormat('yyyy-MM-dd').parse(endDateStr);
      } else if (_endDate != null) {
        endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
      }

      // Get the selected category
      final categories = appController.letterCategoryListMap;
      
      final selectedIndex = letterController.currentIndexLetter.state;
      if (selectedIndex >= categories.length) {
        print('Error: Selected index $selectedIndex is out of bounds for categories length ${categories.length}');
        return;
      }
      
      final selectedCategory = categories[selectedIndex]['id'].toString();
      final selectedCategoryName = categories[selectedIndex]['name'];
      print('Loading letter data for category: $selectedCategoryName (ID: $selectedCategory)');

      // Create data container for letters
      List<Map<String, dynamic>> letterData = [];
      
      // If Surat Lembur is selected, fetch real data from API
      if (selectedCategoryName == 'Surat Lembur') {
        try {
          // Fetch overtime data with date filters
          final response = await _api.getLembur(
            startDate: startDateStr,
            endDate: endDateStr
          ).timeout(
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
              Map<String, dynamic> overtimeItem = Map<String, dynamic>.from(item);
              
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
                  overtimeItem['statusHrd']
                ),
                'keperluan': overtimeItem['keperluan'] ?? '-',
                'category_id': selectedCategory,
                'category_name': selectedCategoryName,
                // Add additional fields from the API that might be useful
                'jamMulai': overtimeItem['jamMulai'],
                'jamSelesai': overtimeItem['jamSelesai'],
                'duration': calculatedDuration,
                'createdAt': overtimeItem['createdAt'],
                'jenisLembur': overtimeItem['jenisLembur'],
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
            SnackBar(content: Text('Error loading overtime data: $e'))
          );
          letterData = [];
        }
      } else {
        // For other categories, use mock data as before
        if (selectedCategoryName == 'Surat Cuti') {
          letterData = [
            {
              'id': 2,
              'name': 'Staff',
              'role': 'Employee',
              'letterType': 'Surat Cuti',
              'tanggal': '2024-12-14',
              'startDate': '2024-12-14',
              'endDate': '2024-12-16',
              'status': 'Approved',
              'keperluan': 'Cuti Tahunan',
              'category_id': selectedCategory,
              'category_name': selectedCategoryName,
            },
          ];
        } else if (selectedCategoryName == 'Surat Sakit') {
          letterData = [
            {
              'id': 3,
              'name': 'Staff',
              'role': 'Employee',
              'letterType': 'Surat Sakit',
              'tanggal': '2024-12-10',
              'startDate': '2024-12-10',
              'endDate': '2024-12-12',
              'status': 'Approved',
              'keperluan': 'Demam',
              'category_id': selectedCategory,
              'category_name': selectedCategoryName,
            },
          ];
        } else if (selectedCategoryName == 'Surat Izin') {
          letterData = [
            {
              'id': 4,
              'name': 'Staff',
              'role': 'Employee',
              'letterType': 'Surat Izin',
              'tanggal': '2024-12-05',
              'startDate': '2024-12-05',
              'endDate': '2024-12-05',
              'status': 'Rejected',
              'keperluan': 'Urusan Keluarga',
              'category_id': selectedCategory,
              'category_name': selectedCategoryName,
            },
          ];
        }
      }

      // Store the letter data in appController
      appController.getAttendanceLMB.removeAll();
      appController.getAttendanceLMB.addAll(letterData);
      appController.getAttendanceListMap = letterData;

    } catch (e) {
      print('Error loading letter data: $e');
      appController.getAttendanceLMB.removeAll();
      appController.getAttendanceListMap = [];
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e'))
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
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
  Future<void> _showAddLetterForm(BuildContext context) async {
    // Reset form values
    _keperluanController.clear();
    _startDateController.clear();
    _endDateController.clear();
    _descriptionController.clear();
    _selectedLetterType = '1';

    // Form key for validation
    final formKey = GlobalKey<FormState>();

    // Show dialog
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Tambah Surat'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Letter Type Dropdown
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Jenis Surat',
                      border: OutlineInputBorder(),
                    ),
                    value: _selectedLetterType,
                    items: _letterTypeList.map((item) {
                      return DropdownMenuItem<String>(
                        value: item['id'].toString(),
                        child: Text(item['name'] ?? 'Tidak ada nama'),
                      );
                    }).toList(),
                    onChanged: (value) {
                      if (value != null) {
                        _selectedLetterType = value;
                      }
                    },
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Pilih jenis surat';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

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
                        return 'Pilih tanggal mulai';
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
                        return 'Pilih tanggal selesai';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),

                  // Keperluan / Description
                  TextFormField(
                    controller: _keperluanController,
                    decoration: const InputDecoration(
                      labelText: 'Keperluan',
                      border: OutlineInputBorder(),
                      hintText: 'Masukkan keperluan surat',
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
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  // In a real app, you would submit the form data to an API
                  // For now, just close the dialog and refresh the list
                  Navigator.pop(context);
                  _loadLetterData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Surat berhasil ditambahkan')),
                  );
                }
              },
              child: const Text(
                'Simpan',
                style: TextStyle(color: Colors.white),
              ),
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
    
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Add category selection
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: BlocBuilder<BlocBase<dynamic>, dynamic>(
              bloc: letterController.currentIndexLetter,
              builder: (BuildContext context, dynamic state) {
                // Always use categories from appController, load if empty
                if (appController.letterCategoryListMap.isEmpty) {
                  // Show loading indicator while categories are being loaded
                  return const Center(child: CircularProgressIndicator());
                }
                final categories = appController.letterCategoryListMap;
                print('Letter categories in UI: $categories');
                
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      categories.length,
                      (index) => Padding(
                        padding: EdgeInsets.only(right: index < categories.length - 1 ? 10 : 0),
                        child: GestureDetector(
                          onTap: () {
                            letterController.changeIndexLetter(index);
                            // Reload letter data when category changes
                            setState(() {
                              _loadLetterData();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            decoration: BoxDecoration(
                              color: letterController.currentIndexLetter.state == index
                                  ? const Color(0xFF3A7AFE)
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              categories[index]['name'] ?? 'Kategori',
                              style: TextStyle(
                                color: letterController.currentIndexLetter.state == index
                                    ? Colors.white
                                    : Theme.of(context).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
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
        onPressed: () => _showAddLetterForm(context),
        child: Icon(
          Icons.add,
          color: Theme.of(context).colorScheme.onPrimary,
        ),
      ),
    );
  }

  Widget _buildLetterList(BuildContext context) {
    return BlocBuilder(
      bloc: appController.getAttendanceLMB,
      builder: (context, state) {
        if (appController.getAttendanceListMap.isEmpty) {
          return const Center(
            child: Text('Tidak ada data surat'),
          );
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
                    final letterData = appController.getAttendanceListMap[index];
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
      return dateStr; // Return original string if parsing fails
    }
  }

  // Calculate duration between two dates
  String _calculateDuration(String startDateStr, String endDateStr) {
    try {
      final DateTime startDate = DateTime.parse(startDateStr);
      final DateTime endDate = DateTime.parse(endDateStr);
      final difference = endDate.difference(startDate).inDays + 1; // Include both start and end days
      return '$difference hari';
    } catch (e) {
      return '0 hari'; // Return 0 if parsing fails
    }
  }

  // Build profile avatar
  Widget _buildProfileAvatar() {
    return CircleAvatar(
      radius: avatarRadius,
      backgroundColor: Colors.purple[200],
      child: Text(
        avatarLabel,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Show edit confirmation dialog
  void _showEditConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Surat'),
          content: const Text('Apakah Anda ingin mengedit surat ini?'),
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
              onPressed: () {
                Navigator.pop(context);
                // In a real app, you would show the edit form here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit surat')),
                );
              },
              child: const Text(
                'Edit',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  // Show delete confirmation dialog
  void _showDeleteConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Hapus Surat'),
          content: const Text('Apakah Anda yakin ingin menghapus surat ini?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              onPressed: () {
                Navigator.pop(context);
                // In a real app, you would delete the letter here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Surat dihapus')),
                );
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
  }

  @override
  Widget build(BuildContext context) {
    // Format dates for better readability
    String formattedDate = _formatDate(date);
    String formattedStartDate = _formatDate(startDate);
    String formattedEndDate = _formatDate(endDate);
    String duration = _calculateDuration(startDate, endDate);

    // Determine status color based on approval status
    Color statusColor = Colors.orange; // Default pending color
    if (status.contains('Approved')) {
      statusColor = Colors.green;
    } else if (status.contains('Rejected')) {
      statusColor = Colors.red;
    }

    // Determine letter type icon and color
    IconData letterIcon;
    Color letterIconColor;
    switch (letterType) {
      case 'Surat Lembur':
        letterIcon = Icons.access_time;
        letterIconColor = Colors.blue;
        break;
      case 'Surat Cuti':
        letterIcon = Icons.beach_access;
        letterIconColor = Colors.orange;
        break;
      case 'Surat Sakit':
        letterIcon = Icons.medical_services;
        letterIconColor = Colors.red;
        break;
      case 'Surat Izin':
        letterIcon = Icons.event_note;
        letterIconColor = Colors.purple;
        break;
      default:
        letterIcon = Icons.description;
        letterIconColor = Colors.grey;
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
              // Letter type icon
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: letterIconColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  letterIcon,
                  color: letterIconColor,
                  size: 20,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 2,
                child: _infoColumn(context, 'Date', formattedDate),
              ),
              Expanded(
                flex: 1,
                child: _infoColumn(context, 'Duration', duration),
              ),
              // Compact action buttons
              Container(
                width: 60,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    InkWell(
                      onTap: () {
                        _showEditConfirmation(context);
                      },
                      child: Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.edit, color: Colors.blue, size: 18),
                      ),
                    ),
                    InkWell(
                      onTap: () {
                        _showDeleteConfirmation(context);
                      },
                      child: Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(Icons.delete, color: Colors.red, size: 18),
                      ),
                    ),
                  ],
                ),
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
              Expanded(
                child: _infoColumn(context, 'Start Date', formattedStartDate),
              ),
              Expanded(
                child: _infoColumn(context, 'End Date', formattedEndDate),
              ),
            ],
          ),

          // Letter type
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                letterIcon,
                color: letterIconColor,
                size: 18,
              ),
              const SizedBox(width: 4),
              Text(
                letterType,
                style: TextStyle(
                  color: letterIconColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Notes section
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
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

  // Helper method to determine status based on supervisor and HRD approval
  String _determineStatus(dynamic supervisorStatus, dynamic hrdStatus) {
    if (supervisorStatus == 0 || supervisorStatus == null) {
      return 'Pending';
    } else if (supervisorStatus == 2 || (hrdStatus != null && hrdStatus == 2)) {
      return 'Rejected';
    } else if (supervisorStatus == 1 && (hrdStatus == null || hrdStatus == 0)) {
      return 'Approved by Supervisor';
    } else if (supervisorStatus == 1 && hrdStatus == 1) {
      return 'Approved';
    } else {
      return 'Pending';
    }
  }