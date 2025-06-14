import 'dart:convert';
import 'dart:async';
import 'package:get_storage/get_storage.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:http/http.dart' as http;

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

  Map<String, String> get headers => {
    'Authorization': 'Bearer ${user.read('token')}',
    'Accept': 'application/json',
  };

  Future login(String email, String pass) async {
    var url = Uri.parse('${this.url}/auth/absensi/login');

    var raw = {"email": email, "password": pass};
    var response = await http.post(url,
        headers: {
          'Accept': 'application/json',
        },
        body: raw);
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

    var response = await http.post(
      url,
      headers: headers,
    );
    var data = json.decode(response.body);
    if (data['status'] == true) {
      user.remove('token');
      user.remove('email');
      user.remove('pass');
    }
    print(data);

    return data;
  }

  Future tokenRefresh() async {
      var url = Uri.parse('${this.url}/auth/absensi/refresh');

      var response = await http.post(
        url,
        headers: headers,
      );
      var data = json.decode(response.body);
      if (data['status'] == true) {
        user.remove('token');
         user.write('token', data['data']['access_token']);
      }
      print(data);

      return data;
    }

  Future getProfile() async {
    var url = Uri.parse('${this.url}/api/v1/absensi/profile');

    var response = await http.get(
      url,
      headers: headers,
    );
    var data = json.decode(response.body);
    print(data);
    if(data['status'] == true && data['data'] != null){
      appController.userProfile.changeVal(data['data']);
    }
    

    return data;
  }

  Future updateProfile(Map<String, String> dataUser) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/profile/${appController.userProfile.state['id']}');

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
      return {
        'status': false,
        'message': 'Error connecting to server: $e',
      };
    }
  }

  Future changePass(
    String oldPass,
    String newPass,
    String confPass
  ) async {
    try {
      var url = Uri.parse('${this.url}/api/v1/absensi/reset-password');

      var raw = {
        'old_password': oldPass,
        'new_password': newPass,
        'confirm_password': confPass
      };

      var response = await http.post(url,
          headers: {
            'Accept': 'application/json',
            'Authorization': 'Bearer ${user.read('token')}',
          },
          body: raw);
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
      return {
        'status': false,
        'message': 'Error connecting to server: $e',
      };
    }
  }

  Future getAbsensi(String category, String startDate, String endDate) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/attendance?category=$category');
    if(startDate != '' && startDate != ""){
       url = Uri.parse('${this.url}/api/v1/absensi/attendance?category=$category&startDate=$startDate&endDate=$endDate');
    }
    
    try {
      // Add timeout to the HTTP request to prevent long waiting times
      var response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('The connection has timed out, please try again!');
      });
      
      var data = json.decode(response.body);
      print('Get Attendance Response: $data');
      return data;
    } catch (e) {
      print('Error getting attendance data: $e');
      return {
        'status': false,
        'message': e is TimeoutException ? e.message : 'Error connecting to server: $e',
      };
    }
  }

  Future addAbsensi(Map<String, String> dataAbsen) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/attendance');

    // Ensure all values are strings for the API request
    Map<String, String> raw = {};
    dataAbsen.forEach((key, value) {
      raw[key] = value.toString();
    });

    try {
      var response = await http.post(url, headers: headers, body: raw);
      var data = json.decode(response.body);

      
      print('Update Profile Response: $data');
      print('Update Profile Request: $raw');
      
      return data;
    } catch (e) {
      print('Error updating profile: $e');
      return {
        'status': false,
        'message': 'Error connecting to server: $e',
      };
    }
  }

  Future delAbsensi(String id) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/attendance/$id');

    try {
      // Add timeout to the HTTP request to prevent long waiting times
      var response = await http.delete(url, headers: headers)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('The connection has timed out, please try again!');
      });
      
      var data = json.decode(response.body);
      print('Delete Attendance Response: $data');
      
      return data;
    } catch (e) {
      print('Error deleting attendance: $e');
      return {
        'status': false,
        'message': e is TimeoutException ? e.message : 'Error connecting to server: $e',
      };
    }
  }

  Future getLembur({String startDate = '', String endDate = ''}) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/lembur');
    if(startDate != '' && endDate != ''){
      url = Uri.parse('${this.url}/api/v1/absensi/lembur?startDate=$startDate&endDate=$endDate');
    } else if(startDate != ''){
      url = Uri.parse('${this.url}/api/v1/absensi/lembur?startDate=$startDate');
    } else if(endDate != ''){
      url = Uri.parse('${this.url}/api/v1/absensi/lembur?endDate=$endDate');
    }
    
    try {
      // Add timeout to the HTTP request to prevent long waiting times
      var response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('The connection has timed out, please try again!');
      });
      
      var data = json.decode(response.body);
      print('Get Attendance Response: $data');
      return data;
    } catch (e) {
      print('Error getting attendance data: $e');
      return {
        'status': false,
        'message': e is TimeoutException ? e.message : 'Error connecting to server: $e',
      };
    }
  }

  Future addLembur(Map<String, String> dataLembur) async {
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
      return {
        'status': false,
        'message': 'Error connecting to server: $e',
      };
    }
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
      return {
        'status': false,
        'message': 'Error connecting to server: $e',
      };
    }
  }

  Future delLembur(String id) async {
    var url = Uri.parse('${this.url}/api/v1/absensi/lembur/$id');

    try {
      // Add timeout to the HTTP request to prevent long waiting times
      var response = await http.delete(url, headers: headers)
          .timeout(const Duration(seconds: 10), onTimeout: () {
        throw TimeoutException('The connection has timed out, please try again!');
      });
      
      var data = json.decode(response.body);
      print('Delete Attendance Response: $data');
      
      return data;
    } catch (e) {
      print('Error deleting attendance: $e');
      return {
        'status': false,
        'message': e is TimeoutException ? e.message : 'Error connecting to server: $e',
      };
    }
  }

  Future getTeam() async {
    var url = Uri.parse('${this.url}/api/v1/absensi/team');
    
    try {
      // Add timeout to the HTTP request to prevent long waiting times
      var response = await http.get(
        url,
        headers: headers,
      ).timeout(const Duration(seconds: 15), onTimeout: () {
        throw TimeoutException('The connection has timed out, please try again!');
      });
      
      var data = json.decode(response.body);
      print('Get Attendance Response: $data');
      return data;
    } catch (e) {
      print('Error getting attendance data: $e');
      return {
        'status': false,
        'message': e is TimeoutException ? e.message : 'Error connecting to server: $e',
      };
    }
  }

}

