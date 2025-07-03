import 'dart:convert';
import 'dart:async';
import 'package:get_storage/get_storage.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:http/http.dart' as http;
import 'package:nb_utils/nb_utils.dart'; // Import nb_utils to access navigatorKey

GetStorage user = GetStorage();

//autologin
GetStorage tglLoginLast = GetStorage();

//development or production
GetStorage modeApplication = GetStorage();

class Api {
  final url = 'https://dev-api-smartkidz.optimasolution.co.id';
  //url prod
  // final url = 'https://dev-api-smartkidz.optimasolution.co.id';
  // final urlimg = 'https://dev-smartkidz.optimasolution.co.id';
  //  final url = 'http://192.168.1.23:8020/';

  Future<Map<String, dynamic>> handleTokenRefreshAndRetry(
    Function originalApiCall,
  ) async {
    try {
      // First attempt with current token
      var result = await originalApiCall();

      // Check if the error is due to invalid token or expired token
      if (result['status'] == false &&
          result['message'] != null &&
          (result['message'].toString().contains('Invalid Token') ||
           result['message'].toString().contains('Expired Token') ||
           result['message'].toString().contains('Token Expired') ||
           (result['code'] != null && result['code'] == 401))) {
        print('Token invalid or expired, attempting to refresh...');

        // Try to refresh the token
        var refreshResult = await tokenRefresh();

        if (refreshResult['status'] == true) {
          print('Token refreshed successfully, retrying original request');
          // Retry the original API call with new token
          return await originalApiCall();
        } else {
          print('Token refresh failed: ${refreshResult['message']}');
          // If refresh fails, force logout and redirect to login screen
          await _handleTokenRefreshFailure();
          // Return the refresh error
          return refreshResult;
        }
      }

      // If not a token error or refresh not needed, return original result
      return result;
    } catch (e) {
      print('Error in handleTokenRefreshAndRetry: $e');
      return {'status': false, 'message': 'Error handling token refresh: $e'};
    }
  }

  // Helper method to handle token refresh failure
  Future<void> _handleTokenRefreshFailure() async {
    // Clear user data
    user.remove('token');
    user.remove('email');
    user.remove('pass');
    tglLoginLast.remove('date');

    // Reset app controller data
    appController.userProfile.changeVal({});
    appController.userAccess.changeVal({});
    
    // Reset data master
    appController.categoryLMB.removeAll();
    appController.categoryListMap = [];
    appController.jabatanLMB.removeAll();
    appController.jabatanListMap = [];
    appController.divisiLMB.removeAll();
    appController.divisiListMap = [];
    appController.jenisLemburLMB.removeAll();
    appController.jenisLemburListMap = [];
    
    // Navigate to login screen using the global navigatorKey
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  }

  Map<String, String> get headers => {
    'Authorization': 'Bearer ${user.read('token')}',
    'Accept': 'application/json',
  };

  Future login(String email, String pass) async {
    var url = Uri.parse('${this.url}/auth/absensi/login');

    var raw = {"email": email, "password": pass};
    var response = await http.post(
      url,
      headers: {'Accept': 'application/json'},
      body: raw,
    );
    var data = json.decode(response.body);
    print(data);
    if (data['status'] == true) {
      user.write('token', data['data']['access_token']);
      user.write('email', email);
      user.write('pass', pass);
      tglLoginLast.write('date', DateTime.now().toString());
    }
    print(data);
    print(raw);
    return data;
  }

  Future logout() async {
    var url = Uri.parse('${this.url}/auth/absensi/logout');

    var response = await http.post(url, headers: headers);
    var data = json.decode(response.body);
    if (data['status'] == true) {
      // Hapus semua data sesi
      user.remove('token');
      user.remove('email');
      user.remove('pass');

      // Hapus tanggal login terakhir
      tglLoginLast.remove('date');

      // Reset data user profile
      appController.userProfile.changeVal({});
      appController.userAccess.changeVal({});

      // Reset data master
      appController.categoryLMB.removeAll();
      appController.categoryListMap = [];
      appController.jabatanLMB.removeAll();
      appController.jabatanListMap = [];
      appController.divisiLMB.removeAll();
      appController.divisiListMap = [];
      appController.jenisLemburLMB.removeAll();
      appController.jenisLemburListMap = [];

      // Reset controller lainnya
      appController.emailLogController.clear();
      appController.passwordLogController.clear();
    }
    print(data);

    return data;
  }

