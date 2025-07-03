import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hr_payroll_smartkidz/controller/tim_controller.dart';
import 'package:hr_payroll_smartkidz/bloc/list_map_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/custom_bloc.dart';
import 'package:hr_payroll_smartkidz/bloc/count_bloc.dart';

class TeamListScreen extends StatelessWidget {
  const TeamListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize data loading when the screen is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      timController.getTeamData();
    });
    
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
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return BlocBuilder<CustomBloc, String>(
            bloc: timController.reloadTimData,
            builder: (context, loadingState) {
              return Expanded(
                child: loadingState == 'loading'
                  ? Center(child: CircularProgressIndicator())
                  : BlocBuilder<ListMapBloc, DataMap>(
                      bloc: timController.teamListData,
                      builder: (context, state) {
                        if (state.listDataMap.isEmpty) {
                          return Center(child: Text('No team data available'));
                        }
                        
                        // Pisahkan data leader dan member
                        final leader = state.listDataMap.firstWhere(
                          (team) => team['role'] == 'Leader',
                          orElse: () => {},
                        );
                        
                        final members = state.listDataMap.where(
                          (team) => team['role'] == 'Member'
                        ).toList();
                        
                        // Dapatkan daftar anggota tim yang berulang tahun hari ini
                        final birthdayMembers = timController.getBirthdayMembersToday();
                        
                        // Create a BlocBuilder for selected items
                        return BlocBuilder<CountBloc, int>(
                          bloc: timController.currentIndexTim,
                          builder: (context, selectedIndex) {
                            // Create a list to track selected items
                            List<bool> selected = List<bool>.filled(state.listDataMap.length, false);
                            
                            return SingleChildScrollView(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  // Tampilkan container ulang tahun jika ada anggota tim yang berulang tahun hari ini
                                  if (birthdayMembers.isNotEmpty) ...[  
                                    Container(
                                      width: MediaQuery.of(context).size.width * 0.9,
                                      margin: EdgeInsets.all(padding),
                                      padding: EdgeInsets.all(padding),
                                      decoration: BoxDecoration(
                                        color: Colors.amber[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: Colors.amber),
                                      ),
                                      child: Column(
                                        children: [
                                          Row(
                                            children: [
                                              Icon(Icons.cake, color: Colors.amber[800]),
                                              SizedBox(width: 8),
                                              Text(
                                                'Ulang Tahun Hari Ini',
                                                style: TextStyle(
                                                  fontSize: fontSize + 2,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.amber[800],
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 8),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: birthdayMembers.map((member) {
                                              return Padding(
                                                padding: EdgeInsets.symmetric(vertical: 4),
                                                child: Text(
                                                  '${member['nama']} - ${member['jabatan'] ?? 'Anggota Tim'}',
                                                  style: TextStyle(
                                                    fontSize: fontSize,
                                                    color: Colors.amber[900],
                                                  ),
                                                ));
                                              }).toList(),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(height: 16),
                                    ],
                                    
                                    // Tampilkan leader jika ada
                                    if (leader.isNotEmpty) ...[  
                                    Padding(
                                      padding: EdgeInsets.all(padding),
                                      child: Text(
                                        'Team Leader',
                                        style: TextStyle(
                                          fontSize: fontSize + 2,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                    _buildTeamCard(context, leader, 0, fontSize, selected),
                                    SizedBox(height: 16),
                                  ],
                                  
                                  // Tampilkan members
                                  Padding(
                                    padding: EdgeInsets.all(padding),
                                    child: Text(
                                      'Team Members',
                                      style: TextStyle(
                                        fontSize: fontSize + 2,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  ListView.builder(
                                    shrinkWrap: true,
                                    physics: NeverScrollableScrollPhysics(),
                                    padding: EdgeInsets.all(padding),
                                    itemCount: members.length,
                                    itemBuilder: (context, index) {
                                      return _buildTeamCard(context, members[index], index + 1, fontSize, selected);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
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
  
  // Widget untuk menampilkan card tim
  Widget _buildTeamCard(BuildContext context, Map<String, dynamic> team, int index, double fontSize, List<bool> selected) {
    // Menggunakan data sesuai dengan struktur JSON yang diberikan
    final nama = team['nama'] ?? 'Unknown';
    final nip = team['nip'] ?? '-';
    final jabatan = team['jabatan'] ?? 'Tidak ada';
    final status = team['status'] ?? 'Tidak ada';
    final isNonGuru = team['isNonGuru'] == true ? 'Non Guru' : 'Guru';
    final role = team['role'] ?? 'Member';
    
    // Tentukan lebar container berdasarkan role
    final containerWidth = role == 'Leader' 
        ? MediaQuery.of(context).size.width * 0.9 // Leader container lebih kecil
        : MediaQuery.of(context).size.width;
    
    return Center( // Tambahkan Center widget untuk leader
      child: Container(
        width: containerWidth,
        // Change from 0.3 to 0.18 of screen height to make it shorter
        height: 0.18 * MediaQuery.of(context).size.height,
        margin: EdgeInsets.only(bottom: 12, right: role == 'Leader' ? 0 : 12), // Hapus margin kanan untuk leader
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          // Beri warna berbeda untuk leader
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
                    // StatefulBuilder(
                    //   builder: (context, setState) {
                    //     return Checkbox(
                    //       value: selected.length > index ? selected[index] : false,
                    //       onChanged: (val) => setState(() => selected[index] = val!),
                    //     );
                    //   },
                    // ),
                  ],
                ),
                Row(
                  children: [
                    _Tag(label: nip),
                  const SizedBox(width: 6),
                  _Tag(label: isNonGuru),
                  const SizedBox(width: 6),
                  _Tag(
                    label: role,
                    // Warna berbeda untuk leader
                    color: role == 'Leader' ? Colors.amber.withOpacity(0.5) : Theme.of(context).primaryColor.withOpacity(0.5),
                  ),
                  ],
              ),
              Text(
                'Jabatan: $jabatan',
                style: TextStyle(
                  fontSize: fontSize - 2,
                  // Gunakan warna yang lebih kontras untuk mode gelap/terang
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.black87,
                  fontWeight: FontWeight.w500, // Tambahkan ketebalan font
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                'Status: ${status ?? "Tidak ada"}',
                style: TextStyle(
                  fontSize: fontSize - 2,
                  // Gunakan warna yang lebih kontras untuk mode gelap/terang
                  color: Theme.of(context).brightness == Brightness.dark 
                      ? Colors.white 
                      : Colors.black87,
                  fontWeight: FontWeight.w500, // Tambahkan ketebalan font
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              // Row(
              //   mainAxisAlignment: MainAxisAlignment.end,
              //   children: [
              //     _ActionCard(icon: Icons.edit, label: 'Edit'),
              //     const SizedBox(width: 12),
              //     _ActionCard(icon: Icons.delete, label: 'Delete'),
              //   ],
              // ),
        ]  ),
        ),
      ),
    ));
  }

  Widget statBox(BuildContext context, int count, String label, Color color, double fontSize) {
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

// Helper widgets remain unchanged
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
  final Color? color;

  const _Tag({required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    // Tentukan warna latar belakang dan teks berdasarkan mode tema
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDarkMode
        ? (color ?? Theme.of(context).primaryColor).withOpacity(0.3) // Lebih terang di mode gelap
        : (color ?? Theme.of(context).primaryColor).withOpacity(0.1);
    
    final textColor = isDarkMode
        ? Colors.white // Teks putih di mode gelap
        : color ?? Theme.of(context).primaryColor;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        // Tambahkan border untuk meningkatkan kontras
        border: Border.all(
          color: (color ?? Theme.of(context).primaryColor).withOpacity(isDarkMode ? 0.5 : 0.3),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(color: textColor, fontSize: 10, fontWeight: FontWeight.w500),
      ),
    );
  }
}
