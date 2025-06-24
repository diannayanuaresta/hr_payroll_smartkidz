import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hr_payroll_smartkidz/controller/main_controller.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/theme_bloc.dart';
import 'package:hr_payroll_smartkidz/components/color_app.dart';
import 'package:hr_payroll_smartkidz/components/theme_toggle.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

class MyAccountPage extends StatefulWidget {
  const MyAccountPage({super.key});

  @override
  State<MyAccountPage> createState() => _MyAccountPageState();
}

class _MyAccountPageState extends State<MyAccountPage> {
  final Api _api = Api();
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }
  
  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _api.getProfile();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading profile: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout.builder(
      mobile: (_) => _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : AccountContent(padding: 16),
      tablet: (_) => _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : AccountContent(padding: 32),
      desktop: (_) => _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : AccountContent(padding: 64),
      watch: (_) => _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : const WatchAccountContent(),
    );
  }
}

class AccountContent extends StatelessWidget {
  final double padding;
  const AccountContent({super.key, required this.padding});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        children: [
          // Theme Toggle
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Appearance',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Choose your preferred theme mode:'),
                  const SizedBox(height: 8),
                  const Center(child: ThemeToggleSwitch(showLabel: true)),
                ],
              ),
            ),
          ),
          const AccountForm(),
        ],
      ),
    );
  }
}

class AccountForm extends StatefulWidget {
  const AccountForm({super.key});

  @override
  State<AccountForm> createState() => _AccountFormState();
}

class _AccountFormState extends State<AccountForm> {
  final _formKey = GlobalKey<FormState>();
  final Api _api = Api();
  bool _isLoading = false;
  
  // Form controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _cityController = TextEditingController();
  final TextEditingController _stateController = TextEditingController();
  final TextEditingController _zipController = TextEditingController();
  String _country = 'Indonesia';
  
  // Date of birth
  DateTime? _tanggalLahir;
  
