import 'package:flutter/material.dart';
import 'package:get_storage/get_storage.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final GetStorage user = GetStorage();
  final Api _api = Api();
  
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Delay for splash screen visibility (optional)
    await Future.delayed(const Duration(seconds: 2));
    
    // Check if user token exists
    final token = user.read('token');
    final email = user.read('email');
    final pass = user.read('pass');
    
    if (token != null && email != null && pass != null) {
      try {
        // Attempt to get profile to verify token validity
        final profileResponse = await _api.getProfile();
        
        if (profileResponse['status'] == true) {
          // Token is valid, load necessary data
          await _loadMasterData();
          
          // Navigate to main screen
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/main');
          }
        } else {
          // Token is invalid, try to login again with stored credentials
          final loginResponse = await _api.login(email, pass);
          
          if (loginResponse['status'] == true) {
            // Login successful, load necessary data
            await _loadMasterData();
            
            // Navigate to main screen
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/main');
            }
          } else {
            // Login failed, go to login screen
            if (mounted) {
              Navigator.pushReplacementNamed(context, '/login');
            }
          }
        }
      } catch (e) {
        // Error occurred, go to login screen
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      }
    } else {
      // No stored credentials, go to login screen
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  Future<void> _loadMasterData() async {
    try {
      // Fetch and save category data
      final masterApi = MasterApi();
      
      // Fetch and save category data
      final categoryResponse = await masterApi.categoryAbsensi();
      if (categoryResponse['status'] == true && categoryResponse['data'] != null) {
        appController.categoryLMB.removeAll();
        appController.categoryLMB.addAll(categoryResponse['data']);
        appController.categoryListMap = List<Map>.from(categoryResponse['data']);
      }

      // Fetch and save approval lembur data
      final approvalLemburResponse = await masterApi.approvalLembur();
      if (approvalLemburResponse['status'] == true && approvalLemburResponse['data'] != null) {
        appController.approvalLemburLMB.removeAll();
        appController.approvalLemburLMB.addAll(approvalLemburResponse['data']);
        appController.approvalLemburListMap = List<Map>.from(approvalLemburResponse['data']);
      }
      
      // Fetch and save jabatan data
      final jabatanResponse = await masterApi.jabatan();
      if (jabatanResponse['status'] == true && jabatanResponse['data'] != null) {
        appController.jabatanLMB.removeAll();
        appController.jabatanLMB.addAll(jabatanResponse['data']);
        appController.jabatanListMap = List<Map>.from(jabatanResponse['data']);
      }
      
      // Fetch and save divisi data
      final divisiResponse = await masterApi.divisi();
      if (divisiResponse['status'] == true && divisiResponse['data'] != null) {
        appController.divisiLMB.removeAll();
        appController.divisiLMB.addAll(divisiResponse['data']);
        appController.divisiListMap = List<Map>.from(divisiResponse['data']);
      }
      
      // Fetch and save jenis lembur data
      final jenisLemburResponse = await masterApi.jenisLembur();
      if (jenisLemburResponse['status'] == true && jenisLemburResponse['data'] != null) {
        appController.jenisLemburLMB.removeAll();
        appController.jenisLemburLMB.addAll(jenisLemburResponse['data']);
        appController.jenisLemburListMap = List<Map>.from(jenisLemburResponse['data']);
      }
    } catch (e) {
      print('Error loading master data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF3F3D8C),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Add your logo here
            Image.asset(
              'assets/images/logo.png', // Make sure this asset exists
              width: 150,
              height: 150,
              errorBuilder: (context, error, stackTrace) {
                return const Icon(
                  Icons.business,
                  size: 150,
                  color: Colors.white,
                );
              },
            ),
            const SizedBox(height: 30),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
            const SizedBox(height: 20),
            const Text(
              'Smartkidz HR',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}