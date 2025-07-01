import 'package:flutter/material.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false;
  final Api _api = Api();

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background with curved shapes
          Positioned(
            top: 0,
            left: 0,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: const BoxDecoration(
                color: Color(0xFF3F3D8C), // Deep blue color
                borderRadius: BorderRadius.only(
                  bottomRight: Radius.circular(200),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.7,
              height: MediaQuery.of(context).size.height * 0.4,
              decoration: const BoxDecoration(
                color: Color(0xFF3F3D8C), // Deep blue color
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(200),
                ),
              ),
            ),
          ),
          // Orange accent
          Positioned(
            bottom: 0,
            left: 0,
            child: Container(
              width: MediaQuery.of(context).size.width * 0.3,
              height: MediaQuery.of(context).size.height * 0.3,
              decoration: const BoxDecoration(
                color: Color(0xFFE95420), // Orange color
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(100),
                ),
              ),
            ),
          ),
          // Login form
          Center(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Login',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 40),
                    // Username field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _usernameController,
                        decoration: InputDecoration(
                          hintText: 'Username',
                          prefixIcon: const Icon(Icons.person_outline, color: Colors.grey),
                          suffixIcon: GestureDetector(
                             onTap: () => _handleLogin(),
                             child: Container(
                               margin: const EdgeInsets.all(8),
                               decoration: const BoxDecoration(
                                 shape: BoxShape.circle,
                                 color: Color(0xFF4FC3F7), // Light blue color for button
                               ),
                               child: _isLoading 
                                 ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                                 : const Icon(Icons.arrow_forward, color: Colors.white, size: 20),
                             ),
                           ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Password field
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.2),
                            spreadRadius: 2,
                            blurRadius: 5,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _passwordController,
                        obscureText: _obscureText,
                        decoration: InputDecoration(
                          hintText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureText ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureText = !_obscureText;
                              });
                            },
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        TextButton(
                          onPressed: () {
                            // Handle forgot password
                          },
                          child: const Text(
                            'Forgot password?',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to register screen
                            Navigator.pushNamed(context, '/register');
                          },
                          child: const Text(
                            'Register',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  void _handleLogin() async {
    if (_usernameController.text.isEmpty || _passwordController.text.isEmpty) {
      _showSnackBar('Username dan password tidak boleh kosong', isError: true);
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final response = await _api.login(_usernameController.text, _passwordController.text);
      
      setState(() {
        _isLoading = false;
      });
      
      if (response['status'] == true) {
        // Simpan data ke controller
        appController.emailLogController.text = _usernameController.text;
        appController.passwordLogController.text = _passwordController.text;
        
        // Save the user access/role data to the MapBloc
        appController.userAccess.changeVal(response['data']);
        print('User Access: ${appController.userAccess.state}');

        // Ambil data profil
        final profileResponse = await _api.getProfile();
        
        // Ambil data master dari MasterApi
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
          appController.approvalLemburListMap = List<Map>.from(approvalLemburResponse['data']); // Gunakan variabel yang benar
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
        
        if (profileResponse['status'] == true && profileResponse['data'] != null) {
          // Data profil sudah disimpan di appController.userProfile oleh fungsi getProfile
          
          // Tampilkan snackbar sukses
          _showSnackBar('Login berhasil! Selamat datang ${profileResponse['data']['name'] ?? 'User'}');
          
          // Navigasi ke halaman main menu
          Navigator.pushReplacementNamed(context, '/main');
        } else {
          _showSnackBar('Berhasil login tetapi gagal mendapatkan data profil', isError: true);
        }
      } else {
        // Login gagal
        _showSnackBar(response['message'] ?? 'Login gagal', isError: true);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      _showSnackBar('Terjadi kesalahan: $e', isError: true);
    }
  }
  
  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? Colors.red : Colors.green,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }
}