import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:hr_payroll_smartkidz/controller/overtime_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:intl/intl.dart';

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
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit, color: Colors.blue),
                    onPressed: () {
                      _showEditConfirmation(context);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _showDeleteConfirmation(context);
                    },
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
  
  void _showEditConfirmation(BuildContext context) {
    final String id = overtimeData['id']?.toString() ?? '';
    
    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot edit: Invalid overtime ID')),
      );
      return;
    }
    
    // Panggil fungsi untuk menampilkan form edit
    _showEditOvertimeForm(context, overtimeData);
  }
  
  // Helper method to parse TimeOfDay from string
  TimeOfDay? _parseTimeOfDay(String timeString) {
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
  
  void _showEditOvertimeForm(BuildContext context, Map<dynamic, dynamic> overtimeData) {
    // Set form values from existing data
    final String id = overtimeData['id']?.toString() ?? '';
    final TextEditingController keperluanController = TextEditingController(text: overtimeData['keperluan'] ?? '');
    final TextEditingController startTimeController = TextEditingController(text: overtimeData['jamMulai'] ?? '');
    final TextEditingController endTimeController = TextEditingController(text: overtimeData['jamSelesai'] ?? '');
    final TextEditingController dateController = TextEditingController(text: overtimeData['tanggal'] ?? '');
    String selectedOvertimeType = overtimeData['jenisLembur']?.toString() ?? '';
    
    // Form key for validation
    final formKey = GlobalKey<FormState>();
    
    // Show dialog
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Data Lembur'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Date Picker
                  TextFormField(
                    controller: dateController,
                    decoration: const InputDecoration(
                      labelText: 'Tanggal',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.calendar_today),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final DateTime? picked = await showDatePicker(
                        context: context,
                        initialDate: DateTime.tryParse(dateController.text) ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null) {
                        dateController.text = DateFormat('yyyy-MM-dd').format(picked);
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
                    controller: startTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Jam Mulai',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final TimeOfDay initialTime = _parseTimeOfDay(startTimeController.text) ?? TimeOfDay.now();
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: initialTime,
                      );
                      if (picked != null) {
                        // Format time as HH:MM
                        startTimeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
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
                    controller: endTimeController,
                    decoration: const InputDecoration(
                      labelText: 'Jam Selesai',
                      border: OutlineInputBorder(),
                      suffixIcon: Icon(Icons.access_time),
                    ),
                    readOnly: true,
                    onTap: () async {
                      final TimeOfDay initialTime = _parseTimeOfDay(endTimeController.text) ?? TimeOfDay.now();
                      final TimeOfDay? picked = await showTimePicker(
                        context: context,
                        initialTime: initialTime,
                      );
                      if (picked != null) {
                        // Format time as HH:MM
                        endTimeController.text = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
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
                    controller: keperluanController,
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
                            Text('Menyimpan perubahan...'),
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
                      'tanggal': dateController.text,
                      'keperluan': keperluanController.text,
                    };
                    
                    // Call API to update overtime
                    final response = await Api().updateLembur(dataLembur, overtimeData['id'].toString());
                    
                    // Close loading dialog
                    Navigator.of(context).pop();
                    
                    // Close form dialog
                    Navigator.of(context).pop();
                    
                    // Show success or error message
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(response['message'] ?? (response['status'] == true ? 'Data lembur berhasil diperbarui' : 'Gagal memperbarui data lembur')),
                        backgroundColor: response['status'] == true ? Colors.green : Colors.red,
                      ),
                    );
                    
                    // Reload data if successful
                    if (response['status'] == true) {
                      overtimeController.reloadOvertimeData.changeVal('true');
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
        // Changed from delAbsensi to delLembur to correctly delete overtime records
        final response = await Api().delLembur(id).timeout(
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