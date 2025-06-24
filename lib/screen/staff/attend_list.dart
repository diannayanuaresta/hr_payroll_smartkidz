import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/controller/attend_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';
import 'package:hr_payroll_smartkidz/components/color_app.dart';

class AttendanceScreen extends StatefulWidget {
  const AttendanceScreen({super.key});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final Api _api = Api();
  bool _isLoading = false;
  DateTime? _startDate;
  DateTime? _endDate;
  
  @override
  void initState() {
    super.initState();
    _loadAttendanceData();
    
    // Listen for reload requests from other screens
    attendController.reloadAttendanceData.stream.listen((value) {
      if (value == 'true') {
        _loadAttendanceData();
        // Reset the flag
        attendController.reloadAttendanceData.changeVal('false');
      }
    });
  }
  
  Future<void> _loadAttendanceData() async {
    setState(() {
      _isLoading = true;
    });
    
    // Add a timeout to prevent UI from hanging indefinitely
    Future<void> loadDataWithTimeout() async {
      try {
        // Get date filter values from appController
        String startDateStr = appController.tglAwalFilter.state;
        String endDateStr = appController.tglAkhirFilter.state;
        
        // Update local date objects if filter values exist
        if (startDateStr.isNotEmpty) {
          _startDate = DateFormat('yyyy-MM-dd').parse(startDateStr);
        } else {
          _startDate = null;
        }
        
        if (endDateStr.isNotEmpty) {
          _endDate = DateFormat('yyyy-MM-dd').parse(endDateStr);
        } else {
          _endDate = null;
        }
        
        // Check if categories are loaded, if not, load them
        if (appController.categoryListMap.isEmpty) {
          final masterApi = MasterApi();
          final categoryResponse = await masterApi.category();
          
          if (categoryResponse['status'] == true && categoryResponse['data'] != null) {
            appController.categoryLMB.removeAll();
            appController.categoryLMB.addAll(categoryResponse['data']);
            appController.categoryListMap = List<Map>.from(categoryResponse['data']);
            print('Categories loaded from API: ${appController.categoryListMap}');
          } else {
            print('Failed to load categories: ${categoryResponse['message']}');
            // Use default categories if API fails
            appController.categoryListMap = [
              {'id': 1, 'name': 'Check In'},
              {'id': 2, 'name': 'Check Out'},
              {'id': 3, 'name': 'Cuti'}
            ];
          }
        }
        
        // Get the selected category
        final categories = appController.categoryListMap;
        
        final selectedIndex = attendController.currentIndexAttend.state;
        if (selectedIndex >= categories.length) {
          print('Error: Selected index $selectedIndex is out of bounds for categories length ${categories.length}');
          return;
        }
        
        final selectedCategory = categories[selectedIndex]['id'].toString();
        final selectedCategoryName = categories[selectedIndex]['name'];
        print('Loading attendance data for category: $selectedCategoryName (ID: $selectedCategory)');
        
        // Format dates for API request - tidak perlu lagi karena sudah diambil dari appController
        // String startDateStr = '';
        // String endDateStr = '';
        // 
        // if (_startDate != null) {
        //   startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
        // }
        // 
        // if (_endDate != null) {
        //   endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);
        // }
        
        print('Filtering with date range: $startDateStr to $endDateStr');
        
        // Tambahkan filter tambahan jika diperlukan
        Map<String, dynamic> additionalFilters = {};
        // Contoh: Jika ada filter tambahan dari UI
        // if (_selectedStatus != null) {
        //   additionalFilters['status'] = _selectedStatus;
        // }
        
        // Fetch attendance data based on the selected category, date range, and additional filters
        final response = await _api.getAbsensi(
          selectedCategory, 
          startDateStr, 
          endDateStr,
          additionalFilters: additionalFilters.isNotEmpty ? additionalFilters : null
        ).timeout(const Duration(seconds: 15), onTimeout: () {
          throw TimeoutException('Loading attendance data timed out. Please try again.');
        });
        
        print('API Response: $response');
        
        if (response['status'] == true && response['data'] != null) {
          // Process and enrich the data
          List<Map<String, dynamic>> enrichedData = [];
          
          for (var item in response['data']) {
            // Convert to Map<String, dynamic> if it's not already
            Map<String, dynamic> attendanceItem = Map<String, dynamic>.from(item);
            
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
          print('Failed to load attendance data: ${response['message'] ?? "Unknown error"}');
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
        print('Error loading attendance data: $e');
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
  
  // Date filter dialog has been moved to main_menu.dart
  
  @override
  Widget build(BuildContext context) {
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
    final avatarRadius = isTablet || isDesktop ? 28.0 : 20.0;

    // Wrap with Scaffold to provide Material context
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const SizedBox(height: 16),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            // In the _buildScaffold method, update the BlocBuilder section:
            child: BlocBuilder<BlocBase<dynamic>, dynamic>(
              bloc: attendController.currentIndexAttend,
              builder: (BuildContext context, dynamic state) {
                // Always use categories from appController, load if empty
                if (appController.categoryListMap.isEmpty) {
                // Show loading indicator while categories are being loaded
                return const Center(child: CircularProgressIndicator());
                }
                final categories = appController.categoryListMap;
                print('Categories in UI: $categories');
                
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      categories.length,
                      (index) => Padding(
                        padding: EdgeInsets.only(right: index < categories.length - 1 ? 10 : 0),
                        child: GestureDetector(
                          onTap: () {
                            attendController.changeIndexAttend(index);
                            // Memuat ulang data absensi saat kategori berubah
                            setState(() {
                              _loadAttendanceData();
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                            decoration: BoxDecoration(
                              color: attendController.currentIndexAttend.state == index
                                  ? const Color(0xFF3A7AFE)
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              categories[index]['name'] ?? 'Kategori',
                              style: TextStyle(
                                color: attendController.currentIndexAttend.state == index
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
              : RefreshIndicator(
                  onRefresh: () async {
                    await _loadAttendanceData();
                  },
                  child: appController.getAttendanceListMap.isEmpty
                    ? ListView(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        children: [
                          Container(
                            height: MediaQuery.of(context).size.height * 0.6,
                            alignment: Alignment.center,
                            child: Text('Tidak ada data absensi untuk kategori ini'),
                          ),
                        ],
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                        itemCount: appController.getAttendanceListMap.length,
                        itemBuilder: (context, index) {
                          final attendance = appController.getAttendanceListMap[index];
                          print('Rendering attendance item $index: $attendance');
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: AttendanceCard(
                              name: attendance['name'] ?? 'Unknown',
                              role: attendance['role'] ?? 'Staff',
                              date: attendance['date'] ?? '-',
                              inTime: attendance['check_in'] ?? '-',
                              outTime: attendance['check_out'] ?? '-',
                              status: attendance['status'] ?? 'Pending',
                              duration: attendance['duration'] ?? '-',
                              avatarLabel: (attendance['name'] ?? 'U').substring(0, 1),
                              avatarRadius: avatarRadius,
                              attendanceData: attendance, // Pass the full attendance data
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

class AttendanceCard extends StatelessWidget {
  final String name;
  final String role;
  final String date;
  final String inTime;
  final String outTime;
  final String status;
  final String duration;
  final String location;
  final String notes;
  final String categoryName;
  final String avatarLabel;
  final double avatarRadius;
  final Map<dynamic, dynamic> attendanceData; // Full attendance data

  const AttendanceCard({
    super.key,
    required this.name,
    required this.role,
    required this.date,
    required this.inTime,
    required this.outTime,
    required this.status,
    required this.duration,
    this.location = '-',
    this.notes = '-',
    this.categoryName = '-',
    this.avatarLabel = 'A',
    this.avatarRadius = 20.0,
    required this.attendanceData,
  });

  @override
  Widget build(BuildContext context) {
    // Extract additional data if available
    final String location = attendanceData['location'] ?? '-';
    final String notes = attendanceData['notes'] ?? '-';
    final String categoryName = attendanceData['category_name'] ?? '-';
    final String categoryId = attendanceData['category_id']?.toString() ?? '-';
    
    // Use attendanceTime for date display if available, otherwise use date field
    final String dateToFormat = attendanceData['attendanceTime'] ?? date;
    
    // Format date and time for better readability
    String formattedDate = _formatDate(dateToFormat);
    String formattedInTime = _formatTime(inTime);
    String formattedOutTime = _formatTime(outTime);
    
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
              _infoColumn(context, 'Category', categoryName),
              IconButton(
                icon: const Icon(Icons.delete, color: Colors.red),
                onPressed: () {
                  _showDeleteConfirmation(context);
                },
              ),
            ],
          ),
          // Status and duration rows removed as requested

          if (location != '-') ...[  // Only show if location is available
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, color: Theme.of(context).colorScheme.primary, size: 18),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
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
          // More Details section removed as requested

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
    final String id = attendanceData['id']?.toString() ?? '';
    
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot delete: Invalid attendance ID')),
      );
      return;
    }
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Attendance'),
        content: const Text('Are you sure you want to delete this attendance record?'),
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
          title: const Text('Deleting Attendance'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Please wait while we delete the attendance record...'),
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
          safeShowSnackBar('Attendance deleted successfully');
          
          // Trigger reload of attendance data
          attendController.reloadAttendanceData.changeVal('true');
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
    final String? photoBase64 = attendanceData['photo'];
    
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