  Future tokenRefresh() async {
    var url = Uri.parse('${this.url}/auth/absensi/refresh');

    try {
      var response = await http.post(url, headers: headers)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'The connection has timed out during token refresh, please try again!',
              );
            },
          );
      var data = json.decode(response.body);

      print('Token refresh attempt: $data');

      if (data['status'] == true) {
        user.remove('token');
        user.write('token', data['data']['access_token']);
        print('Token refreshed successfully');
        return data;
      } else {
        print('Token refresh failed: ${data['message']}');
        // If token refresh fails, you might want to force logout
        if (data['code'] == 401 || 
            (data['message'] != null && 
             (data['message'].toString().contains('Invalid Token') || 
              data['message'].toString().contains('Expired Token') || 
              data['message'].toString().contains('Token Expired')))) {
          // Clear user data and handle logout
          await _handleTokenRefreshFailure();
        }
        return data;
      }
    } catch (e) {
      print('Error refreshing token: $e');
      return {
        'status': false,
        'message': e is TimeoutException
            ? e.message
            : 'Error connecting to server during token refresh: $e',
        'code': 500,
      };
    }
  }

  Future getProfile() async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/profile');

      var response = await http.get(url, headers: headers);
      var data = json.decode(response.body);
      print(data);
      if (data['status'] == true && data['data'] != null) {
        appController.userProfile.changeVal(data['data']);
      }

      return data;
    });
  }

  Future updateProfile(Map<String, String> dataUser) async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse(
        '${this.url}/api/v1/absensi/profile/${appController.userProfile.state['id']}',
      );

      // Ensure all values are strings for the API request
      Map<String, String> raw = {};
      dataUser.forEach((key, value) {
        raw[key] = value.toString();
      });

      try {
        var response = await http.put(url, headers: headers, body: raw);
        var data = json.decode(response.body);

        if (data['status'] == true && data['data'] != null) {
          // Update the local user profile data
          appController.userProfile.changeVal(data['data']);
        }

        print('Update Profile Response: $data');
        print('Update Profile Request: $raw');

        return data;
      } catch (e) {
        print('Error updating profile: $e');
        return {'status': false, 'message': 'Error connecting to server: $e'};
      }
    });
  }

  Future changePass(String oldPass, String newPass, String confPass) async {
    return handleTokenRefreshAndRetry(() async {
      try {
        var url = Uri.parse('${this.url}/api/v1/absensi/reset-password');

        var raw = {
          'old_password': oldPass,
          'new_password': newPass,
          'confirm_password': confPass,
        };

        var response = await http.post(
          url,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${user.read('token')}',
          },
          body: raw,
        );
        var data = json.decode(response.body);

        if (data['status'] == true) {
          // Update stored password if successful
          user.write('pass', newPass);
        }

        print('Change Password Response: $data');
        print('Change Password Request: $raw');

        return data;
      } catch (e) {
        print('Error changing password: $e');
        return {'status': false, 'message': 'Error connecting to server: $e'};
      }
    });
  }

  Future getAbsensi(
    String category,
    String startDate,
    String endDate, {
    Map<String, dynamic>? additionalFilters,
  }) async {
    return handleTokenRefreshAndRetry(() async {
      var urlString =
          '${this.url}/api/v1/absensi/attendance?category=$category';

      // Debug print for date parameters
      print('Date parameters - Start: "$startDate", End: "$endDate"');

      // Always include date parameters if they exist, even if one is empty
      if (startDate.isNotEmpty) {
        urlString += '&startDate=$startDate';
      }

      if (endDate.isNotEmpty) {
        urlString += '&endDate=$endDate';
      }

      // Tambahkan parameter tambahan jika tersedia
      if (additionalFilters != null && additionalFilters.isNotEmpty) {
        additionalFilters.forEach((key, value) {
          if (value != null && value.toString().isNotEmpty) {
            urlString += '&$key=$value';
          }
        });
      }

      var url = Uri.parse(urlString);
      print('API URL: $urlString'); // Tambahkan log untuk debugging

      try {
        // Add timeout to the HTTP request to prevent long waiting times
        var response = await http
            .get(url, headers: headers)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'The connection has timed out, please try again!',
                );
              },
            );

        var data = json.decode(response.body);
        print('Get Attendance Response: $data');
        return data;
      } catch (e) {
        print('Error getting attendance data: $e');
        return {
          'status': false,
          'message': e is TimeoutException
              ? e.message
              : 'Error connecting to server: $e',
        };
      }
    }); // This is the correct closing brace for handleTokenRefreshAndRetry
  } // This is the correct closing brace for getAbsensi

  Future addAbsensi(Map<String, String> dataAbsen) async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/attendance');

      // Ensure all values are strings for the API request
      Map<String, String> raw = {};
      dataAbsen.forEach((key, value) {
        raw[key] = value.toString();
      });

      try {
        var response = await http.post(url, headers: headers, body: raw);
        var data = json.decode(response.body);

        print('Add Attendance Response: $data');
        print('Add Attendance Request: $raw');

        return data;
      } catch (e) {
        print('Error adding attendance: $e');
        return {'status': false, 'message': 'Error connecting to server: $e'};
      }
    });
  }

  Future delAbsensi(String id) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/attendance/$id');

    try {
      // Add timeout to the HTTP request to prevent long waiting times
      var response = await http
          .delete(url, headers: headers)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'The connection has timed out, please try again!',
              );
            },
          );

      var data = json.decode(response.body);
      print('Delete Attendance Response: $data');

      return data;
    } catch (e) {
      print('Error deleting attendance: $e');
      return {
        'status': false,
        'message': e is TimeoutException
            ? e.message
            : 'Error connecting to server: $e',
      };
    }
  }

  //lembur
  Future getLembur({String startDate = '', String endDate = ''}) async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/lembur');
      if (startDate != '' && endDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/lembur?startDate=$startDate&endDate=$endDate',
        );
      } else if (startDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/lembur?startDate=$startDate',
        );
      } else if (endDate != '') {
        url = Uri.parse('${this.url}/api/v1/absensi/lembur?endDate=$endDate');
      }

      try {
        // Add timeout to the HTTP request to prevent long waiting times
        var response = await http
            .get(url, headers: headers)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'The connection has timed out, please try again!',
                );
              },
            );

        var data = json.decode(response.body);
        print('Get Attendance Response: $data');
        return data;
      } catch (e) {
        print('Error getting attendance data: $e');
        return {
          'status': false,
          'message': e is TimeoutException
              ? e.message
              : 'Error connecting to server: $e',
        };
      }
    });
  }

  Future addLembur(Map<String, String> dataLembur) async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/lembur');

      // Ensure all values are strings for the API request
      Map<String, String> raw = {};
      dataLembur.forEach((key, value) {
        raw[key] = value.toString();
      });

      try {
        var response = await http.post(url, headers: headers, body: raw);
        var data = json.decode(response.body);

        print('Add Lembur Response: $data');
        print('Add Lembur Request: $raw');

        return data;
      } catch (e) {
        print('Error updating profile: $e');
        return {'status': false, 'message': 'Error connecting to server: $e'};
      }
    });
  }

  Future updateLembur(Map<String, String> dataLembur, String id) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/lembur/$id');

    // Ensure all values are strings for the API request
    Map<String, String> raw = {};
    dataLembur.forEach((key, value) {
      raw[key] = value.toString();
    });

    try {
      var response = await http.put(url, headers: headers, body: raw);
      var data = json.decode(response.body);

      print('Add Lembur Response: $data');
      print('Add Lembur Request: $raw');

      return data;
    } catch (e) {
      print('Error updating profile: $e');
      return {'status': false, 'message': 'Error connecting to server: $e'};
    }
  }

  Future delLembur(String id) async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/lembur/$id');

      try {
        // Add timeout to the HTTP request to prevent long waiting times
        var response = await http
            .delete(url, headers: headers)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw TimeoutException(
                  'The connection has timed out, please try again!',
                );
              },
            );

        var data = json.decode(response.body);
        print('Delete Attendance Response: $data');

        return data;
      } catch (e) {
        print('Error deleting attendance: $e');
        return {
          'status': false,
          'message': e is TimeoutException
              ? e.message
              : 'Error connecting to server: $e',
        };
      }
    });
  }

  //Izin
  Future getIzin({String startDate = '', String endDate = ''}) async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/izin');
      if (startDate != '' && endDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/izin?startDate=$startDate&endDate=$endDate',
        );
      } else if (startDate != '') {
        url = Uri.parse('${this.url}/api/v1/absensi/izin?startDate=$startDate');
      } else if (endDate != '') {
        url = Uri.parse('${this.url}/api/v1/absensi/izin?endDate=$endDate');
      }

      try {
        // Add timeout to the HTTP request to prevent long waiting times
        var response = await http
            .get(url, headers: headers)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'The connection has timed out, please try again!',
                );
              },
            );

        var data = json.decode(response.body);
        print('Get Attendance Response: $data');
        return data;
      } catch (e) {
        print('Error getting attendance data: $e');
        return {
          'status': false,
          'message': e is TimeoutException
              ? e.message
              : 'Error connecting to server: $e',
        };
      }
    });
  }

  Future addIzin(Map<String, String> dataLembur) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/izin');

    // Ensure all values are strings for the API request
    Map<String, String> raw = {};
    dataLembur.forEach((key, value) {
      raw[key] = value.toString();
    });

    try {
      var response = await http.post(url, headers: headers, body: raw);
      var data = json.decode(response.body);

      print('Add Lembur Response: $data');
      print('Add Lembur Request: $raw');

      return data;
    } catch (e) {
      print('Error updating profile: $e');
      return {'status': false, 'message': 'Error connecting to server: $e'};
    }
  }

  Future updateIzin(Map<String, String> dataLembur, String id) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/izin/$id');

    // Ensure all values are strings for the API request
    Map<String, String> raw = {};
    dataLembur.forEach((key, value) {
      raw[key] = value.toString();
    });

    try {
      var response = await http.put(url, headers: headers, body: raw);
      var data = json.decode(response.body);

      print('Add Lembur Response: $data');
      print('Add Lembur Request: $raw');

      return data;
    } catch (e) {
      print('Error updating profile: $e');
      return {'status': false, 'message': 'Error connecting to server: $e'};
    }
  }

  Future delIzin(String id) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/izin/$id');

    try {
      // Add timeout to the HTTP request to prevent long waiting times
      var response = await http
          .delete(url, headers: headers)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'The connection has timed out, please try again!',
              );
            },
          );

      var data = json.decode(response.body);
      print('Delete Attendance Response: $data');

      return data;
    } catch (e) {
      print('Error deleting attendance: $e');
      return {
        'status': false,
        'message': e is TimeoutException
            ? e.message
            : 'Error connecting to server: $e',
      };
    }
  }

  //Sakit
  Future getSakit({String startDate = '', String endDate = ''}) async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/sakit');
      if (startDate != '' && endDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/sakit?startDate=$startDate&endDate=$endDate',
        );
      } else if (startDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/sakit?startDate=$startDate',
        );
      } else if (endDate != '') {
        url = Uri.parse('${this.url}/api/v1/absensi/sakit?endDate=$endDate');
      }

      try {
        // Add timeout to the HTTP request to prevent long waiting times
        var response = await http
            .get(url, headers: headers)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'The connection has timed out, please try again!',
                );
              },
            );

        var data = json.decode(response.body);
        print('Get Attendance Response: $data');
        return data;
      } catch (e) {
        print('Error getting attendance data: $e');
        return {
          'status': false,
          'message': e is TimeoutException
              ? e.message
              : 'Error connecting to server: $e',
        };
      }
    });
  }

  Future addSakit(Map<String, String> dataLembur) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/sakit');

    // Ensure all values are strings for the API request
    Map<String, String> raw = {};
    dataLembur.forEach((key, value) {
      raw[key] = value.toString();
    });

    try {
      var response = await http.post(url, headers: headers, body: raw);
      var data = json.decode(response.body);

      print('Add Lembur Response: $data');
      print('Add Lembur Request: $raw');

      return data;
    } catch (e) {
      print('Error updating profile: $e');
      return {'status': false, 'message': 'Error connecting to server: $e'};
    }
  }

  Future updateSakit(Map<String, String> dataLembur, String id) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/sakit/$id');

    // Ensure all values are strings for the API request
    Map<String, String> raw = {};
    dataLembur.forEach((key, value) {
      raw[key] = value.toString();
    });

    try {
      var response = await http.put(url, headers: headers, body: raw);
      var data = json.decode(response.body);

      print('Add Lembur Response: $data');
      print('Add Lembur Request: $raw');

      return data;
    } catch (e) {
      print('Error updating profile: $e');
      return {'status': false, 'message': 'Error connecting to server: $e'};
    }
  }

  Future delSakit(String id) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/sakit/$id');

    try {
      // Add timeout to the HTTP request to prevent long waiting times
      var response = await http
          .delete(url, headers: headers)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'The connection has timed out, please try again!',
              );
            },
          );

      var data = json.decode(response.body);
      print('Delete Attendance Response: $data');

      return data;
    } catch (e) {
      print('Error deleting attendance: $e');
      return {
        'status': false,
        'message': e is TimeoutException
            ? e.message
            : 'Error connecting to server: $e',
      };
    }
  }

  //Cuti
  Future getTeam() async {
    var url = Uri.parse('${this.url}/api/v1/absensi/team');

    try {
      // Add timeout to the HTTP request to prevent long waiting times
      var response = await http
          .get(url, headers: headers)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'The connection has timed out, please try again!',
              );
            },
          );

      var data = json.decode(response.body);
      print(
        'Get Team Response: $data',
      ); // Updated log message to be more specific
      return data;
    } catch (e) {
      print(
        'Error getting team data: $e',
      ); // Updated error message to be more specific
      return {
        'status': false,
        'message': e is TimeoutException
            ? e.message
            : 'Error connecting to server: $e',
      };
    }
  }

  Future getTeamBirthday() async {
    var url = Uri.parse('${this.url}/api/v1/absensi/team/birthday');

    try {
      // Add timeout to the HTTP request to prevent long waiting times
      var response = await http
          .get(url, headers: headers)
          .timeout(
            const Duration(seconds: 15),
            onTimeout: () {
              throw TimeoutException(
                'The connection has timed out, please try again!',
              );
            },
          );

      var data = json.decode(response.body);
      print(
        'Get Team Response: $data',
      ); // Updated log message to be more specific
      return data;
    } catch (e) {
      print(
        'Error getting team data: $e',
      ); // Updated error message to be more specific
      return {
        'status': false,
        'message': e is TimeoutException
            ? e.message
            : 'Error connecting to server: $e',
      };
    }
  }

  //Cuti
  Future getCuti({String startDate = '', String endDate = ''}) async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/cuti');
      if (startDate != '' && endDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/cuti?startDate=$startDate&endDate=$endDate',
        );
      } else if (startDate != '') {
        url = Uri.parse('${this.url}/api/v1/absensi/cuti?startDate=$startDate');
      } else if (endDate != '') {
        url = Uri.parse('${this.url}/api/v1/absensi/cuti?endDate=$endDate');
      }

      try {
        // Add timeout to the HTTP request to prevent long waiting times
        var response = await http
            .get(url, headers: headers)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'The connection has timed out, please try again!',
                );
              },
            );

        var data = json.decode(response.body);
        print('Get Cuti Response: $data');
        return data;
      } catch (e) {
        print('Error getting cuti data: $e');
        return {
          'status': false,
          'message': e is TimeoutException
              ? e.message
              : 'Error connecting to server: $e',
        };
      }
    });
  }

  Future addCuti(Map<String, String> dataCuti) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/cuti');

    // Ensure all values are strings for the API request
    Map<String, String> raw = {};
    dataCuti.forEach((key, value) {
      raw[key] = value.toString();
    });

    try {
      var response = await http.post(url, headers: headers, body: raw);
      var data = json.decode(response.body);

      print('Add Cuti Response: $data');
      print('Add Cuti Request: $raw');

      return data;
    } catch (e) {
      print('Error adding cuti: $e');
      return {'status': false, 'message': 'Error connecting to server: $e'};
    }
  }

  Future updateCuti(Map<String, String> dataCuti, String id) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/cuti/$id');

    // Ensure all values are strings for the API request
    Map<String, String> raw = {};
    dataCuti.forEach((key, value) {
      raw[key] = value.toString();
    });

    try {
      var response = await http.put(url, headers: headers, body: raw);
      var data = json.decode(response.body);

      print('Update Cuti Response: $data');
      print('Update Cuti Request: $raw');

      return data;
    } catch (e) {
      print('Error updating cuti: $e');
      return {'status': false, 'message': 'Error connecting to server: $e'};
    }
  }

  Future delCuti(String id) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/cuti/$id');

    try {
      // Add timeout to the HTTP request to prevent long waiting times
      var response = await http
          .delete(url, headers: headers)
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException(
                'The connection has timed out, please try again!',
              );
            },
          );

      var data = json.decode(response.body);
      print('Delete Cuti Response: $data');

      return data;
    } catch (e) {
      print('Error deleting cuti: $e');
      return {
        'status': false,
        'message': e is TimeoutException
            ? e.message
            : 'Error connecting to server: $e',
      };
    }
  }

  //approval Lembur
  Future getApprovalLembur({String startDate = '', String endDate = ''}) async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/lembur/approval');
      if (startDate != '' && endDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/lembur/approval?startDate=$startDate&endDate=$endDate',
        );
      } else if (startDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/lembur/approval?startDate=$startDate',
        );
      } else if (endDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/lembur/approval?endDate=$endDate',
        );
      }

      try {
        // Add timeout to the HTTP request to prevent long waiting times
        var response = await http
            .get(url, headers: headers)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'The connection has timed out, please try again!',
                );
              },
            );

        var data = json.decode(response.body);
        print('Get Cuti Response: $data');
        return data;
      } catch (e) {
        print('Error getting cuti data: $e');
        return {
          'status': false,
          'message': e is TimeoutException
              ? e.message
              : 'Error connecting to server: $e',
        };
      }
    });
  }

  Future approvalLemburByHRD(String id, Map<String, String> body) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/lembur/approval-hrd/$id');
    Map<String, String> header = {
      'Authorization': 'Bearer ${user.read('token')}',
      'Accept': 'application/json',
    };

    var response = await http.put(url, headers: header, body: body);
    var data = json.decode(response.body);
    print('Category Response: $data');
    
    print(data);
    return data;
  }

  Future approvalLemburBySupervisor(String id, Map<String, String> body) async {
    var url = Uri.parse(
      '${this.url}/api/v1/absensi/lembur/approval-supervisor/$id',
    );
    Map<String, String> header = {
      'Authorization': 'Bearer ${user.read('token')}',
      'Accept': 'application/json',
    };

    var response = await http.put(url, headers: header, body: body);
    var data = json.decode(response.body);
    print('Category Response: $data');
    
    print(data);
    return data;
  }

  //approval Cuti
  Future getApprovalCuti({String startDate = '', String endDate = ''}) async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/cuti/approval');
      if (startDate != '' && endDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/cuti/approval?startDate=$startDate&endDate=$endDate',
        );
      } else if (startDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/cuti/approval?startDate=$startDate',
        );
      } else if (endDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/cuti/approval?endDate=$endDate',
        );
      }

      try {
        // Add timeout to the HTTP request to prevent long waiting times
        var response = await http
            .get(url, headers: headers)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'The connection has timed out, please try again!',
                );
              },
            );

        var data = json.decode(response.body);
        print('Get Cuti Response: $data');
        return data;
      } catch (e) {
        print('Error getting cuti data: $e');
        return {
          'status': false,
          'message': e is TimeoutException
              ? e.message
              : 'Error connecting to server: $e',
        };
      }
    });
  }

  Future approvalCutiByHRD(String id, Map<String, String> body) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/cuti/approval-hrd/$id');
    Map<String, String> header = {
      'Authorization': 'Bearer ${user.read('token')}',
      'Accept': 'application/json',
    };

    var response = await http.put(url, headers: header, body: body);
    var data = json.decode(response.body);
    print('Category Response: $data');
    
    print(data);
    return data;
  }

  Future approvalCutiBySupervisor(String id, Map<String, String> body) async {
    var url = Uri.parse(
      '${this.url}/api/v1/absensi/cuti/approval-supervisor/$id',
    );
    Map<String, String> header = {
      'Authorization': 'Bearer ${user.read('token')}',
      'Accept': 'application/json',
    };

    var response = await http.put(url, headers: header, body: body);
    var data = json.decode(response.body);
    print('Category Response: $data');
    
    print(data);
    return data;
  }

  //approval Izin
  Future getApprovalIzin({String startDate = '', String endDate = ''}) async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/izin/approval');
      if (startDate != '' && endDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/izin/approval?startDate=$startDate&endDate=$endDate',
        );
      } else if (startDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/izin/approval?startDate=$startDate',
        );
      } else if (endDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/izin/approval?endDate=$endDate',
        );
      }

      try {
        // Add timeout to the HTTP request to prevent long waiting times
        var response = await http
            .get(url, headers: headers)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'The connection has timed out, please try again!',
                );
              },
            );

        var data = json.decode(response.body);
        print('Get Cuti Response: $data');
        return data;
      } catch (e) {
        print('Error getting cuti data: $e');
        return {
          'status': false,
          'message': e is TimeoutException
              ? e.message
              : 'Error connecting to server: $e',
        };
      }
    });
  }

  Future approvalIzinByHRD(String id, Map<String, String> body) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/izin/approval-hrd/$id');
    Map<String, String> header = {
      'Authorization': 'Bearer ${user.read('token')}',
      'Accept': 'application/json',
    };

    var response = await http.put(url, headers: header, body: body);
    var data = json.decode(response.body);
    print('Category Response: $data');
    return data;
  }

  Future approvalIzinBySupervisor(String id, Map<String, String> body) async {
    var url = Uri.parse(
      '${this.url}/api/v1/absensi/izin/approval-supervisor/$id',
    );
    Map<String, String> header = {
      'Authorization': 'Bearer ${user.read('token')}',
      'Accept': 'application/json',
    };

    var response = await http.put(url, headers: header, body: body);
    var data = json.decode(response.body);
    print('Category Response: $data');
    return data;
  }

  //approval Sakit
  Future getApprovalSakit({String startDate = '', String endDate = ''}) async {
    return handleTokenRefreshAndRetry(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/sakit/approval');
      if (startDate != '' && endDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/sakit/approval?startDate=$startDate&endDate=$endDate',
        );
      } else if (startDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/sakit/approval?startDate=$startDate',
        );
      } else if (endDate != '') {
        url = Uri.parse(
          '${this.url}/api/v1/absensi/sakit/approval?endDate=$endDate',
        );
      }

      try {
        // Add timeout to the HTTP request to prevent long waiting times
        var response = await http
            .get(url, headers: headers)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'The connection has timed out, please try again!',
                );
              },
            );

        var data = json.decode(response.body);
        print('Get Cuti Response: $data');
        return data;
      } catch (e) {
        print('Error getting cuti data: $e');
        return {
          'status': false,
          'message': e is TimeoutException
              ? e.message
              : 'Error connecting to server: $e',
        };
      }
    });
  }

  Future approvalSakitByHRD(String id, Map<String, String> body) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/sakit/approval-hrd/$id');
    Map<String, String> header = {
      'Authorization': 'Bearer ${user.read('token')}',
      'Accept': 'application/json',
    };

    var response = await http.put(url, headers: header, body: body);
    var data = json.decode(response.body);
    print('Category Response: $data');
    return data;
  }

  Future approvalSakitBySupervisor(String id, Map<String, String> body) async {
    var url = Uri.parse(
      '${this.url}/api/v1/absensi/sakit/approval-supervisor/$id',
    );
    Map<String, String> header = {
      'Authorization': 'Bearer ${user.read('token')}',
      'Accept': 'application/json',
    };

    var response = await http.put(url, headers: header, body: body);
    var data = json.decode(response.body);
    print('Category Response: $data');
    return data;
  }
}