class MasterApi {
  final url = 'https://dev-api-smartkidz.optimasolution.co.id';
  //url prod
  // final url = 'https://dev-api-smartkidz.optimasolution.co.id';
  // final urlimg = 'https://dev-smartkidz.optimasolution.co.id';
  //  final url = 'http://192.168.1.23:8020/';

  Map<String, String> headers = {
    'Authorization': 'Bearer ${user.read('token')}',
    'Accept': 'application/json'
  };

  Future category() async {
    var url = Uri.parse('${this.url}/api/v1/absensi/category');
     Map<String, String> header = {
      'Authorization': 'Bearer ${user.read('token')}',
      'Accept': 'application/json'
    };

    var response = await http.get(url, headers: header);
    var data = json.decode(response.body);
    print('Category Response: $data');
    // var data = {
    //   "status": true,
    //   "message": "Success",
    //   "code": 200,
    //   "data": [
    //     {
    //         "id": 1,
    //         "code": "SKC0001",
    //         "name": "Smartkidz Graha Raya"
    //     },
    //     {
    //         "id": 2,
    //         "code": "SKC0002",
    //         "name": "Smartkidz Kelapa Dua"
    //     },
    //     {
    //         "id": 3,
    //         "code": "SKC0003",
    //         "name": "Smartkidz Spatan"
    //     },
    //     {
    //         "id": 4,
    //         "code": "SKC0004",
    //         "name": "Smartkidz Ceger Raya"
    //     },
    //     {
    //         "id": 5,
    //         "code": "SKC0005",
    //         "name": "Smartkidz Ahmad Yani Tangerang"
    //     },
    //     {
    //         "id": 6,
    //         "code": "SKC0006",
    //         "name": "Smartkidz Grand Batavia"
    //     },
    //     {
    //         "id": 7,
    //         "code": "SKC0007",
    //         "name": "Smartkidz Poris Gaga"
    //     },
    //     {
    //         "id": 8,
    //         "code": "SKC0008",
    //         "name": "Smartkidz Cileduk"
    //     },
    //     {
    //         "id": 9,
    //         "code": "SKC0009",
    //         "name": "Smartkidz Permata Regency"
    //     },
    //     {
    //         "id": 10,
    //         "code": "SKC0010",
    //         "name": "Smartkidz Cipondoh"
    //     },
    //     {
    //         "id": 11,
    //         "code": "SKC0011",
    //         "name": "Smartkidz Karawaci"
    //     },
    //     {
    //         "id": 12,
    //         "code": "SKC0012",
    //         "name": "Smartkidz Semanan"
    //     }
    //   ]
    // };
    // print(data);
    print(data);
    return data;
  }

