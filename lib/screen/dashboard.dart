import 'package:flutter/material.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:hr_payroll_smartkidz/screen/staff/attend_list.dart';
import 'package:hr_payroll_smartkidz/screen/staff/document_list.dart';
import 'package:hr_payroll_smartkidz/screen/staff/tim_list.dart';
import 'package:hr_payroll_smartkidz/screen/detail_staff.dart';

class HRMDashboard extends StatelessWidget {
  const HRMDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return ScreenTypeLayout.builder(
      mobile: (context) => _buildScaffold(context, deviceType: DeviceScreenType.mobile),
      tablet: (context) => _buildScaffold(context, deviceType: DeviceScreenType.tablet),
      desktop: (context) => _buildScaffold(context, deviceType: DeviceScreenType.desktop),
    );
  }

  Widget _buildScaffold(BuildContext context, {
    required DeviceScreenType deviceType,
  }) {
    final horizontalPadding = deviceType == DeviceScreenType.desktop || deviceType == DeviceScreenType.tablet ? 32.0 : 16.0;
    final gridCrossAxisCount = deviceType == DeviceScreenType.desktop ? 4 : (deviceType == DeviceScreenType.tablet ? 3 : 2);
    final avatarRadius = deviceType == DeviceScreenType.desktop ? 30.0 : (deviceType == DeviceScreenType.tablet ? 25.0 : 20.0);
    final headerFontSize = deviceType == DeviceScreenType.desktop ? 24.0 : (deviceType == DeviceScreenType.tablet ? 22.0 : 20.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      body: Column(
        children: [
          // Header Section
          Container(
            decoration: const BoxDecoration(
              color: Color(0xFF306EF1),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'HRM &\nPayroll Management',
                  style: TextStyle(
                    fontSize: headerFontSize,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                CircleAvatar(
                  backgroundImage: const NetworkImage(
                    'https://randomuser.me/api/portraits/men/75.jpg',
                  ),
                  radius: avatarRadius,
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Top Grid Menu
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: GridView.count(
              shrinkWrap: true,
              crossAxisCount: gridCrossAxisCount,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.3,
              physics: const NeverScrollableScrollPhysics(),
              children: const [
                _DashboardCardWithImage(
                  imageUrl: 'https://cdn-icons-png.flaticon.com/512/921/921347.png',
                  label: 'Employee\nManagement',
                ),
                _DashboardCardWithImage(
                  imageUrl: 'https://cdn-icons-png.flaticon.com/512/992/992700.png',
                  label: 'Expenses\nManagement',
                ),
                _DashboardCardWithImage(
                  imageUrl: 'https://cdn-icons-png.flaticon.com/512/415/415733.png',
                  label: 'Payroll\nManagement',
                ),
                _DashboardCardWithImage(
                  imageUrl: 'https://cdn-icons-png.flaticon.com/512/2991/2991108.png',
                  label: 'File\nManagement',
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // List Tiles
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              children: [
                _DashboardListTile(title: 'Attendance List', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const AttendanceScreen()));
                }),
                _DashboardListTile(title: 'Employee Details', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const EmployeeDetailScreen()));
                }),
                _DashboardListTile(title: 'Attendance Review', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const TeamListScreen()));
                }),
                _DashboardListTile(title: 'Detail Class', onTap: () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const DocumentList()));
                }),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardCardWithImage extends StatelessWidget {
  final String imageUrl;
  final String label;

  const _DashboardCardWithImage({
    super.key,
    required this.imageUrl,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.network(imageUrl, height: 40, width: 40),
              const SizedBox(height: 10),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardListTile extends StatelessWidget {
  final String title;
  final Function onTap;

  const _DashboardListTile({super.key, required this.title, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
      onTap: () => onTap(),
    );
  }
}