class MasterApi {
  final url = 'https://dev-api-smartkidz.optimasolution.co.id';
  //url prod
  // final url = 'https://dev-api-smartkidz.optimasolution.co.id';
  // final urlimg = 'https://dev-smartkidz.optimasolution.co.id';
  //  final url = 'http://192.168.1.23:8020/';
  final Api _api = Api(); // Add an instance of Api for token refresh handling

  Map<String, String> headers = {
    'Authorization': 'Bearer ${user.read('token')}',
    'Accept': 'application/json',
  };

  // Helper method to handle token refresh for all MasterApi methods
  Future<Map<String, dynamic>> _handleTokenRefresh(
    Function originalApiCall,
  ) async {
    try {
      // First attempt with current token
      var result = await originalApiCall();
      
      // Only attempt token refresh if it's not the first login
      // and we get a specific token error
      if (result['status'] == false &&
          result['message'] != null &&
          (result['message'].toString().contains('Invalid Token') ||
           result['message'].toString().contains('Expired Token') ||
           result['message'].toString().contains('Token Expired') ||
           (result['code'] != null && result['code'] == 401))) {
        
        // Check if this is the first login attempt
        if (tglLoginLast.read('date') != null) {
          // Not the first login, so try to refresh the token
          return _api.handleTokenRefreshAndRetry(originalApiCall);
        }
      }
      
      // Return the original result
      return result;
    } catch (e) {
      print('Error in _handleTokenRefresh: $e');
      return {'status': false, 'message': 'Error handling API call: $e'};
    }
  }

