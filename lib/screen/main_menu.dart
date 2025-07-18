import 'dart:convert';
import 'dart:io';
import 'dart:math' as Math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/custom_bloc.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/controller/attend_controller.dart';
import 'package:hr_payroll_smartkidz/controller/main_controller.dart';
import 'package:hr_payroll_smartkidz/controller/tim_controller.dart';
import 'package:hr_payroll_smartkidz/screen/staff/account_list.dart';
import 'package:hr_payroll_smartkidz/screen/staff/attend_list.dart';
import 'package:hr_payroll_smartkidz/screen/staff/tim_list.dart';
import 'package:hr_payroll_smartkidz/screen/staff/letter_list.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';

class MainMenuScreen extends StatefulWidget {
  const MainMenuScreen({super.key});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen> {
  DateTime? _startDate;
  DateTime? _endDate;
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isCameraInitialized = false;
  bool _isProcessing = false;
  String? _imagePath;
  String? _base64Image;
  Position? _currentPosition;
  final TextEditingController _descriptionController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Initialize with Presensi screen (index 0)
    mainController.changeIndexMenu(0);
    // Initialize camera
    _initializeCamera();
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _initializeCamera() async {
    try {
      // Get available cameras
      _cameras = await availableCameras();
      print('Available cameras: ${_cameras?.length ?? 0}');

      if (_cameras == null || _cameras!.isEmpty) {
        print('No cameras available');
        return;
      }

      // Find front camera
      CameraDescription? frontCamera;
      for (var camera in _cameras!) {
        print('Camera: ${camera.name}, direction: ${camera.lensDirection}');
        if (camera.lensDirection == CameraLensDirection.front) {
          frontCamera = camera;
          break;
        }
      }

      // If front camera not found, use the first available camera
      final cameraToUse = frontCamera ?? _cameras!.first;
      print(
        'Using camera: ${cameraToUse.name}, direction: ${cameraToUse.lensDirection}',
      );

      // Dispose of previous controller if it exists
      await _cameraController?.dispose();

      // Create new controller
      _cameraController = CameraController(
        cameraToUse,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      // Initialize the controller
      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isCameraInitialized = true;
        });
        print('Camera initialized successfully');
      }
    } catch (e) {
      print('Error initializing camera: $e');
      if (mounted) {
        setState(() {
          _isCameraInitialized = false;
        });
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location services are disabled.')),
      );
      return;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Location permissions are permanently denied, we cannot request permissions.',
          ),
        ),
      );
      return;
    }

    // When we reach here, permissions are granted and we can get the location
    try {
      _currentPosition = await Geolocator.getCurrentPosition();
      print(
        'Current location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}',
      );
    } catch (e) {
      print('Error getting location: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error getting location: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout.builder(
      mobile: (context) => _buildScaffold(context),
      tablet: (context) => _buildScaffold(context, isTablet: true),
      desktop: (context) => _buildScaffold(context, isDesktop: true),
      watch: (context) => _buildScaffold(context, isWatch: true),
    );
  }

  // Show attendance form with camera and location
  void _showAttendanceForm(BuildContext context) async {
    // Reset state
    setState(() {
      _imagePath = null;
      _base64Image = null;
      _descriptionController.clear();
    });

    // Get current location
    await _getCurrentLocation();

    // Check if camera is initialized, if not try to initialize it again
    if (!_isCameraInitialized) {
      print('Camera not initialized, attempting to initialize again...');
      await _initializeCamera();

      // If still not initialized, show error and return
      if (!_isCameraInitialized) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Camera initialization failed. Please restart the app and try again.',
            ),
          ),
        );
        return;
      }
    }

    // Ensure camera controller is valid
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      print('Camera controller is null or not initialized');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Camera is not ready. Please try again.')),
      );
      return;
    }

    if (_currentPosition == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to get location. Please try again.'),
        ),
      );
      return;
    }

    // Get the selected category
    final categories = appController.categoryListMap.isNotEmpty
        ? appController.categoryListMap
        : [
            {'id': 1, 'name': 'Check In'},
            {'id': 2, 'name': 'Check Out'},
            {'id': 3, 'name': 'Cuti'},
          ];

    final selectedIndex = attendController.currentIndexAttend.state;
    final selectedCategory = categories[selectedIndex]['id'];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Attendance Form'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Camera preview or captured image
                  if (_base64Image == null) ...[
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors
                            .black, // Keeping black for camera background as it's standard
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: _cameraController!.value.isInitialized
                            ? CameraPreview(_cameraController!)
                            : const Center(child: CircularProgressIndicator()),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      onPressed: _isProcessing
                          ? null
                          : () async {
                              setDialogState(() {
                                _isProcessing = true;
                              });

                              try {
                                // Check if camera controller is still valid
                                if (_cameraController == null ||
                                    !_cameraController!.value.isInitialized) {
                                  throw Exception('Camera is not ready');
                                }

                                // Capture image
                                print('Taking picture...');
                                final XFile image = await _cameraController!
                                    .takePicture();
                                print('Picture taken: ${image.path}');
                                _imagePath = image.path;

                                // Convert to base64
                                print('Converting image to base64...');
                                final bytes = await File(
                                  _imagePath!,
                                ).readAsBytes();
                                print('Image size: ${bytes.length} bytes');
                                final base64String = base64Encode(bytes);
                                // Add the data URI prefix as expected by the API and display code
                                _base64Image =
                                    'data:image/png;base64,$base64String';

                                // Debug log to verify conversion
                                print(
                                  'Image converted to base64 with prefix. Length: ${_base64Image!.length}',
                                );
                                print(
                                  'Base64 sample: ${_base64Image!.substring(0, Math.min(50, _base64Image!.length))}...',
                                );

                                setDialogState(() {
                                  _isProcessing = false;
                                });
                              } catch (e) {
                                print('Error capturing image: $e');
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Error capturing image: $e'),
                                  ),
                                );
                                setDialogState(() {
                                  _isProcessing = false;
                                });

                                // Try to reinitialize camera if there was an error
                                _initializeCamera();
                              }
                            },
                      child: _isProcessing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Capture Photo',
                              style: TextStyle(color: Colors.white),
                            ),
                    ),
                  ] else ...[
                    // Show captured image
                    Container(
                      height: 300,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(File(_imagePath!), fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        setDialogState(() {
                          _base64Image = null;
                          _imagePath = null;
                        });
                      },
                      child: const Text('Retake Photo'),
                    ),
                  ],

                  const SizedBox(height: 16),

                  // Location information
                  // Container(
                  //   padding: const EdgeInsets.all(12),
                  //   decoration: BoxDecoration(
                  //     color: Colors.grey[200],
                  //     borderRadius: BorderRadius.circular(8),
                  //   ),
                  //   child: Column(
                  //     crossAxisAlignment: CrossAxisAlignment.start,
                  //     children: [
                  //       const Text(
                  //         'Location:',
                  //         style: TextStyle(fontWeight: FontWeight.bold),
                  //       ),
                  //       const SizedBox(height: 4),
                  //       Text(
                  //         'Latitude: ${_currentPosition?.latitude ?? 'Unknown'}',
                  //       ),
                  //       Text(
                  //         'Longitude: ${_currentPosition?.longitude ?? 'Unknown'}',
                  //       ),
                  //     ],
                  //   ),
                  // ),

                  const SizedBox(height: 16),

                  // Description field
                  TextField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      border: OutlineInputBorder(),
                      hintText: 'Enter description (optional)',
                    ),
                    maxLines: 3,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).primaryColor,
                ),
                onPressed: (_base64Image == null || _isProcessing)
                    ? null
                    : () async {
                        setDialogState(() {
                          _isProcessing = true;
                        });

                        try {
                          // Prepare data for API
                          final Map<String, String> attendanceData = {
                            'category': selectedCategory.toString(),
                            'latitude': _currentPosition!.latitude.toString(),
                            'longitude': _currentPosition!.longitude.toString(),
                            'photo': _base64Image!,
                            'description': _descriptionController.text,
                          };

                          // Send data to API
                          final response = await Api().addAbsensi(
                            attendanceData,
                          );

                          setDialogState(() {
                            _isProcessing = false;
                          });

                          Navigator.pop(context); // Close dialog

                          if (response['status'] == true) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Attendance recorded successfully',
                                ),
                              ),
                            );

                            // Refresh attendance list
                            attendController.reloadAttendanceData.changeVal(
                              'true',
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Failed to record attendance: ${response['message'] ?? "Unknown error"}',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          print('Error submitting attendance: $e');
                          setDialogState(() {
                            _isProcessing = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Error submitting attendance: $e'),
                            ),
                          );
                        }
                      },
                child: _isProcessing
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Text(
                        'Submit',
                        style: TextStyle(color: Colors.white),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    bool isTablet = false,
    bool isDesktop = false,
    bool isWatch = false,
  }) {

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).primaryColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: BlocBuilder(
          bloc: mainController.currentIndexMenu,
          builder: (context, state) {
            switch (mainController.currentIndexMenu.state) {
              case 0:
                return const Text(
                  'Presensi',
                  style: TextStyle(color: Colors.white),
                );
              case 1:
                return const Text('Tim', style: TextStyle(color: Colors.white));
              case 2:
                return const Text(
                  'Letter',
                  style: TextStyle(color: Colors.white),
                );
              case 3:
                return const Text(
                  'Settings',
                  style: TextStyle(color: Colors.white),
                );
              default:
                return const Text(
                  'Letter',
                  style: TextStyle(color: Colors.white),
                );
            }
          },
        ),
        // leading: BlocBuilder(
        //   bloc: mainController.currentIndexMenu,
        //   builder: (context, state) {
        //     // Show filter button when on Presensi screen (index 0) or Letter screen (index 2)
        //     if (mainController.currentIndexMenu.state == 0 ||
        //         mainController.currentIndexMenu.state == 2) {
        //       return IconButton(
        //         icon: const Icon(Icons.filter_alt, color: Colors.white),
        //         onPressed: () => _showDateFilterDialog(context),
        //       );
        //     }
        //     // Trigger reload in LetterScreen
        //     // Trigger reload in LetterScreen
        //     letterController.reloadLetterData.changeVal('true');
        //     return const SizedBox.shrink(); // Empty widget when not on Presensi or Letter screen
        //   },
        // ),
      ),
      body: BlocBuilder(
        bloc: mainController.currentIndexMenu,
        builder: (context, state) {
          switch (mainController.currentIndexMenu.state) {
            case 0:
              return const AttendanceScreen();
            case 1:
              return const TeamListScreen();
            case 2:
              return const LetterScreen();
            case 3:
              return const MyAccountPage();
            default:
              return const AttendanceScreen();
          }
        },
      ),
      // Show floating action button only when Presensi menu is selected
      floatingActionButton: BlocBuilder(
        bloc: mainController.currentIndexMenu,
        builder: (context, state) {
          if (mainController.currentIndexMenu.state == 0) {
            return FloatingActionButton(
              backgroundColor: Theme.of(context).primaryColor,
              onPressed: () => _showAttendanceForm(context),
              child: Icon(
                Icons.camera_alt,
                color: Theme.of(context).colorScheme.onPrimary,
              ),
            );
          }
          return const SizedBox.shrink(); // No FAB for other menu items
        },
      ),
      bottomNavigationBar: BlocBuilder(
        bloc: mainController.currentIndexMenu,
        builder: (context, state) {
          // Buat list item bottom navigation bar
          final List<BottomNavigationBarItem> navItems = [
            BottomNavigationBarItem(
              icon: Icon(
                Icons.camera_front_rounded,
                color: mainController.currentIndexMenu.state == 0
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
              ),
              label: 'Presensi',
            ),
            BottomNavigationBarItem(
              backgroundColor: Theme.of(context).primaryColor,
              icon: Stack(
                children: [
                  Icon(
                    Icons.people_rounded,
                    color: mainController.currentIndexMenu.state == 1
                        ? Theme.of(context).colorScheme.tertiary
                        : Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
                  ),
                  // Tambahkan indikator ulang tahun jika ada anggota tim yang berulang tahun hari ini
                  BlocBuilder<CustomBloc, dynamic>(
                    bloc: timController.hasBirthdayToday,
                    builder: (context, hasBirthday) {
                      if (hasBirthday == true) {
                        return Positioned(
                          right: 0,
                          top: 0,
                          child: Container(
                            padding: EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                            ),
                            constraints: BoxConstraints(minWidth: 8, minHeight: 8),
                          ),
                        );
                      }
                      return SizedBox.shrink();
                    },
                  ),
                ],
              ),
              label: 'Tim',
            ),
            // BottomNavigationBarItem(
            //   icon: Icon(
            //     Icons.access_time,
            //     color: mainController.currentIndexMenu.state == 2
            //         ? Theme.of(context).colorScheme.tertiary
            //         : Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
            //   ),
            //   label: 'Overtime',
            // ),
            // Hapus kondisi if untuk menu Surat
            BottomNavigationBarItem(
              icon: Icon(
                Icons.mail_outline, // Changed icon to be more appropriate for Letter
                color: mainController.currentIndexMenu.state == 2
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
              ),
              label: 'Letter',
            ),
             BottomNavigationBarItem(
              icon: Icon(
                Icons.settings, // Changed icon to be more appropriate for Letter
                color: mainController.currentIndexMenu.state == 2
                    ? Theme.of(context).colorScheme.tertiary
                    : Theme.of(context).colorScheme.onPrimary.withOpacity(0.5),
              ),
              label: 'Account',
            ),
          ];

          // Pastikan currentIndex valid untuk jumlah item yang ada
          int currentIndex = mainController.currentIndexMenu.state;

          // Jika currentIndex melebihi jumlah item yang ada, sesuaikan
          if (currentIndex >= navItems.length) {
            currentIndex = navItems.length - 1;
          }

          return BottomNavigationBar(
            backgroundColor: Theme.of(context).primaryColor,
            selectedItemColor: Theme.of(context).colorScheme.tertiary,
            unselectedItemColor: Theme.of(
              context,
            ).colorScheme.onPrimary.withOpacity(0.5),
            type: BottomNavigationBarType
                .fixed, // Add this to support more than 4 items
            items: navItems,
            currentIndex: currentIndex,
            onTap: (index) {
               mainController.changeIndexMenu(index);
            },
          );
        },
      ),
    );
  }
}
