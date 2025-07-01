import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:hr_payroll_smartkidz/components/color_app.dart';
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/custom_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/list_map_bloc.dart';

class ApprovalList extends StatelessWidget {
  const ApprovalList({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the bloc if it doesn't exist
    appController.approvalLemburLMB;
    
    // Create a loading bloc if it doesn't exist
    final loadingBloc = CustomBloc();
    
    // Load data when widget is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPendingApprovals(context, loadingBloc);
    });
    
    return ScreenTypeLayout.builder(
      mobile: (context) => _buildScaffold(context, loadingBloc),
      tablet: (context) => _buildScaffold(context, loadingBloc, isTablet: true),
      desktop: (context) => _buildScaffold(context, loadingBloc, isDesktop: true),
      watch: (context) => _buildScaffold(context, loadingBloc, isWatch: true),
    );
  }
  
  Widget _buildScaffold(
    BuildContext context,
    CustomBloc loadingBloc, {
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
      body: BlocBuilder<CustomBloc, String>(
        bloc: loadingBloc,
        builder: (context, isLoadingState) {
          final bool isLoading = isLoadingState == 'true';
          
          return BlocBuilder<ListMapBloc, DataMap>(
            bloc: appController.approvalLemburLMB,
            builder: (context, state) {
              final pendingApprovals = state.listDataMap;
              
              if (isLoading) {
                return Center(child: CircularProgressIndicator());
              }
              
              if (pendingApprovals.isEmpty) {
                return Center(child: Text('Tidak ada approval yang pending'));
              }
              
              return RefreshIndicator(
                onRefresh: () => _loadPendingApprovals(context, loadingBloc),
                child: ListView.builder(
                  padding: EdgeInsets.symmetric(
                    horizontal: horizontalPadding,
                    vertical: 16,
                  ),
                  itemCount: pendingApprovals.length,
                  itemBuilder: (context, index) {
                    final approval = pendingApprovals[index];
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
                                    context,
                                    approval['id'].toString(),
                                    false,
                                    loadingBloc,
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
                                    context,
                                    approval['id'].toString(),
                                    true,
                                    loadingBloc,
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
              );
            },
          );
        },
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
  
  Future<void> _loadPendingApprovals(BuildContext context, CustomBloc loadingBloc) async {
    loadingBloc.changeVal('true');

    try {
      final Api api = Api();
      // Ambil data approval yang pending sesuai role
      final response = await api.getLembur();

      if (response['status'] == true && response['data'] != null) {
        // Clear existing data and add new data
        appController.approvalLemburLMB.removeAll();
        appController.approvalLemburLMB.addAll(List<Map<String, dynamic>>.from(response['data']));
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
      loadingBloc.changeVal('false');
    }
  }

  Future<void> _approveOrReject(BuildContext context, String id, bool isApproved, String comment, CustomBloc loadingBloc) async {
    try {
      loadingBloc.changeVal('true');

      // Cek role user
      final userProfile = appController.userProfile.state;
      final bool isHR =
          (userProfile['divisiNama'] == 'HR' ||
              userProfile['jabatanNama'] == 'HR');
      final bool isSupervisor =
          (userProfile['divisiNama'] == 'Supervisor' ||
              userProfile['jabatanNama'] == 'Supervisor');

      // Panggil API untuk approve/reject berdasarkan role
      final Api api = Api();
      final response;
      if (isApproved) {
        // Jika approve
        response = await api.approvalLemburByHRD(id, {
            "status": "1",
            "comment": comment,
          });
        if (response['status'] == true) {
          // Refresh data setelah approve/reject
          await _loadPendingApprovals(context, loadingBloc);
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
      } else {
        // Jika reject, perlu implementasi API untuk reject
        // Catatan: API untuk reject belum terlihat di file api.dart
        // Gunakan API yang sesuai jika sudah tersedia
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Fitur reject belum tersedia')));
      }
    } catch (e) {
      print('Error processing approval: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      loadingBloc.changeVal('false');
    }
  }

  Future<void> _showReasonDialog(BuildContext context, String id, bool isApproved, CustomBloc loadingBloc) async {
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
                _approveOrReject(context, id, isApproved, reasonController.text, loadingBloc);
              },
            ),
          ],
        );
      },
    );
  }
}