  Future categoryAbsensi() async {
    return _handleTokenRefresh(() async {
      try {
        var url = Uri.parse('${this.url}/api/v1/absensi/category');
        Map<String, String> header = {
          'Authorization': 'Bearer ${user.read('token')}',
          'Accept': 'application/json',
        };

        var response = await http.get(url, headers: header);
        var data = json.decode(response.body);
        print('Category Response: $data');
        print(data);
        return data;
      } catch (e) {
        print('Error in category: $e');
        return {'status': false, 'message': 'Error fetching categories: $e'};
      }
    });
  }

  Future jenisLembur() async {
    return _handleTokenRefresh(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/jenis-lembur');
      Map<String, String> header = {
        'Authorization': 'Bearer ${user.read('token')}',
        'Accept': 'application/json',
      };

      try {
        var response = await http.get(url, headers: header);
        var data = json.decode(response.body);
        print('Jenis Lembur Response: $data');
        print(data);
        return data;
      } catch (e) {
        print('Error in jenisLembur: $e');
        return {'status': false, 'message': 'Error fetching jenis lembur: $e'};
      }
    });
  }

  Future approvalLembur() async {
    return _handleTokenRefresh(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/approval-lembur');
      Map<String, String> header = {
        'Authorization': 'Bearer ${user.read('token')}',
        'Accept': 'application/json',
      };

      try {
        var response = await http.get(url, headers: header);
        var data = json.decode(response.body);
        print('Approval Lembur Response: $data');
        print(data);
        return data;
      } catch (e) {
        print('Error in approvalLembur: $e');
        return {
          'status': false,
          'message': 'Error fetching approval lembur: $e',
        };
      }
    });
  }

  Future divisi() async {
    return _handleTokenRefresh(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/divisi');

      try {
        // Add timeout to the HTTP request to prevent long waiting times
        var response = await http
            .get(url, headers: headers)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'The connection has timed out, please try again!',
                );
              },
            );

        var data = json.decode(response.body);
        print(
          'Get Divisi Response: $data',
        ); // Updated log message to be more specific
        return data;
      } catch (e) {
        print(
          'Error getting divisi data: $e',
        ); // Updated error message to be more specific
        return {
          'status': false,
          'message': e is TimeoutException
              ? e.message
              : 'Error connecting to server: $e',
        };
      }
    });
  }

  Future jabatan() async {
    return _handleTokenRefresh(() async {
      var url = Uri.parse('${this.url}/api/v1/absensi/jabatan');

      try {
        // Add timeout to the HTTP request to prevent long waiting times
        var response = await http
            .get(url, headers: headers)
            .timeout(
              const Duration(seconds: 15),
              onTimeout: () {
                throw TimeoutException(
                  'The connection has timed out, please try again!',
                );
              },
            );

        var data = json.decode(response.body);
        print(
          'Get Jabatan Response: $data',
        ); // Updated log message to be more specific
        return data;
      } catch (e) {
        print(
          'Error getting jabatan data: $e',
        ); // Updated error message to be more specific
        return {
          'status': false,
          'message': e is TimeoutException
              ? e.message
              : 'Error connecting to server: $e',
        };
      }
    });
  }
}
