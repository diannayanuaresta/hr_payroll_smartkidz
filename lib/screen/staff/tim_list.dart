import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:hr_payroll_smartkidz/components/color_app.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hr_payroll_smartkidz/controller/tim_controller.dart';
import 'package:hr_payroll_smartkidz/bloc/list_map_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/custom_bloc.dart';

class TeamListScreen extends StatefulWidget {
  const TeamListScreen({super.key});

  @override
  State<TeamListScreen> createState() => _TeamListScreenState();
}

class _TeamListScreenState extends State<TeamListScreen> {
  String bulkAction = 'Present';
  List<bool> selected = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTeamData();
  }
  
  Future<void> _loadTeamData() async {
    setState(() {
      isLoading = true;
    });
    
    await timController.getTeamData();
    
    // Inisialisasi selected list berdasarkan jumlah data tim
    if (timController.teamListData.state.listDataMap.isNotEmpty) {
      selected = List<bool>.filled(timController.teamListData.state.listDataMap.length, false);
    }
    
    setState(() {
      isLoading = false;
    });
  }

  void applyBulkAction() {
    setState(() {
      for (int i = 0; i < timController.teamListData.state.listDataMap.length; i++) {
        if (selected[i]) {
          // Update status di data tim jika diperlukan
          // Ini hanya contoh, sesuaikan dengan struktur data tim yang sebenarnya
          timController.teamListData.state.listDataMap[i]['status'] = bulkAction == 'Present' ? 'active' : 'inactive';
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout.builder(
      mobile: (context) => buildMainContent(context, fontSize: 14, padding: 12),
      tablet: (context) => buildMainContent(context, fontSize: 16, padding: 24),
      desktop: (context) => buildMainContent(context, fontSize: 18, padding: 32),
      watch: (context) => Scaffold(
        body: Center(
          child: Text('Watch view not supported', style: TextStyle(fontSize: 10)),
        ),
      ),
    );
  }

  Widget buildMainContent(BuildContext context, {double fontSize = 14, double padding = 12}) {
    // Hitung jumlah tim berdasarkan status (jika ada)
    int totalCount = timController.teamListData.state.listDataMap.length;
    int activeCount = timController.teamListData.state.listDataMap
        .where((team) => team['status'] == 'active')
        .length;
    int inactiveCount = totalCount - activeCount;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Expanded(
                child: isLoading
                  ? Center(child: CircularProgressIndicator())
                  : BlocBuilder<ListMapBloc, DataMap>(
                      bloc: timController.teamListData,
                      builder: (context, state) {
                        if (state.listDataMap.isEmpty) {
                          return Center(child: Text('No team data available'));
                        }
                        
                        return ListView.builder(
                          scrollDirection: Axis.vertical,
                          padding: EdgeInsets.all(padding),
                          itemCount: state.listDataMap.length,
                          itemBuilder: (context, index) {
                            final team = state.listDataMap[index];
                            // Menggunakan data sesuai dengan struktur JSON yang diberikan
                            final nama = team['nama'] ?? 'Unknown';
                            final nip = team['nip'] ?? '-';
                            final jabatan = team['jabatan'] ?? 'Tidak ada';
                            final status = team['status'] ?? 'Tidak ada';
                            final isNonGuru = team['isNonGuru'] == true ? 'Non Guru' : 'Guru';
                            
                            return Container(
                              width: MediaQuery.of(context).size.width,
                              height: 0.3*MediaQuery.of(context).size.height,
                              margin: EdgeInsets.only(right: 12),
                              child: Card(
                                elevation: 3,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                child: Padding(
                                  padding: EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            nama,
                                            style: TextStyle(
                                              fontSize: fontSize,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Checkbox(
                                          value: selected.length > index ? selected[index] : false,
                                          onChanged: (val) => setState(() => selected[index] = val!),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        _Tag(label: nip),
                                        const SizedBox(width: 6),
                                        _Tag(label: isNonGuru),
                                      ],
                                    ),
                                    Text(
                                      'Jabatan: ${jabatan}',
                                      style: TextStyle(fontSize: fontSize - 2),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      'Status: ${status ?? "Tidak ada"}',
                                      style: TextStyle(fontSize: fontSize - 2),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        _ActionCard(icon: Icons.edit, label: 'Edit'),
                                        const SizedBox(width: 12),
                                        _ActionCard(icon: Icons.delete, label: 'Delete'),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ));
                          },
                        );
                      },
                    ),
              );
        },
      ),
    );
  }

  Widget statBox(int count, String label, Color color, double fontSize) {
    return Container(
      width: 100,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            count.toString().padLeft(2, '0'),
            style: TextStyle(color: label == 'Present' ? Theme.of(context).colorScheme.secondary : Theme.of(context).colorScheme.error, fontWeight: FontWeight.bold, fontSize: fontSize + 4),
          ),
          Text(label, style: TextStyle(color: Colors.black, fontSize: fontSize)),
        ],
      ),
    );
  }
}

// Model class tidak diperlukan lagi karena kita menggunakan data dari API

class _ActionCard extends StatelessWidget {
  final IconData icon;
  final String label;

  const _ActionCard({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(color: Colors.black12, blurRadius: 2),
            ],
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor, size: 18),
        ),
        const SizedBox(height: 4),
        Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: Theme.of(context).primaryColor, fontSize: 10),
      ),
    );
  }
}
