import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:hr_payroll_smartkidz/components/color_app.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:intl/intl.dart';

class ApprovalList extends StatefulWidget {
  const ApprovalList({super.key});

  @override
  State<ApprovalList> createState() => _ApprovalListState();
}

class _ApprovalListState extends State<ApprovalList> {
  final Api _api = Api();
  bool _isLoading = false;
  List<Map<String, dynamic>> _pendingApprovals = [];

  @override
  void initState() {
    super.initState();
    _loadPendingApprovals();
  }

  Future<void> _loadPendingApprovals() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Ambil data approval yang pending sesuai role
      final response;
      // Jika user adalah HRD, gunakan API getAbsensiLemburApprovalHRD
      response = await _api.getLembur();

      if (response['status'] == true && response['data'] != null) {
        setState(() {
          _pendingApprovals = List<Map<String, dynamic>>.from(response['data']);
        });
      } else {
        // Handle error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to load approvals'),
          ),
        );
      }
    } catch (e) {
      print('Error loading approvals: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _approveOrReject(String id, bool isApproved, String comment) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Cek role user
      final userProfile = appController.userProfile.state;
      final bool isHR =
          userProfile != null &&
          (userProfile['divisiNama'] == 'HR' ||
              userProfile['jabatanNama'] == 'HR');
      final bool isSupervisor =
          userProfile != null &&
          (userProfile['divisiNama'] == 'Supervisor' ||
              userProfile['jabatanNama'] == 'Supervisor');

      // Panggil API untuk approve/reject berdasarkan role
      final response;
      if (isApproved) {
        // Jika approve
        response = await _api.approvalLemburByHRD(id, {
            "status": "1",
            "comment": comment,
          });
           if (response['status'] == true) {
        // Refresh data setelah approve/reject
        await _loadPendingApprovals();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Action completed successfully',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response['message'] ?? 'Failed to process request'),
          ),
        );
      }
          setState(() {
            _isLoading = false;
          });
          return;
        }
       else {
        // Jika reject, perlu implementasi API untuk reject
        // Catatan: API untuk reject belum terlihat di file api.dart
        // Gunakan API yang sesuai jika sudah tersedia
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fitur reject belum tersedia')));
        setState(() {
          _isLoading = false;
        });
        return;
      }
    } catch (e) {
      print('Error processing approval: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _showReasonDialog(String id, bool isApproved) async {
    final TextEditingController reasonController = TextEditingController();
    
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(isApproved ? 'Setujui Lembur' : 'Tolak Lembur'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Masukkan alasan ${isApproved ? "persetujuan" : "penolakan"}:'),
                SizedBox(height: 16),
                TextField(
                  controller: reasonController,
                  decoration: InputDecoration(
                    hintText: 'Alasan',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 3,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Batal'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text(isApproved ? 'Setuju' : 'Tolak'),
              onPressed: () {
                Navigator.of(context).pop();
                _approveOrReject(id, isApproved, reasonController.text);
              },
            ),
          ],
        );
      },
    );
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

  Widget _buildScaffold(
    BuildContext context, {
    bool isTablet = false,
    bool isDesktop = false,
    bool isWatch = false,
  }) {
    final horizontalPadding = isTablet || isDesktop ? 32.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text('Approval List'),
        backgroundColor: ColorApp.lightPrimary,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _pendingApprovals.isEmpty
          ? Center(child: Text('Tidak ada approval yang pending'))
          : RefreshIndicator(
              onRefresh: _loadPendingApprovals,
              child: ListView.builder(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 16,
                ),
                itemCount: _pendingApprovals.length,
                itemBuilder: (context, index) {
                  final approval = _pendingApprovals[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 16),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                approval['name'] ?? 'Staff',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Pending',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          _buildInfoRow('Tanggal', approval['tanggal'] ?? '-'),
                          _buildInfoRow(
                            'Jam',
                            '${approval['jamMulai'] ?? '-'} - ${approval['jamSelesai'] ?? '-'}',
                          ),
                          _buildInfoRow(
                            'Keperluan',
                            approval['keperluan'] ?? '-',
                          ),
                          SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () => _showReasonDialog(
                                  approval['id'].toString(),
                                  false,
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: BorderSide(color: Colors.red),
                                ),
                                child: Text('Tolak'),
                              ),
                              SizedBox(width: 12),
                              ElevatedButton(
                                onPressed: () => _showReasonDialog(
                                  approval['id'].toString(),
                                  true,
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                ),
                                child: Text('Setuju'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text('$label:', style: TextStyle(color: Colors.grey[600])),
          ),
          Expanded(
            child: Text(value, style: TextStyle(fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}