  Future jenisLembur() async {
    var url = Uri.parse('${this.url}/api/v1/absensi/jenis-lembur');
     Map<String, String> header = {
      'Authorization': 'Bearer ${user.read('token')}',
      'Accept': 'application/json'
    };

    var response = await http.get(url, headers: header);
    var data = json.decode(response.body);
    print('Category Response: $data');
    // var data = {
    //   "status": true,
    //   "message": "Success",
    //   "code": 200,
    //   "data": [
    //     {
    //         "id": 1,
    //         "code": "SKC0001",
    //         "name": "Smartkidz Graha Raya"
    //     },
    //     {
    //         "id": 2,
    //         "code": "SKC0002",
    //         "name": "Smartkidz Kelapa Dua"
    //     },
    //     {
    //         "id": 3,
    //         "code": "SKC0003",
    //         "name": "Smartkidz Spatan"
    //     },
    //     {
    //         "id": 4,
    //         "code": "SKC0004",
    //         "name": "Smartkidz Ceger Raya"
    //     },
    //     {
    //         "id": 5,
    //         "code": "SKC0005",
    //         "name": "Smartkidz Ahmad Yani Tangerang"
    //     },
    //     {
    //         "id": 6,
    //         "code": "SKC0006",
    //         "name": "Smartkidz Grand Batavia"
    //     },
    //     {
    //         "id": 7,
    //         "code": "SKC0007",
    //         "name": "Smartkidz Poris Gaga"
    //     },
    //     {
    //         "id": 8,
    //         "code": "SKC0008",
    //         "name": "Smartkidz Cileduk"
    //     },
    //     {
    //         "id": 9,
    //         "code": "SKC0009",
    //         "name": "Smartkidz Permata Regency"
    //     },
    //     {
    //         "id": 10,
    //         "code": "SKC0010",
    //         "name": "Smartkidz Cipondoh"
    //     },
    //     {
    //         "id": 11,
    //         "code": "SKC0011",
    //         "name": "Smartkidz Karawaci"
    //     },
    //     {
    //         "id": 12,
    //         "code": "SKC0012",
    //         "name": "Smartkidz Semanan"
    //     }
    //   ]
    // };
    // print(data);
    print(data);
    return data;
  }

  Future approvalLembur() async {
    var url = Uri.parse('${this.url}/api/v1/absensi/approval-lembur');
     Map<String, String> header = {
      'Authorization': 'Bearer ${user.read('token')}',
      'Accept': 'application/json'
    };

    var response = await http.get(url, headers: header);
    var data = json.decode(response.body);
    print('Category Response: $data');
    // var data = {
    //   "status": true,
    //   "message": "Success",
    //   "code": 200,
    //   "data": [
    //     {
    //         "id": 1,
    //         "code": "SKC0001",
    //         "name": "Smartkidz Graha Raya"
    //     },
    //     {
    //         "id": 2,
    //         "code": "SKC0002",
    //         "name": "Smartkidz Kelapa Dua"
    //     },
    //     {
    //         "id": 3,
    //         "code": "SKC0003",
    //         "name": "Smartkidz Spatan"
    //     },
    //     {
    //         "id": 4,
    //         "code": "SKC0004",
    //         "name": "Smartkidz Ceger Raya"
    //     },
    //     {
    //         "id": 5,
    //         "code": "SKC0005",
    //         "name": "Smartkidz Ahmad Yani Tangerang"
    //     },
    //     {
    //         "id": 6,
    //         "code": "SKC0006",
    //         "name": "Smartkidz Grand Batavia"
    //     },
    //     {
    //         "id": 7,
    //         "code": "SKC0007",
    //         "name": "Smartkidz Poris Gaga"
    //     },
    //     {
    //         "id": 8,
    //         "code": "SKC0008",
    //         "name": "Smartkidz Cileduk"
    //     },
    //     {
    //         "id": 9,
    //         "code": "SKC0009",
    //         "name": "Smartkidz Permata Regency"
    //     },
    //     {
    //         "id": 10,
    //         "code": "SKC0010",
    //         "name": "Smartkidz Cipondoh"
    //     },
    //     {
    //         "id": 11,
    //         "code": "SKC0011",
    //         "name": "Smartkidz Karawaci"
    //     },
    //     {
    //         "id": 12,
    //         "code": "SKC0012",
    //         "name": "Smartkidz Semanan"
    //     }
    //   ]
    // };
    // print(data);
    print(data);
    return data;
  }



}