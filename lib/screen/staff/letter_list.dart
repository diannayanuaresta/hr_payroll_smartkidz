import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show BlocBuilder, BlocBase;
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/controller/letter_controller.dart';
import 'package:hr_payroll_smartkidz/screen/hrd/LetterHRScreen.dart';
import 'package:hr_payroll_smartkidz/screen/supervisor/LetterSupervisorScreen.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img;

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
  bool _isLoading = false;

  // Data untuk jenis surat
  final List<Map<String, dynamic>> _letterTypeList = [
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
  String _selectedLetterType = '1';

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

      // Get the selected category
      final categories = appController.letterCategoryListMap;

      final selectedIndex = letterController.currentIndexLetter.state;
      if (selectedIndex >= categories.length) {
        print(
          'Error: Selected index $selectedIndex is out of bounds for categories length ${categories.length}',
        );
        return;
      }

      final selectedCategory = categories[selectedIndex]['id'].toString();
      final selectedCategoryName = categories[selectedIndex]['name'];
      print(
        'Loading letter data for category: $selectedCategoryName (ID: $selectedCategory)',
      );
      print('Using date range: $startDateStr to $endDateStr');

      // Create data container for letters
      List<Map<String, dynamic>> letterData = [];

      // Load data based on selected category
      if (selectedCategoryName == 'Surat Lembur') {
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
            final List<dynamic> overtimeData = response['data'];

            for (var overtimeItem in overtimeData) {
              // Calculate duration from start and end time
              String calculatedDuration = '-';
              if (overtimeItem['jamMulai'] != null &&
                  overtimeItem['jamSelesai'] != null) {
                try {
                  final startTime = _parseTimeString(overtimeItem['jamMulai']);
                  final endTime = _parseTimeString(overtimeItem['jamSelesai']);

                  if (startTime != null && endTime != null) {
                    // Calculate duration in minutes
                    int startMinutes = startTime.hour * 60 + startTime.minute;
                    int endMinutes = endTime.hour * 60 + endTime.minute;

                    // Handle overnight overtime
                    if (endMinutes < startMinutes) {
                      endMinutes += 24 * 60; // Add 24 hours
                    }

                    int durationMinutes = endMinutes - startMinutes;
                    int hours = durationMinutes ~/ 60;
                    int minutes = durationMinutes % 60;

                    calculatedDuration = '${hours}h ${minutes}m';
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
                'category_id': selectedCategory,
                'category_name': selectedCategoryName,
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
      } else {
        // For other categories, fetch from API or use mock data
        if (selectedCategoryName == 'Surat Cuti') {
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
                  'category_id': selectedCategory,
                  'category_name': selectedCategoryName,
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
        } else if (selectedCategoryName == 'Surat Sakit') {
          try {
            // Fetch Sakit data from API with date filters
            final response = await _api.getSakit(
              startDate: startDateStr,
              endDate: endDateStr,
            );

            if (response['status'] == true && response['data'] != null) {
              final List<dynamic> sakitData = response['data'];

              letterData = sakitData.map((item) {
                return {
                  'id': item['id'],
                  'name': item['pegawaiNama'] ?? 'Staff',
                  'role': item['pegawaiJabatan'] ?? 'Employee',
                  'letterType': 'Surat Sakit',
                  'tanggal': item['createdAt']?.toString().split(' ')[0] ?? '',
                  'startDate': item['tanggalAwal'] ?? '',
                  'endDate': item['tanggalAkhir'] ?? '',
                  'status': _getStatusText(
                    item['verifSupervisor'],
                    item['verifHrd'],
                  ),
                  'keperluan': item['keterangan'] ?? '',
                  'category_id': selectedCategory,
                  'category_name': selectedCategoryName,
                  'foto': item['foto'] ?? '',
                };
              }).toList();
            } else {
              // Handle error or empty response
              letterData = [];
            }
          } catch (e) {
            print('Error fetching sakit data: $e');
            // Jika terjadi error, gunakan array kosong
            letterData = [];
          }
        } else if (selectedCategoryName == 'Surat Izin') {
          try {
            // Fetch Izin data from API with date filters
            final response = await _api.getIzin(
              startDate: startDateStr,
              endDate: endDateStr,
            );

            if (response['status'] == true && response['data'] != null) {
              final List<dynamic> izinData = response['data'];

              letterData = izinData.map((item) {
                return {
                  'id': item['id'],
                  'name': item['pegawaiNama'] ?? 'Staff',
                  'role': item['pegawaiJabatan'] ?? 'Employee',
                  'letterType': 'Surat Izin',
                  'tanggal': item['createdAt']?.toString().split(' ')[0] ?? '',
                  'startDate': item['tanggalAwal'] ?? '',
                  'endDate': item['tanggalAkhir'] ?? '',
                  'status': _getStatusText(
                    item['verifSupervisor'],
                    item['verifHrd'],
                  ),
                  'keperluan': item['perihal'] ?? '',
                  'category_id': selectedCategory,
                  'category_name': selectedCategoryName,
                };
              }).toList();
            } else {
              // Handle error or empty response
              letterData = [];
            }
          } catch (e) {
            print('Error fetching izin data: $e');
            // Jika terjadi error, gunakan array kosong
            letterData = [];
          }
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

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading data: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Helper method to parse time string
  TimeOfDay? _parseTimeString(String timeString) {
    if (timeString.isEmpty) return null;

    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        return TimeOfDay(hour: hour, minute: minute);
      }
    } catch (e) {
      print('Error parsing time: $e');
    }

    return null;
  }
  
  // Fungsi untuk memproses gambar dengan kualitas lebih baik
  Future<String> _processImageWithBetterQuality(File imageFile) async {
    try {
      // Baca gambar sebagai bytes
      final List<int> imageBytes = await imageFile.readAsBytes();
      
      // Decode gambar untuk diproses
      final img.Image? originalImage = img.decodeImage(Uint8List.fromList(imageBytes));
      
      if (originalImage == null) {
        // Jika gagal decode, gunakan cara lama sebagai fallback
        return base64Encode(imageBytes);
      }
      
      // Resize gambar jika terlalu besar (preserving aspect ratio)
      img.Image resizedImage = originalImage;
      if (originalImage.width > 1200 || originalImage.height > 1200) {
        resizedImage = img.copyResize(
          originalImage,
          width: originalImage.width > originalImage.height ? 1200 : null,
          height: originalImage.height >= originalImage.width ? 1200 : null,
        );
      }
      
      // Encode sebagai PNG untuk dokumen (kualitas lebih baik untuk teks)
      // PNG tidak menggunakan kompresi lossy sehingga tidak akan mengubah warna
      final List<int> processedBytes = img.encodePng(resizedImage);
      
      // Konversi ke base64
      return base64Encode(processedBytes);
    } catch (e) {
      // Jika terjadi error, gunakan cara lama sebagai fallback
      final List<int> imageBytes = await imageFile.readAsBytes();
      return base64Encode(imageBytes);
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
          
          // Container untuk akses HR (hanya muncul jika user adalah HR)
          BlocBuilder<BlocBase<dynamic>, dynamic>(
            bloc: appController.userAccess,
            builder: (context, state) {
              // Cek apakah user memiliki akses HR
              final bool isHR = (state['divisiNama'] == 'HR' || state['jabatanNama'] == 'HR');
              // Cek apakah user adalah supervisor
              final bool isSupervisor = (state['jabatanNama'] == 'Supervisor' || state['jabatanNama'] == 'Manager');
              if (isHR) {
                // Jika user hanya memiliki akses HR
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LetterHRScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.blue[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.admin_panel_settings, color: Colors.blue[800]),
                          const SizedBox(width: 8),
                          Text(
                            'Akses Halaman HR',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else if (isSupervisor) {
                // Jika user hanya memiliki akses Supervisor
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: 8),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const LetterSupervisorScreen(),
                        ),
                      );
                    },
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                        color: Colors.green[100],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green[300]!),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.supervisor_account, color: Colors.green[800]),
                          const SizedBox(width: 8),
                          Text(
                            'Akses Halaman Supervisor',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              } else {
                return const SizedBox.shrink(); // Tidak menampilkan apa-apa jika bukan HR atau Supervisor
              }
            },
          ),
          
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
                        padding: EdgeInsets.only(
                          right: index < categories.length - 1 ? 10 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            letterController.changeIndexLetter(index);
                            _loadLetterData(); // Reload data when category changes
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  letterController.currentIndexLetter.state ==
                                      index
                                  ? const Color(0xFF3A7AFE)
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              categories[index]['name'] ?? 'Kategori',
                              style: TextStyle(
                                color:
                                    letterController.currentIndexLetter.state ==
                                        index
                                    ? Colors.white
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
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
          // Date filter row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                Expanded(
                  child: BlocBuilder<BlocBase<dynamic>, dynamic>(
                    bloc: appController.tglAwalFilter,
                    builder: (context, state) {
                      return GestureDetector(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              appController.tglAwalFilter.changeVal(
                                picked.toString(),
                              );
                              _loadLetterData();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                state.isEmpty
                                    ? 'Start Date'
                                    : DateFormat('dd MMM yyyy').format(
                                        DateFormat('yyyy-MM-dd').parse(state),
                                      ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BlocBuilder<BlocBase<dynamic>, dynamic>(
                    bloc: appController.tglAkhirFilter,
                    builder: (context, state) {
                      return GestureDetector(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              appController.tglAkhirFilter.changeVal(
                                picked.toString(),
                              );
                              _loadLetterData();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                state.isEmpty
                                    ? 'End Date'
                                    : DateFormat('dd MMM yyyy').format(
                                        DateFormat('yyyy-MM-dd').parse(state),
                                      ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Letter list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : BlocBuilder<BlocBase<dynamic>, dynamic>(
                    bloc: appController.getAttendanceLMB,
                    builder: (context, state) {
                      final letterData = appController.getAttendanceListMap;
                      if (letterData.isEmpty) {
                        return Center(
                          child: Text(
                            'Tidak ada data surat',
                            style: TextStyle(fontSize: 16),
                          ),
                        );
                      }

                      return ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 8,
                        ),
                        itemCount: letterData.length,
                        itemBuilder: (context, index) {
                          final letterItem = letterData[index];
                          return LetterCard(
                            letter: Map<String, dynamic>.from(letterItem),
                            onEdit: () => _showEditConfirmation(
                              context,
                              Map<String, dynamic>.from(letterItem),
                            ),
                            onDelete: () => _showDeleteConfirmation(
                              context,
                              Map<String, dynamic>.from(letterItem),
                            ),
                            onInfo: () => _showInfoDialog(
                              context,
                              Map<String, dynamic>.from(letterItem),
                            ),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddLetterForm(context),
        child: const Icon(Icons.add),
      ),
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

    // Tambahan untuk lembur
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();
    String selectedOvertimeType = '';
    List<Map<String, dynamic>> jenisLemburData = [];

    // Tambahan untuk surat sakit
    String base64Image = '';

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
                        items: _letterTypeList.map((type) {
                          return DropdownMenuItem<String>(
                            value: type['id'].toString(),
                            child: Text(type['name']),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            _selectedLetterType = value!;
                          });
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Pilih jenis surat';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      // Conditional form fields based on letter type
                      if (_selectedLetterType == '1') ...[
                        // Surat Lembur
                        // Jenis Lembur Dropdown
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Jenis Lembur',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedOvertimeType.isNotEmpty
                              ? selectedOvertimeType
                              : null,
                          items: jenisLemburData.map((type) {
                            return DropdownMenuItem<String>(
                              value: type['id'].toString(),
                              child: Text(type['name']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedOvertimeType = value!;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Pilih jenis lembur';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Tanggal Mulai
                        GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() {
                                _startDateController.text = picked.toString();
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: _startDateController,
                              decoration: const InputDecoration(
                                labelText: 'Tanggal Mulai',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Pilih tanggal mulai';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Jam Mulai
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

                        // Jam Selesai
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
                        // Keterangan
                        TextFormField(
                          controller: _keperluanController,
                          decoration: const InputDecoration(
                            labelText: 'Keterangan',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Keterangan wajib diisi';
                            }
                            return null;
                          },
                        ),
                      ] else if (_selectedLetterType == '2') ...[
                        // Surat Cuti
                        // Tanggal Mulai
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
                                _startDateController.text = picked.toString();
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

                        // Tanggal Selesai
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
                                _endDateController.text = picked.toString();
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

                        // Keterangan
                        TextFormField(
                          controller: _keperluanController,
                          decoration: const InputDecoration(
                            labelText: 'Keterangan',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Keterangan wajib diisi';
                            }
                            return null;
                          },
                        ),
                      ], // Image upload for Surat Sakit
                      if (_selectedLetterType == '3') ...[
                        // Surat Sakit
                        // Tanggal Mulai
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
                                _startDateController.text = picked.toString();
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

                        // Tanggal Selesai
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
                                _endDateController.text = picked.toString();
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

                        // Keterangan
                        TextFormField(
                          controller: _keperluanController,
                          decoration: const InputDecoration(
                            labelText: 'Keterangan',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Keterangan wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Upload Foto
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? pickedFile = await picker
                                    .pickImage(
                                      source: ImageSource.gallery,
                                      // Hapus parameter kompresi untuk mendapatkan gambar asli
                                    );

                                if (pickedFile != null) {
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
                                            Text('Memproses gambar...'),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                  
                                  try {
                                    // Proses gambar dengan kualitas lebih baik
                                    File imageFile = File(pickedFile.path);
                                    final processedBase64 = await _processImageWithBetterQuality(imageFile);
                                    
                                    // Tutup dialog loading
                                    Navigator.of(context).pop();
                                    
                                    setState(() {
                                      base64Image = processedBase64;
                                    });
                                    
                                    // Tampilkan pesan sukses
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Foto berhasil diupload'),
                                        backgroundColor: Colors.green,
                                      ),
                                    );
                                  } catch (e) {
                                    // Tutup dialog loading
                                    Navigator.of(context).pop();
                                    
                                    // Tampilkan pesan error
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Gagal memproses gambar: $e'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              child: const Text('Upload Foto Bukti'),
                            ),
                            if (base64Image.isNotEmpty) ...[
                              // Tampilkan indikator jika foto sudah diupload
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Foto bukti sudah diupload',
                                    style: TextStyle(color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ] else if (_selectedLetterType == '4') ...[
                        // Surat Izin
                        // Tanggal Mulai
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
                                _startDateController.text = picked.toString();
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

                        // Tanggal Selesai
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
                                _endDateController.text = picked.toString();
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

                        // Perihal
                        TextFormField(
                          controller: _keperluanController,
                          decoration: const InputDecoration(
                            labelText: 'Perihal',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Perihal wajib diisi';
                            }
                            return null;
                          },
                        ),
                      ],
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
                      // Show loading dialog
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
                        Map<String, dynamic> response = {};

                        // Jika jenis surat adalah Surat Lembur (id = 1)
                        if (_selectedLetterType == '1') {
                          // Prepare data for API
                          Map<String, String> dataLembur = {
                            'jenisLembur': selectedOvertimeType,
                            'jamMulai': startTimeController.text,
                            'jamSelesai': endTimeController.text,
                            'tanggal': _startDateController.text,
                            'keperluan': _keperluanController.text,
                          };

                          // Call API
                          response = await _api.addLembur(dataLembur);
                        }
                        // Jika jenis surat adalah Surat Cuti (id = 2)
                        else if (_selectedLetterType == '2') {
                          // Prepare data for API
                          Map<String, String> dataCuti = {
                            'tanggalAwal': _startDateController.text,
                            'tanggalAkhir': _endDateController.text,
                            'keterangan': _keperluanController.text,
                          };

                          // Call API
                          response = await _api.addCuti(dataCuti);
                        }
                        // Jika jenis surat adalah Surat Sakit (id = 3)
                        else if (_selectedLetterType == '3') {
                          // Prepare data for API
                          Map<String, String> dataSakit = {
                            'tanggalAwal': _startDateController.text,
                            'tanggalAkhir': _endDateController.text,
                            'keterangan': _keperluanController.text,
                            'foto':
                                base64Image, // Pastikan base64Image sudah diisi
                          };

                          // Call API
                          response = await _api.addSakit(dataSakit);
                        }
                        // Jika jenis surat adalah Surat Izin (id = 4)
                        else if (_selectedLetterType == '4') {
                          // Prepare data for API
                          Map<String, String> dataIzin = {
                            'tanggalAwal': _startDateController.text,
                            'tanggalAkhir': _endDateController.text,
                            'perihal': _keperluanController.text,
                          };

                          // Call API
                          response = await _api.addIzin(dataIzin);
                        }

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
                          _loadLetterData();
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

  // Show edit confirmation dialog
  void _showEditConfirmation(
    BuildContext context,
    Map<String, dynamic> letter,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi'),
          content: Text(
            'Apakah Anda ingin mengedit ${letter['letterType']} ini?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Show edit form with pre-filled data
                _showEditLetterForm(context, letter);
              },
              child: const Text('Edit'),
            ),
          ],
        );
      },
    );
  }

  // Show form dialog for editing letter
  Future<void> _showEditLetterForm(
    BuildContext context,
    Map<String, dynamic> letter,
  ) async {
    // Set form values from letter data
    final letterType = letter['letterType'];
    String letterTypeId = '1'; // Default to Surat Lembur

    // Determine letter type ID
    for (var type in _letterTypeList) {
      if (type['name'] == letterType) {
        letterTypeId = type['id'].toString();
        break;
      }
    }

    _selectedLetterType = letterTypeId;

    // Set common fields
    _keperluanController.text = letter['keperluan'] ?? '';

    // Convert dates to proper format if needed
    if (letter['startDate'] != null && letter['startDate'].isNotEmpty) {
      try {
        final startDate = DateTime.parse(letter['startDate']);
        _startDateController.text = startDate.toString();
      } catch (e) {
        _startDateController.text = letter['startDate'];
      }
    }

    if (letter['endDate'] != null && letter['endDate'].isNotEmpty) {
      try {
        final endDate = DateTime.parse(letter['endDate']);
        _endDateController.text = endDate.toString();
      } catch (e) {
        _endDateController.text = letter['endDate'];
      }
    }

    // Additional fields for specific letter types
    final startTimeController = TextEditingController();
    final endTimeController = TextEditingController();
    String selectedOvertimeType = '';
    List<Map<String, dynamic>> jenisLemburData = [];
    String base64Image = '';

    // Set specific fields based on letter type
    if (letterType == 'Surat Lembur') {
      // Set overtime specific fields
      startTimeController.text = letter['jamMulai'] ?? '';
      endTimeController.text = letter['jamSelesai'] ?? '';

      // Get overtime types if available
      if (appController.jenisLemburListMap.isNotEmpty) {
        jenisLemburData = List<Map<String, dynamic>>.from(
          appController.jenisLemburListMap,
        );
        // Try to find the matching overtime type
        if (letter['jenisLembur'] != null) {
          for (var type in jenisLemburData) {
            if (type['id'].toString() == letter['jenisLembur'].toString()) {
              selectedOvertimeType = type['id'].toString();
              break;
            }
          }
        }
        // Default to first type if not found
        if (selectedOvertimeType.isEmpty && jenisLemburData.isNotEmpty) {
          selectedOvertimeType = jenisLemburData[0]['id'].toString();
        }
      }
    } else if (letterType == 'Surat Sakit') {
      // For sick letter, get the image if available
      if (letter['foto'] != null && letter['foto'].isNotEmpty) {
        base64Image = letter['foto'];
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
              title: Text('Edit $letterType'),
              content: SingleChildScrollView(
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Letter Type Dropdown (disabled for editing)
                      DropdownButtonFormField<String>(
                        decoration: const InputDecoration(
                          labelText: 'Jenis Surat',
                          border: OutlineInputBorder(),
                        ),
                        value: _selectedLetterType,
                        items: _letterTypeList.map((type) {
                          return DropdownMenuItem<String>(
                            value: type['id'].toString(),
                            child: Text(type['name']),
                          );
                        }).toList(),
                        onChanged: null, // Disabled for editing
                      ),
                      const SizedBox(height: 16),

                      // Conditional form fields based on letter type
                      if (letterType == 'Surat Lembur') ...[
                        // Jenis Lembur Dropdown
                        DropdownButtonFormField<String>(
                          decoration: const InputDecoration(
                            labelText: 'Jenis Lembur',
                            border: OutlineInputBorder(),
                          ),
                          value: selectedOvertimeType.isNotEmpty
                              ? selectedOvertimeType
                              : null,
                          items: jenisLemburData.map((type) {
                            return DropdownMenuItem<String>(
                              value: type['id'].toString(),
                              child: Text(type['name']),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              selectedOvertimeType = value!;
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Pilih jenis lembur';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Tanggal Mulai
                        GestureDetector(
                          onTap: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _startDateController.text.isNotEmpty
                                  ? DateTime.parse(_startDateController.text)
                                  : DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() {
                                _startDateController.text = picked.toString();
                              });
                            }
                          },
                          child: AbsorbPointer(
                            child: TextFormField(
                              controller: _startDateController,
                              decoration: const InputDecoration(
                                labelText: 'Tanggal Mulai',
                                border: OutlineInputBorder(),
                                suffixIcon: Icon(Icons.calendar_today),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Pilih tanggal mulai';
                                }
                                return null;
                              },
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Jam Mulai
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
                              initialTime: startTimeController.text.isNotEmpty
                                  ? _parseTimeString(
                                          startTimeController.text,
                                        ) ??
                                        TimeOfDay.now()
                                  : TimeOfDay.now(),
                            );
                            if (picked != null) {
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

                        // Jam Selesai
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
                              initialTime: endTimeController.text.isNotEmpty
                                  ? _parseTimeString(endTimeController.text) ??
                                        TimeOfDay.now()
                                  : TimeOfDay.now(),
                            );
                            if (picked != null) {
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
                        // Keterangan
                        TextFormField(
                          controller: _keperluanController,
                          decoration: const InputDecoration(
                            labelText: 'Keterangan',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Keterangan wajib diisi';
                            }
                            return null;
                          },
                        ),
                      ] else if (letterType == 'Surat Cuti') ...[
                        // Tanggal Mulai
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
                              initialDate: _startDateController.text.isNotEmpty
                                  ? DateTime.parse(_startDateController.text)
                                  : DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() {
                                _startDateController.text = picked.toString();
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

                        // Tanggal Selesai
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
                              initialDate: _endDateController.text.isNotEmpty
                                  ? DateTime.parse(_endDateController.text)
                                  : DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() {
                                _endDateController.text = picked.toString();
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

                        // Keterangan
                        TextFormField(
                          controller: _keperluanController,
                          decoration: const InputDecoration(
                            labelText: 'Keterangan',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Keterangan wajib diisi';
                            }
                            return null;
                          },
                        ),
                      ] else if (letterType == 'Surat Sakit') ...[
                        // Tanggal Mulai
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
                              initialDate: _startDateController.text.isNotEmpty
                                  ? DateTime.parse(_startDateController.text)
                                  : DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() {
                                _startDateController.text = picked.toString();
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

                        // Tanggal Selesai
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
                              initialDate: _endDateController.text.isNotEmpty
                                  ? DateTime.parse(_endDateController.text)
                                  : DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() {
                                _endDateController.text = picked.toString();
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

                        // Keterangan
                        TextFormField(
                          controller: _keperluanController,
                          decoration: const InputDecoration(
                            labelText: 'Keterangan',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Keterangan wajib diisi';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Upload Foto
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ElevatedButton(
                              onPressed: () async {
                                final ImagePicker picker = ImagePicker();
                                final XFile? pickedFile = await picker
                                    .pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 800,
                                      maxHeight: 800,
                                      imageQuality: 80,
                                    );

                                if (pickedFile != null) {
                                  // Konversi gambar ke base64 dengan kualitas lebih baik
                                  File imageFile = File(pickedFile.path);
                                  base64Image = await _processImageWithBetterQuality(imageFile);
                                  setState(() {});

                                  // Tampilkan pesan sukses
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Foto berhasil diupload'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              },
                              child: const Text('Upload Foto Bukti'),
                            ),
                            if (base64Image.isNotEmpty) ...[
                              // Tampilkan indikator jika foto sudah diupload
                              const SizedBox(height: 8),
                              const Row(
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 16,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Foto bukti sudah diupload',
                                    style: TextStyle(color: Colors.green),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ] else if (letterType == 'Surat Izin') ...[
                        // Tanggal Mulai
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
                              initialDate: _startDateController.text.isNotEmpty
                                  ? DateTime.parse(_startDateController.text)
                                  : DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() {
                                _startDateController.text = picked.toString();
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

                        // Tanggal Selesai
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
                              initialDate: _endDateController.text.isNotEmpty
                                  ? DateTime.parse(_endDateController.text)
                                  : DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (picked != null) {
                              setState(() {
                                _endDateController.text = picked.toString();
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

                        // Perihal
                        TextFormField(
                          controller: _keperluanController,
                          decoration: const InputDecoration(
                            labelText: 'Perihal',
                            border: OutlineInputBorder(),
                          ),
                          maxLines: 3,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Perihal wajib diisi';
                            }
                            return null;
                          },
                        ),
                      ],
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
                      // Show loading dialog
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
                        Map<String, dynamic> response = {};
                        final String id = letter['id'].toString();

                        // Call appropriate update API based on letter type
                        if (letterType == 'Surat Lembur') {
                          // Prepare data for API
                          Map<String, String> dataLembur = {
                            'jenisLembur': selectedOvertimeType,
                            'jamMulai': startTimeController.text,
                            'jamSelesai': endTimeController.text,
                            'tanggal': _startDateController.text,
                            'keperluan': _keperluanController.text,
                          };

                          // Call API
                          response = await _api.updateLembur(dataLembur, id);
                        }
                        // Jika jenis surat adalah Surat Cuti (id = 2)
                        else if (letterType == 'Surat Cuti') {
                          // Prepare data for API
                          Map<String, String> dataCuti = {
                            'tanggalAwal': _startDateController.text,
                            'tanggalAkhir': _endDateController.text,
                            'keterangan': _keperluanController.text,
                          };

                          // Call API
                          response = await _api.updateCuti(dataCuti, id);
                        }
                        // Jika jenis surat adalah Surat Sakit (id = 3)
                        else if (letterType == 'Surat Sakit') {
                          // Prepare data for API
                          Map<String, String> dataSakit = {
                            'tanggalAwal': _startDateController.text,
                            'tanggalAkhir': _endDateController.text,
                            'keterangan': _keperluanController.text,
                          };

                          // Only include foto if it was updated
                          if (base64Image.isNotEmpty) {
                            dataSakit['foto'] = base64Image;
                          }

                          // Call API
                          response = await _api.updateSakit(dataSakit, id);
                        }
                        // Jika jenis surat adalah Surat Izin (id = 4)
                        else if (letterType == 'Surat Izin') {
                          // Prepare data for API
                          Map<String, String> dataIzin = {
                            'tanggalAwal': _startDateController.text,
                            'tanggalAkhir': _endDateController.text,
                            'perihal': _keperluanController.text,
                          };

                          // Call API
                          response = await _api.updateIzin(dataIzin, id);
                        }

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
                                      ? 'Data berhasil diperbarui'
                                      : 'Gagal memperbarui data'),
                            ),
                            backgroundColor: response['status'] == true
                                ? Colors.green
                                : Colors.red,
                          ),
                        );

                        // Reload data if successful
                        if (response['status'] == true) {
                          _loadLetterData();
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

  // Show delete confirmation dialog
  void _showDeleteConfirmation(
    BuildContext context,
    Map<String, dynamic> letter,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Konfirmasi'),
          content: Text(
            'Apakah Anda yakin ingin menghapus ${letter['letterType']} ini?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Batal'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.of(context).pop();
                _performDelete(letter);
              },
              child: const Text('Hapus'),
            ),
          ],
        );
      },
    );
  }

  // Show info dialog with letter details
  void _showInfoDialog(BuildContext context, Map<String, dynamic> letter) {
    final letterType = letter['letterType'];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Detail $letterType'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Common information for all letter types
                _buildInfoRow('Nama', letter['name'] ?? '-'),
                _buildInfoRow('Jabatan', letter['role'] ?? '-'),
                _buildInfoRow(
                  'Tanggal Pengajuan',
                  DateFormat('dd MMM yyyy').format(
                    DateTime.parse(
                      letter['tanggal'] ?? DateTime.now().toString(),
                    ),
                  ),
                ),
                _buildInfoRow('Status', letter['status'] ?? '-'),

                const Divider(height: 24),

                // Letter type specific information
                if (letterType == 'Surat Lembur') ...[
                  _buildInfoRow('Jenis Lembur', letter['category_name'] ?? '-'),
                  _buildInfoRow(
                    'Tanggal',
                    DateFormat('dd MMM yyyy').format(
                      DateTime.parse(
                        letter['startDate'] ?? DateTime.now().toString(),
                      ),
                    ),
                  ),
                  _buildInfoRow('Jam Mulai', letter['jamMulai'] ?? '-'),
                  _buildInfoRow('Jam Selesai', letter['jamSelesai'] ?? '-'),
                  _buildInfoRow('Durasi', letter['duration'] ?? '-'),
                ] else if (letterType == 'Surat Cuti' ||
                    letterType == 'Surat Sakit' ||
                    letterType == 'Surat Izin') ...[
                  _buildInfoRow(
                    'Tanggal Mulai',
                    DateFormat('dd MMM yyyy').format(
                      DateTime.parse(
                        letter['startDate'] ?? DateTime.now().toString(),
                      ),
                    ),
                  ),
                  _buildInfoRow(
                    'Tanggal Selesai',
                    DateFormat('dd MMM yyyy').format(
                      DateTime.parse(
                        letter['endDate'] ?? DateTime.now().toString(),
                      ),
                    ),
                  ),
                ],

                _buildInfoRow(
                  letterType == 'Surat Izin' ? 'Perihal' : 'Keterangan',
                  letter['keperluan'] ?? '-',
                ),

                // Show approval status
                const Divider(height: 24),
                _buildInfoRow(
                  'Status Supervisor',
                  _getSupervisorStatusText(letter['statusSupervisor']),
                ),
                _buildInfoRow(
                  'Status HRD',
                  _getHrdStatusText(letter['statusHrd']),
                ),

                // Show image for Surat Sakit if available
                if (letterType == 'Surat Sakit' &&
                    letter['foto'] != null &&
                    letter['foto'].isNotEmpty) ...[
                  const Divider(height: 24),
                  const Text(
                    'Bukti Sakit:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      base64Decode(letter['foto']),
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          height: 200,
                          color: Colors.grey[300],
                          child: const Center(
                            child: Text('Tidak dapat menampilkan gambar'),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Tutup'),
            ),
          ],
        );
      },
    );
  }

  // Helper method to build info row
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  // Helper method to get supervisor status text
  String _getSupervisorStatusText(dynamic status) {
    // Konversi nilai ke integer jika string
    final statusInt = status is String ? int.tryParse(status) ?? 0 : status ?? 0;
    
    if (statusInt == 2) {
      return 'Disetujui by Supervisor';
    } else if (statusInt == 3) {
      return 'Ditolak by Supervisor';
    } else {
      return 'Menunggu by Supervisor';
    }
  }

  // Helper method to get HRD status text
  String _getHrdStatusText(dynamic status) {
    // Konversi nilai ke integer jika string
    final statusInt = status is String ? int.tryParse(status) ?? 0 : status ?? 0;
    
    if (statusInt == 2) {
      return 'Disetujui by HRD';
    } else if (statusInt == 3) {
      return 'Ditolak by HRD';
    } else {
      return 'Menunggu by HRD';
    }
  }

  // Perform delete operation
  Future<void> _performDelete(Map<String, dynamic> letter) async {
    // Show loading dialog
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
      Map<String, dynamic> response = {};
      final String id = letter['id'].toString();
      final String letterType = letter['letterType'];

      // Call appropriate API based on letter type
      if (letterType == 'Surat Lembur') {
        response = await _api.delLembur(id);
      } else if (letterType == 'Surat Cuti') {
        response = await _api.delCuti(id);
      } else if (letterType == 'Surat Sakit') {
        response = await _api.delSakit(id);
      } else if (letterType == 'Surat Izin') {
        response = await _api.delIzin(id);
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success or error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            response['message'] ??
                (response['status'] == true
                    ? 'Data berhasil dihapus'
                    : 'Gagal menghapus data'),
          ),
          backgroundColor: response['status'] == true
              ? Colors.green
              : Colors.red,
        ),
      );

      // Reload data if successful
      if (response['status'] == true) {
        _loadLetterData();
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}

// Letter Card Widget
class LetterCard extends StatelessWidget {
  final Map<String, dynamic> letter;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onInfo;

  const LetterCard({
    super.key,
    required this.letter,
    required this.onEdit,
    required this.onDelete,
    required this.onInfo,
  });

  @override
  Widget build(BuildContext context) {
    // Determine status color
    Color statusColor = Colors.orange; // Default: Pending
    if (letter['status'] == 'Approved') {
      statusColor = Colors.green;
    } else if (letter['status'] == 'Rejected') {
      statusColor = Colors.red;
    }

    // Determine icon and color based on letter type
    IconData letterIcon;
    Color letterColor;

    switch (letter['letterType']) {
      case 'Surat Lembur':
        letterIcon = Icons.access_time;
        letterColor = Colors.orange;
        break;
      case 'Surat Cuti':
        letterIcon = Icons.beach_access;
        letterColor = Colors.blue;
        break;
      case 'Surat Sakit':
        letterIcon = Icons.healing;
        letterColor = Colors.red;
        break;
      case 'Surat Izin':
        letterIcon = Icons.event_note;
        letterColor = Colors.purple;
        break;
      default:
        letterIcon = Icons.description;
        letterColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: letterColor.withOpacity(0.2),
                  child: Icon(letterIcon, color: letterColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        letter['name'] ?? 'Staff',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        letter['role'] ?? 'Employee',
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20),
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, size: 20),
                      onPressed: onDelete,
                    ),
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 20),
                      onPressed: onInfo,
                    ),
                  ],
                ),
              ],
            ),
            const Divider(height: 24),
            
            // Tambahkan tampilan tanggal lembur untuk Surat Lembur
            if (letter['letterType'] == 'Surat Lembur') ...[              
              Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: Row(
                  children: [
                    Text(
                      'Tanggal Lembur:',
                      style: TextStyle(color: Colors.grey[600], fontSize: 14),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDate(letter['tanggal'] ?? '-'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            
            Row(
              children: [
                Expanded(
                  child: _infoColumn(
                    context,
                    letter['letterType'] == 'Surat Lembur'
                        ? 'Start Time'
                        : 'Start',
                    letter['letterType'] == 'Surat Lembur'
                        ? letter['jamMulai'] ?? '-'
                        : _formatDate(letter['startDate']),
                  ),
                ),
                Expanded(
                  child: _infoColumn(
                    context,
                    letter['letterType'] == 'Surat Lembur' ? 'End Time' : 'End',
                    letter['letterType'] == 'Surat Lembur'
                        ? letter['jamSelesai'] ?? '-'
                        : _formatDate(letter['endDate']),
                  ),
                ),
                if (letter['letterType'] == 'Surat Lembur') ...[
                  // Only for overtime
                  Expanded(
                    child: _infoColumn(
                      context,
                      'Duration',
                      letter['duration'] ?? '-',
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            // Show approval badges for all letter types
            Row(
              children: [
                _getSupervisorBadge(letter['statusSupervisor']),
                const SizedBox(width: 8),
                _getHrdBadge(letter['statusHrd']),
              ],
            ),
            const SizedBox(height: 16),
            // Notes section
            Text(
              'Notes',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              letter['keperluan'] ?? '-',
              style: const TextStyle(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method for info columns
  Widget _infoColumn(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 14)),
      ],
    );
  }

  // Helper method to format date
  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '-';
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }

  // Helper method to get supervisor badge
  Widget _getSupervisorBadge(dynamic status) {
    Color badgeColor;
    String badgeText;

    // Konversi nilai ke integer jika string
    final statusInt = status is String ? int.tryParse(status) ?? 0 : status ?? 0;

    if (statusInt == 2) {
      badgeColor = Colors.green;
      badgeText = 'Disetujui by Supervisor';
    } else if (statusInt == 3) {
      badgeColor = Colors.red;
      badgeText = 'Ditolak by Supervisor';
    } else {
      // Untuk status null, 0, atau 1
      badgeColor = Colors.orange;
      badgeText = 'Pending by Supervisor';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  // Helper method to get HRD badge
  Widget _getHrdBadge(dynamic status) {
    Color badgeColor;
    String badgeText;

    // Konversi nilai ke integer jika string
    final statusInt = status is String ? int.tryParse(status) ?? 0 : status ?? 0;

    if (statusInt == 2) {
      badgeColor = Colors.green;
      badgeText = 'Disetujui by HRD';
    } else if (statusInt == 3) {
      badgeColor = Colors.red;
      badgeText = 'Ditolak by HRD';
    } else {
      // Untuk status null, 0, atau 1
      badgeColor = Colors.orange;
      badgeText = 'Pending by HRD';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        badgeText,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

// Helper method to determine status based on supervisor and HRD approval
String _determineStatus(dynamic supervisorStatus, dynamic hrdStatus) {
  // Konversi nilai ke integer jika string
  final supStatus = supervisorStatus is String ? int.tryParse(supervisorStatus) ?? 0 : supervisorStatus ?? 0;
  final hrdStat = hrdStatus is String ? int.tryParse(hrdStatus) ?? 0 : hrdStatus ?? 0;
  
  if (supStatus == 0 || supStatus == 1) {
    return 'Pending';
  } else if (supStatus == 3) {
    return 'Ditolak';
  } else if (supStatus == 2) {
    if (hrdStat == 0 || hrdStat == 1) {
      return 'Pending';
    } else if (hrdStat == 3) {
      return 'Ditolak';
    } else if (hrdStat == 2) {
      return 'Disetujui';
    }
  }
  return 'Pending';
}

// Helper method to get letter type name
String _getLetterTypeName(String typeId) {
  final letterType = appController.letterCategoryListMap.firstWhere(
    (type) => type['id'].toString() == typeId,
    orElse: () => {'name': 'Surat'},
  );
  return letterType['name'] ?? 'Surat';
}

// Helper function to determine status text based on verification values
String _getStatusText(dynamic verifSupervisor, dynamic verifHrd) {
  // Jika salah satu bernilai 0, berarti ditolak
  if (verifSupervisor == 0 || verifHrd == 0) {
    return 'Rejected';
  }
  // Jika keduanya bernilai 1, berarti disetujui
  else if (verifSupervisor == 1 && verifHrd == 1) {
    return 'Approved';
  }
  // Jika tidak, masih dalam proses
  else {
    return 'Pending';
  }
}