  // Image handling
  String? _base64Image;
  String? _imagePath;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _zipController.dispose();
    super.dispose();
  }
  
  void _loadUserData() {
    final userProfile = appController.userProfile.state;
    if (userProfile.isNotEmpty) {
      _nameController.text = userProfile['name'] ?? '';
      _usernameController.text = userProfile['username'] ?? '';
      _phoneController.text = userProfile['phone'] ?? '';
      _emailController.text = userProfile['email'] ?? '';
      
      // Load date of birth if available
      if (userProfile['tanggalLahir'] != null && userProfile['tanggalLahir'].toString().isNotEmpty) {
        try {
          _tanggalLahir = DateTime.parse(userProfile['tanggalLahir']);
        } catch (e) {
          print('Error parsing date of birth: $e');
        }
      }
      
      // Load profile image if available
      if (userProfile['image'] != null && userProfile['image'].toString().isNotEmpty) {
        _base64Image = userProfile['image'];
      }
      
      // Only load fields that have default data
      if (userProfile['address'] != null && userProfile['address'].toString().isNotEmpty) {
        _addressController.text = userProfile['address'];
      }
      if (userProfile['city'] != null && userProfile['city'].toString().isNotEmpty) {
        _cityController.text = userProfile['city'];
      }
      if (userProfile['state'] != null && userProfile['state'].toString().isNotEmpty) {
        _stateController.text = userProfile['state'];
      }
      if (userProfile['zip_code'] != null && userProfile['zip_code'].toString().isNotEmpty) {
        _zipController.text = userProfile['zip_code'];
      }
      _country = userProfile['country'] ?? 'Indonesia';
    }
  }
  
  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final userData = {
        'name': _nameController.text,
        'username': _usernameController.text,
        'phone': _phoneController.text,
        'tanggalLahir': _tanggalLahir != null ? _tanggalLahir!.toIso8601String().split('T')[0] : '',
        'email': _emailController.text,
        'address': _addressController.text,
        'city': _cityController.text,
        'state': _stateController.text,
        'zip_code': _zipController.text,
        'country': _country,
      };
      
      // Add image if available
      if (_base64Image != null) {
        userData['image'] = _base64Image!;
      }
      
      final response = await _api.updateProfile(userData);
      
      if (response['status'] == true) {
        // Update local user profile data
        await _api.getProfile();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Profile updated successfully')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(response['message'] ?? 'Failed to update profile')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Show logout confirmation dialog
  void _showLogoutConfirmation(context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout Confirmation'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              // Close the dialog first
              Navigator.pop(context);
              
              // Show loading indicator
              setState(() {
                _isLoading = true;
              });
              
              try {
                // Call logout API
                final response = await _api.logout();
                
                // Handle the response
                if (response['status'] == true) {
                  // Reset main controller index
                  mainController.changeIndexMenu(0);
                  
                  // On successful logout, navigate to login screen
                  // and remove all previous routes from the stack
                  if (mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil(
                      '/login', 
                      (route) => false
                    );
                  }
                } else {
                  // Only update state and show error if logout failed
                  setState(() {
                    _isLoading = false;
                  });
                  
                  // Show error message
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(response['message'] ?? 'Failed to logout'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                // Only update state and show error if exception occurred
                if (mounted) {
                  setState(() {
                    _isLoading = false;
                  });
                  
                  // Show error message
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }
  
  // Show password change dialog
  void _showChangePasswordDialog() {
    final _oldPasswordController = TextEditingController();
    final _newPasswordController = TextEditingController();
    final _confirmPasswordController = TextEditingController();
    bool _isChangingPassword = false;
    final _passwordFormKey = GlobalKey<FormState>();
    
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Change Password'),
              content: Form(
                key: _passwordFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: _oldPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Current Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your current password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _newPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'New Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a new password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _confirmPasswordController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Confirm New Password',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please confirm your new password';
                        }
                        if (value != _newPasswordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: _isChangingPassword
                      ? null
                      : () async {
                          if (_passwordFormKey.currentState!.validate()) {
                            setState(() {
                              _isChangingPassword = true;
                            });
                            
                            try {
                              final response = await _api.changePass(
                                _oldPasswordController.text,
                                _newPasswordController.text,
                                _confirmPasswordController.text,
                              );
                              
                              Navigator.pop(context);
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(response['message'] ?? 
                                    (response['status'] == true 
                                      ? 'Password changed successfully' 
                                      : 'Failed to change password')),
                                  backgroundColor: response['status'] == true 
                                    ? Colors.green 
                                    : Colors.red,
                                ),
                              );
                            } catch (e) {
                              setState(() {
                                _isChangingPassword = false;
                              });
                              
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A7AFE),
                  ),
                  child: _isChangingPassword
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Change Password'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Function to pick date of birth
  Future<void> _selectDateOfBirth(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _tanggalLahir ?? DateTime(1990),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    
    if (picked != null && picked != _tanggalLahir) {
      setState(() {
        _tanggalLahir = picked;
      });
    }
  }
  
  // Function to handle image selection
  Future<void> _selectImage(BuildContext context) async {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Profile Photo'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_base64Image != null) ...[  
                      // Show current image
                      Container(
                        height: 200,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: _base64Image!.contains('base64,') 
                            ? Image.memory(
                                base64Decode(_base64Image!.split('base64,')[1]),
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(child: Text('Invalid image'));
                                },
                              )
                            : Image.network(
                                _base64Image!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Center(child: Text('Invalid image'));
                                },
                              ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () {
                          setDialogState(() {
                            _base64Image = null;
                          });
                        },
                        child: const Text('Remove Photo'),
                      ),
                    ] else ...[  
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A7AFE),
                        ),
                        onPressed: () async {
                          // Use image_picker to select image from gallery
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.gallery);
                          
                          if (image != null) {
                            try {
                              // Convert to base64
                              final bytes = await File(image.path).readAsBytes();
                              final base64String = base64Encode(bytes);
                              // Add the data URI prefix as expected by the API
                              final imageData = 'data:image/png;base64,$base64String';
                              
                              setDialogState(() {
                                _base64Image = imageData;
                              });
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error processing image: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Select from Gallery', style: TextStyle(color: Colors.white)),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF3A7AFE),
                        ),
                        onPressed: () async {
                          // Use image_picker to take a photo
                          final ImagePicker picker = ImagePicker();
                          final XFile? image = await picker.pickImage(source: ImageSource.camera);
                          
                          if (image != null) {
                            try {
                              // Convert to base64
                              final bytes = await File(image.path).readAsBytes();
                              final base64String = base64Encode(bytes);
                              // Add the data URI prefix as expected by the API
                              final imageData = 'data:image/png;base64,$base64String';
                              
                              setDialogState(() {
                                _base64Image = imageData;
                              });
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error processing image: $e')),
                              );
                            }
                          }
                        },
                        child: const Text('Take Photo', style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return BlocBuilder(
      bloc: appController.userProfile,
      builder: (context, state) {
        return Form(
          key: _formKey,
          child: Column(
            children: [
              // Profile image selection
              GestureDetector(
                onTap: () => _selectImage(context),
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _base64Image != null
                        ? (_base64Image!.contains('base64,') 
                            ? MemoryImage(base64Decode(_base64Image!.split('base64,')[1]))
                            : NetworkImage(_base64Image!) as ImageProvider)
                        : const NetworkImage('https://ui-avatars.com/api/?name=User&background=3A7AFE&color=fff'),
                      backgroundColor: const Color(0xFF3A7AFE),
                    ),
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: Colors.white,
                      child: Icon(Icons.camera_alt, size: 16, color: Theme.of(context).primaryColor),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 16),
              
              buildTextField(
                controller: _nameController,
                label: 'Full Name', 
                hint: 'Enter your full name',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              buildTextField(
                controller: _usernameController,
                label: 'Username', 
                hint: 'Enter your username',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your username';
                  }
                  return null;
                },
              ),
              buildPhoneField(),
              
              // Date of birth field
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: InkWell(
                  onTap: () => _selectDateOfBirth(context),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth',
                      border: OutlineInputBorder(),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _tanggalLahir != null
                              ? '${_tanggalLahir!.day}/${_tanggalLahir!.month}/${_tanggalLahir!.year}'
                              : 'Select date of birth',
                          style: TextStyle(
                            color: _tanggalLahir != null ? Colors.black : Colors.grey,
                          ),
                        ),
                        const Icon(Icons.calendar_today),
                      ],
                    ),
                  ),
                ),
              ),
              
              buildTextField(
                controller: _emailController,
                label: 'Email Address', 
                hint: 'Enter your email',
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              // Only show address field if it has data
              if (_addressController.text.isNotEmpty)
                buildTextField(
                  controller: _addressController,
                  label: 'Address', 
                  hint: 'Enter your address',
                ),
              // Only show city and state fields if they have data
              if (_cityController.text.isNotEmpty || _stateController.text.isNotEmpty)
                Row(
                  children: [
                    if (_cityController.text.isNotEmpty)
                      Expanded(child: buildTextField(
                        controller: _cityController,
                        label: 'City',
                        hint: 'Enter your city',
                      )),
                    if (_cityController.text.isNotEmpty && _stateController.text.isNotEmpty)
                      const SizedBox(width: 10),
                    if (_stateController.text.isNotEmpty)
                      Expanded(child: buildTextField(
                        controller: _stateController,
                        label: 'State/Province',
                        hint: 'Enter your state',
                      )),
                  ],
                ),
              // Only show postal code and country if postal code has data
              if (_zipController.text.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(child: buildTextField(
                        controller: _zipController,
                        label: 'Postal Code',
                        hint: 'Enter postal code',
                      )),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _country,
                          items: ['Indonesia', 'Malaysia', 'Singapore', 'United States', 'Other']
                              .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _country = value;
                              });
                            }
                          },
                          decoration: const InputDecoration(
                            labelText: 'Country',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _updateProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3A7AFE),
                    disabledBackgroundColor: Colors.grey,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Update Profile', style: TextStyle(fontSize: 18, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: _showChangePasswordDialog,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF3A7AFE)),
                  ),
                  child: const Text('Change Password', 
                    style: TextStyle(fontSize: 18, color: Color(0xFF3A7AFE))),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton(
                  onPressed: () => _showLogoutConfirmation(context),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.red),
                  ),
                  child: const Text('Logout', 
                    style: TextStyle(fontSize: 18, color: Colors.red)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget buildTextField({
    required String hint, 
    String? label, 
    TextEditingController? controller,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget buildPhoneField() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: _phoneController,
        keyboardType: TextInputType.phone,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your phone number';
          }
          return null;
        },
        decoration: const InputDecoration(
          labelText: 'Mobile Number',
          hintText: 'Enter your phone number',
          border: OutlineInputBorder(),
        ),
      ),
    );
  }
}

class WatchAccountContent extends StatelessWidget {
  const WatchAccountContent({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: const [
          SizedBox(height: 20),
          Icon(Icons.account_circle, size: 48, color: Colors.blue),
          Text(
            "My Account",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          Text("Too small for form", style: TextStyle(fontSize: 12)),
        ],
      ),
    );
  }
}