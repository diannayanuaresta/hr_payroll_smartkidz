import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/count_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/custom_bloc.dart';
import 'package:hr_payroll_smartkidz/components/color_app.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/controller/attend_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';

class AttendanceScreen extends StatelessWidget {
  const AttendanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize data loading when the screen is first built
    // This will only run once when the widget is inserted into the tree
    WidgetsBinding.instance.addPostFrameCallback((_) {
      attendController.loadAttendanceData();

      // Listen for reload requests from other screens
      attendController.reloadAttendanceData.stream.listen((value) {
        if (value == 'true') {
          attendController.loadAttendanceData();
          // Reset the flag
          attendController.reloadAttendanceData.changeVal('false');
        }
      });
    });

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
          // Category selector
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: BlocBuilder<CountBloc, int>(
              bloc: attendController.currentIndexAttend,
              builder: (BuildContext context, int selectedIndex) {
                // Check if categories are loaded
                if (appController.categoryListMap.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                final categories = appController.categoryListMap;

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
                            attendController.currentIndexAttend.changeVal(
                              index,
                            );
                            // Reload attendance data when category changes
                            attendController.loadAttendanceData();
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color: selectedIndex == index
                                  ? const Color(0xFF3A7AFE)
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              categories[index]['name'] ?? 'Kategori',
                              style: TextStyle(
                                color: selectedIndex == index
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

          // Add date filter display with BLoC builder
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                Expanded(
                  child: BlocBuilder<CustomBloc, String>(
                    bloc: attendController.startDateFilter,
                    builder: (context, startDateState) {
                      return BlocBuilder<CustomBloc, String>(
                        bloc: attendController.endDateFilter,
                        builder: (context, endDateState) {
                          String startDate = startDateState;
                          String endDate = endDateState;

                          if (startDate.isEmpty && endDate.isEmpty) {
                            return const SizedBox.shrink(); // No filter applied
                          }

                          // Format dates for display
                          String displayText = 'Filter: ';
                          if (startDate.isNotEmpty) {
                            displayText += DateFormat(
                              'dd/MM/yyyy',
                            ).format(DateFormat('yyyy-MM-dd').parse(startDate));
                          }

                          if (endDate.isNotEmpty) {
                            displayText +=
                                ' - ${DateFormat('dd/MM/yyyy').format(DateFormat('yyyy-MM-dd').parse(endDate))}';
                          }

                          return Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 8,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(displayText),
                                const SizedBox(width: 8),
                                InkWell(
                                  onTap: () {
                                    // Clear filters
                                    attendController.clearDateFilters();
                                    appController.tglAwalFilter.changeVal('');
                                    appController.tglAkhirFilter.changeVal('');
                                    attendController.loadAttendanceData();
                                  },
                                  child: const Icon(Icons.close, size: 16),
                                ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_alt),
                  onPressed: () => _showDateFilterDialog(context),
                ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Existing list view code with BlocBuilder for loading state
          Expanded(
            child: BlocBuilder<CountBloc, int>(
              bloc: attendController.isLoading,
              builder: (context, isLoading) {
                return isLoading == 1
                    ? const Center(child: CircularProgressIndicator())
                    : RefreshIndicator(
                        onRefresh: () async {
                          attendController.loadAttendanceData();
                        },
                        child: BlocBuilder<BlocBase<dynamic>, dynamic>(
                          bloc: appController.getAttendanceLMB,
                          builder: (context, _) {
                            return appController.getAttendanceListMap.isEmpty
                                ? ListView(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: horizontalPadding,
                                    ),
                                    children: [
                                      Container(
                                        height:
                                            MediaQuery.of(context).size.height *
                                            0.6,
                                        alignment: Alignment.center,
                                        child: Text(
                                          'Tidak ada data absensi untuk kategori ini',
                                        ),
                                      ),
                                    ],
                                  )
                                : ListView.builder(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: horizontalPadding,
                                    ),
                                    itemCount: appController
                                        .getAttendanceListMap
                                        .length,
                                    itemBuilder: (context, index) {
                                      final attendance = appController
                                          .getAttendanceListMap[index];
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16,
                                        ),
                                        child: AttendanceCard(
                                          name: attendance['name'] ?? 'Unknown',
                                          role: attendance['role'] ?? 'Staff',
                                          date: attendance['date'] ?? '-',
                                          inTime: attendance['check_in'] ?? '-',
                                          outTime:
                                              attendance['check_out'] ?? '-',
                                          status:
                                              attendance['status'] ?? 'Pending',
                                          duration:
                                              attendance['duration'] ?? '-',
                                          avatarLabel:
                                              (attendance['name'] ?? 'U')
                                                  .substring(0, 1),
                                          avatarRadius: avatarRadius,
                                          attendanceData: attendance,
                                        ),
                                      );
                                    },
                                  );
                          },
                        ),
                      );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Extract date filter dialog to a separate method
  void _showDateFilterDialog(BuildContext context) {
    // Inisialisasi variabel lokal untuk menyimpan state sementara
    DateTime? tempStartDate;
    DateTime? tempEndDate;
    
    // Ambil nilai dari state BLoC jika ada
    if (attendController.startDateFilter.state.isNotEmpty) {
      tempStartDate = DateFormat('yyyy-MM-dd').parse(attendController.startDateFilter.state);
    }
    
    if (attendController.endDateFilter.state.isNotEmpty) {
      tempEndDate = DateFormat('yyyy-MM-dd').parse(attendController.endDateFilter.state);
    }
    
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Filter by Date Range'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Start Date
                  ListTile(
                    title: const Text('Start Date'),
                    subtitle: Text(
                      tempStartDate == null
                          ? 'Not set'
                          : DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(tempStartDate!),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: tempStartDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        // Add these theme properties
                        builder: (context, child) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Theme(
                            data: Theme.of(context).copyWith(
                              datePickerTheme: DatePickerThemeData(
                                confirmButtonStyle: ButtonStyle(
                                  foregroundColor: MaterialStateProperty.all<Color>(
                                    isDark ? ColorApp.darkTertiary : ColorApp.lightPrimary,
                                  ),
                                ),
                                cancelButtonStyle: ButtonStyle(
                                  foregroundColor: MaterialStateProperty.all<Color>(
                                    isDark ? ColorApp.darkTertiary : ColorApp.lightPrimary,
                                  ),
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          tempStartDate = picked;
                        });
                      }
                    },
                  ),
                  
                  // End Date
                  ListTile(
                    title: const Text('End Date'),
                    subtitle: Text(
                      tempEndDate == null
                          ? 'Not set'
                          : DateFormat('EEEE, d MMMM yyyy', 'id_ID').format(tempEndDate!),
                    ),
                    trailing: const Icon(Icons.calendar_today),
                    // End Date ListTile onTap method
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: tempEndDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                        // Add these theme properties
                        builder: (context, child) {
                          final isDark = Theme.of(context).brightness == Brightness.dark;
                          return Theme(
                            data: Theme.of(context).copyWith(
                              datePickerTheme: DatePickerThemeData(
                                confirmButtonStyle: ButtonStyle(
                                  foregroundColor: MaterialStateProperty.all<Color>(
                                    isDark ? ColorApp.darkTertiary : ColorApp.lightPrimary,
                                  ),
                                ),
                                cancelButtonStyle: ButtonStyle(
                                  foregroundColor: MaterialStateProperty.all<Color>(
                                    isDark ? ColorApp.darkTertiary : ColorApp.lightPrimary,
                                  ),
                                ),
                              ),
                            ),
                            child: child!,
                          );
                        },
                      );
                      if (picked != null) {
                        setState(() {
                          tempEndDate = picked;
                        });
                      }
                    },
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                    
                    // Clear date filters
                    attendController.clearDateFilters();
                    appController.tglAwalFilter.changeVal('');
                    appController.tglAkhirFilter.changeVal('');
                    attendController.loadAttendanceData();
                  },
                  child: const Text('Clear'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    // Format dates for API
                    String startDateStr = tempStartDate != null
                        ? DateFormat('yyyy-MM-dd').format(tempStartDate!)
                        : '';
                    String endDateStr = tempEndDate != null
                        ? DateFormat('yyyy-MM-dd').format(tempEndDate!)
                        : '';
                    
                    // Add debug prints
                    print('Setting date filters - Start: $startDateStr, End: $endDateStr');
                    
                    // Update filters in controller
                    attendController.startDateFilter.changeVal(startDateStr);
                    attendController.endDateFilter.changeVal(endDateStr);
                    appController.tglAwalFilter.changeVal(startDateStr);
                    appController.tglAkhirFilter.changeVal(endDateStr);
                    
                    // Close dialog
                    Navigator.pop(dialogContext);
                    
                    // Load data with new filters
                    attendController.loadAttendanceData();
                  },
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
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
                child: IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () {
                    _showDeleteConfirmation(context);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoColumn(context, 'Date', formattedDate),
              _infoColumn(context, 'Category', categoryName),
            ],
          ),

          // Status and duration rows removed as requested
          if (location != '-') ...[
            // Only show if location is available
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: Theme.of(context).colorScheme.primary,
                  size: 18,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    location,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
          if (notes != '-') ...[
            // Only show if notes are available
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

          // More Details section removed as requested
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
        content: const Text(
          'Are you sure you want to delete this attendance record?',
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
        // Add a local timeout to ensure the API call doesn't hang indefinitely
        final response = await Api()
            .delAbsensi(id)
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
          safeShowSnackBar('Attendance deleted successfully');

          // Trigger reload of attendance data
          attendController.reloadAttendanceData.changeVal('true');
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
    final String? photoBase64 = attendanceData['photo'];

    // Safe substring to avoid errors with null or empty strings
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      print(
        'Photo data: ${photoBase64.substring(0, photoBase64.length > 30 ? 30 : photoBase64.length)}...',
      );
    } else {
      print('Photo data is null or empty');
    }

    // Check for invalid or placeholder data
    if (photoBase64 == null ||
        photoBase64.isEmpty ||
        photoBase64 == '-' ||
        photoBase64 == 'xxxx' ||
        photoBase64.contains('data:image/png;base64,xxxx')) {
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
      print(
        'Attempting to decode base64 string of length: ${base64String.length}',
      );
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
          'EEEE, d MMMM yyyy',
          'id_ID',
        ).format(dateTime); // e.g., "Senin, 12 Agustus 2025"
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
          int minute = int.parse(
            parts[1].split(' ')[0],
          ); // Handle cases like "14:30:00"

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
