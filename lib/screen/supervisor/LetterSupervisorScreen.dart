import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart' show BlocBuilder, BlocBase;
import 'package:hr_payroll_smartkidz/controller/app_controller.dart';
import 'package:hr_payroll_smartkidz/controller/letter_controller.dart';
import 'package:hr_payroll_smartkidz/services/api.dart';
import 'package:responsive_builder/responsive_builder.dart';
import 'package:intl/intl.dart';

class LetterSupervisorScreen extends StatefulWidget {
  const LetterSupervisorScreen({super.key});

  @override
  State<LetterSupervisorScreen> createState() => _LetterSupervisorScreenState();
}

class _LetterSupervisorScreenState extends State<LetterSupervisorScreen>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  final Api _api = Api();
  bool _isLoading = false;

  // Data untuk jenis surat
  final List<Map<String, dynamic>> _letterTypeList = [
    {'id': 1, 'name': 'Surat Lembur'},
    {'id': 2, 'name': 'Surat Cuti'},
    {'id': 3, 'name': 'Surat Sakit'},
    {'id': 4, 'name': 'Surat Izin'},
  ];
  bool _isLoadingLetterTypes = false;
  List<Map<String, dynamic>> _approvalData = [];

  @override
  void initState() {
    super.initState();
    _loadLetterCategories();
    _loadApprovalData();
  }

  // Load letter categories
  Future<void> _loadLetterCategories() async {
    setState(() {
      _isLoadingLetterTypes = true;
    });

    try {
      // Menggunakan kategori yang sama dengan letter screen
      appController.letterCategoryLMB.removeAll();
      appController.letterCategoryLMB.addAll(_letterTypeList);
      appController.letterCategoryListMap = List<Map>.from(_letterTypeList);
    } catch (e) {
      print('Error loading letter categories: $e');
      // Use default categories if API fails
      appController.letterCategoryListMap = _letterTypeList;
    } finally {
      setState(() {
        _isLoadingLetterTypes = false;
      });
    }
  }

  // Load approval data from API
  Future<void> _loadApprovalData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Get date filter values from appController
      String startDateStr = appController.tglAwalFilter.state;
      String endDateStr = appController.tglAkhirFilter.state;

      // Set default values if empty
      if (startDateStr.isEmpty) {
        // Default startDate: 1 month ago from today
        final DateTime defaultStartDate = DateTime.now().subtract(
          const Duration(days: 30),
        );
        startDateStr = DateFormat('yyyy-MM-dd').format(defaultStartDate);
        // Update the appController value
        appController.tglAwalFilter.changeVal(startDateStr);
      }

      if (endDateStr.isEmpty) {
        // Default endDate: today
        final DateTime defaultEndDate = DateTime.now();
        endDateStr = DateFormat('yyyy-MM-dd').format(defaultEndDate);
        // Update the appController value
        appController.tglAkhirFilter.changeVal(endDateStr);
      }

      // Get the selected category
      final categories = appController.letterCategoryListMap;

      final selectedIndex = letterController.currentIndexLetter.state;
      if (selectedIndex >= categories.length) {
        print(
          'Error: Selected index $selectedIndex is out of bounds for categories length ${categories.length}',
        );
        return;
      }

      final selectedCategory = categories[selectedIndex]['id'].toString();
      final selectedCategoryName = categories[selectedIndex]['name'];
      print(
        'Loading approval data for category: $selectedCategoryName (ID: $selectedCategory)',
      );
      print('Using date range: $startDateStr to $endDateStr');

      // Load data based on selected category
      Map<String, dynamic> response;
      
      if (selectedCategoryName == 'Surat Lembur') {
        response = await _api.getApprovalLembur(
          startDate: startDateStr,
          endDate: endDateStr,
        );
      } else if (selectedCategoryName == 'Surat Cuti') {
        response = await _api.getApprovalCuti(
          startDate: startDateStr,
          endDate: endDateStr,
        );
      } else if (selectedCategoryName == 'Surat Sakit') {
        response = await _api.getApprovalSakit(
          startDate: startDateStr,
          endDate: endDateStr,
        );
      } else { // Surat Izin
        response = await _api.getApprovalIzin(
          startDate: startDateStr,
          endDate: endDateStr,
        );
      }

      if (response['status'] == true && response['data'] != null) {
        setState(() {
          _approvalData = List<Map<String, dynamic>>.from(response['data']);
        });
      } else {
        setState(() {
          _approvalData = [];
        });
      }
    } catch (e) {
      print('Error loading approval data: $e');
      setState(() {
        _approvalData = [];
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
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
        title: const Text('Approval Surat Supervisor'),
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          const SizedBox(height: 16),
          // Add category selection
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: BlocBuilder<BlocBase<dynamic>, dynamic>(
              bloc: letterController.currentIndexLetter,
              builder: (BuildContext context, dynamic state) {
                // Always use categories from appController, load if empty
                if (appController.letterCategoryListMap.isEmpty) {
                  // Show loading indicator while categories are being loaded
                  return const Center(child: CircularProgressIndicator());
                }
                final categories = appController.letterCategoryListMap;

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: List.generate(
                      categories.length,
                      (index) => Padding(
                        padding: EdgeInsets.only(
                          right: index < categories.length - 1 ? 10 : 0,
                        ),
                        child: GestureDetector(
                          onTap: () {
                            letterController.changeIndexLetter(index);
                            _loadApprovalData(); // Reload data when category changes
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 20,
                            ),
                            decoration: BoxDecoration(
                              color:
                                  letterController.currentIndexLetter.state ==
                                      index
                                  ? const Color(0xFF3A7AFE)
                                  : Theme.of(context).cardColor,
                              borderRadius: BorderRadius.circular(30),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              categories[index]['name'] ?? 'Kategori',
                              style: TextStyle(
                                color:
                                    letterController.currentIndexLetter.state ==
                                        index
                                    ? Colors.white
                                    : Theme.of(
                                        context,
                                      ).textTheme.bodyMedium?.color,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          // Date filter row
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Row(
              children: [
                Expanded(
                  child: BlocBuilder<BlocBase<dynamic>, dynamic>(
                    bloc: appController.tglAwalFilter,
                    builder: (context, state) {
                      return GestureDetector(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              appController.tglAwalFilter.changeVal(
                                picked.toString(),
                              );
                              _loadApprovalData();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                state.isEmpty
                                    ? 'Start Date'
                                    : DateFormat('dd MMM yyyy').format(
                                        DateFormat('yyyy-MM-dd').parse(state),
                                      ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: BlocBuilder<BlocBase<dynamic>, dynamic>(
                    bloc: appController.tglAkhirFilter,
                    builder: (context, state) {
                      return GestureDetector(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime(2030),
                          );
                          if (picked != null) {
                            setState(() {
                              appController.tglAkhirFilter.changeVal(
                                picked.toString(),
                              );
                              _loadApprovalData();
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.calendar_today, size: 16),
                              const SizedBox(width: 8),
                              Text(
                                state.isEmpty
                                    ? 'End Date'
                                    : DateFormat('dd MMM yyyy').format(
                                        DateFormat('yyyy-MM-dd').parse(state),
                                      ),
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Theme.of(
                                    context,
                                  ).textTheme.bodyMedium?.color,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Approval list
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _approvalData.isEmpty
                    ? Center(
                        child: Text(
                          'Tidak ada data approval',
                          style: TextStyle(fontSize: 16),
                        ),
                      )
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: horizontalPadding,
                          vertical: 8,
                        ),
                        itemCount: _approvalData.length,
                        itemBuilder: (context, index) {
                          final approvalItem = _approvalData[index];
                          return ApprovalCard(
                            approval: Map<String, dynamic>.from(approvalItem),
                            onApprove: () => _showApproveConfirmation(
                              context,
                              Map<String, dynamic>.from(approvalItem),
                            ),
                            onReject: () => _showRejectConfirmation(
                              context,
                              Map<String, dynamic>.from(approvalItem),
                            ),
                            onInfo: () => _showInfoDialog(
                              context,
                              Map<String, dynamic>.from(approvalItem),
                            ),
                            getStatusText: _getStatusText,
                            getStatusColor: _getStatusColor,
                            formatDate: _formatDate,
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  // Show info dialog
  Future<void> _showInfoDialog(BuildContext context, Map<String, dynamic> approval) async {
    // Get letter type from the selected category
    final categories = appController.letterCategoryListMap;
    final selectedIndex = letterController.currentIndexLetter.state;
    final selectedCategoryName = categories[selectedIndex]['name'];
    
    // Set letterType in approval data if not already set
    approval['letterType'] = selectedCategoryName;
    
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxWidth: 500,
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _getLetterColor(selectedCategoryName),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(_getLetterIcon(selectedCategoryName), color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Detail $selectedCategoryName',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildInfoRow('Nama', approval['pegawaiNama'] ?? '-'),
                      _buildInfoRow('Jabatan', approval['pegawaiJabatan'] ?? '-'),
                      _buildInfoRow('Divisi', approval['pegawaiDivisi'] ?? '-'),
                      
                      // Informasi spesifik berdasarkan jenis surat
                      if (selectedCategoryName == 'Surat Lembur') ...[                
                        _buildInfoRow('Tanggal Lembur', _formatDate(approval['tanggal'] ?? '-')),
                        _buildInfoRow('Jam Mulai', approval['jamMulai'] ?? '-'),
                        _buildInfoRow('Jam Selesai', approval['jamSelesai'] ?? '-'),
                        _buildInfoRow('Jenis Lembur', _getLemburType(approval['jenisLembur'])),
                        _buildInfoRow('Keperluan', approval['keterangan'] ?? '-'),
                        _buildInfoRow('Tanggal Pengajuan', _formatDate(approval['createdAt'] ?? '-')),
                      ] else if (selectedCategoryName == 'Surat Cuti') ...[                
                        _buildInfoRow('Tanggal Mulai', _formatDate(approval['tanggalMulai'] ?? approval['tanggalAwal'] ?? '-')),
                        _buildInfoRow('Tanggal Selesai', _formatDate(approval['tanggalSelesai'] ?? approval['tanggalAkhir'] ?? '-')),
                        _buildInfoRow('Jumlah Hari', '${approval['jumlahHari'] ?? '-'} hari'),
                        _buildInfoRow('Jenis Cuti', approval['jenisCuti'] ?? '-'),
                        _buildInfoRow('Perihal', approval['keterangan'] ?? '-'),
                      ] else if (selectedCategoryName == 'Surat Sakit') ...[                
                        _buildInfoRow('Tanggal Mulai', _formatDate(approval['tanggalMulai'] ?? approval['tanggalAwal'] ?? '-')),
                        _buildInfoRow('Tanggal Selesai', _formatDate(approval['tanggalSelesai'] ?? approval['tanggalAkhir'] ?? '-')),
                        _buildInfoRow('Jumlah Hari', '${approval['jumlahHari'] ?? '-'} hari'),
                        _buildInfoRow('Keterangan', approval['keterangan'] ?? '-'),
                        
                        // Foto bukti sakit
                        if (approval['foto'] != null && approval['foto'].toString().isNotEmpty) ...[                
                          const SizedBox(height: 16),
                          const Text('Foto Bukti:', style: TextStyle(fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          GestureDetector(
                            onTap: () {
                              // Show full screen image
                              showDialog(
                                context: context,
                                builder: (context) => Dialog(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      AppBar(
                                        title: const Text('Foto Bukti'),
                                        leading: IconButton(
                                          icon: const Icon(Icons.close),
                                          onPressed: () => Navigator.pop(context),
                                        ),
                                      ),
                                      Flexible(
                                        child: InteractiveViewer(
                                          minScale: 0.5,
                                          maxScale: 4.0,
                                          child: Image.memory(
                                            base64Decode(approval['foto']),
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Center(child: Text('Tidak dapat menampilkan gambar'));
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.memory(
                                  base64Decode(approval['foto']),
                                  height: 200,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) {
                                    return const SizedBox(
                                      height: 200,
                                      child: Center(child: Text('Tidak dapat menampilkan gambar')),
                                    );
                                  },
                                ),
                              ),
                            ),
                          ),
                        ],
                      ] else if (selectedCategoryName == 'Surat Izin') ...[                
                        _buildInfoRow('Tanggal Mulai', _formatDate(approval['tanggalMulai'] ?? approval['tanggalAwal'] ?? '-')),
                        _buildInfoRow('Tanggal Selesai', _formatDate(approval['tanggalSelesai'] ?? approval['tanggalAkhir'] ?? '-')),
                        _buildInfoRow('Jumlah Hari', '${approval['jumlahHari'] ?? '-'} hari'),
                        _buildInfoRow('Jenis Izin', approval['jenisIzin'] ?? '-'),
                        _buildInfoRow('Keterangan', approval['keterangan'] ?? '-'),
                      ],
                      
                      const Divider(height: 32),
                      
                      // Status approval
                      const Text('Status Approval:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 8),
                      
                      // Supervisor approval status
                      _buildApprovalStatus(
                        'Supervisor', 
                        approval['namaSupervisor'] ?? (approval['idSupervisor'] != null ? 'Supervisor' : '-'), 
                        _getStatusText(selectedCategoryName == 'Surat Lembur' ? approval['statusSupervisor'] : approval['verifSupervisor']),
                        _getStatusColor(selectedCategoryName == 'Surat Lembur' ? approval['statusSupervisor'] : approval['verifSupervisor']),
                        approval['commentSupervisor'],
                        approval['approvedAtSupervisor'] ?? approval['verifAtSupervisor'],
                      ),
                      
                      const SizedBox(height: 8),
                      
                      // HRD approval status
                      _buildApprovalStatus(
                        'HRD', 
                        approval['namaHrd'] ?? (approval['idHrd'] != null ? 'HRD' : '-'), 
                        _getStatusText(selectedCategoryName == 'Surat Lembur' ? approval['statusHRD'] : approval['verifHrd']),
                        _getStatusColor(selectedCategoryName == 'Surat Lembur' ? approval['statusHRD'] : approval['verifHrd']),
                        approval['commentHrd'],
                        approval['approvedAtHrd'] ?? approval['verifAtHrd'],
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  border: Border(top: BorderSide(color: Colors.grey)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Setujui', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showApproveConfirmation(context, approval);
                      },
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.cancel, color: Colors.white),
                      label: const Text('Tolak', style: TextStyle(color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        _showRejectConfirmation(context, approval);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Show approve confirmation dialog
  Future<void> _showApproveConfirmation(BuildContext context, Map<String, dynamic> approval) async {
    final TextEditingController commentController = TextEditingController();
    
    // Get letter type from the selected category
    final categories = appController.letterCategoryListMap;
    final selectedIndex = letterController.currentIndexLetter.state;
    final selectedCategoryName = categories[selectedIndex]['name'];
    
    bool result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Setujui $selectedCategoryName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anda yakin ingin menyetujui ${approval["pegawaiNama"]} untuk $selectedCategoryName?'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Komentar (opsional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      _performApprove(approval, commentController.text);
    }
  }
  
  // Show reject confirmation dialog
  Future<void> _showRejectConfirmation(BuildContext context, Map<String, dynamic> approval) async {
    final TextEditingController commentController = TextEditingController();
    
    // Get letter type from the selected category
    final categories = appController.letterCategoryListMap;
    final selectedIndex = letterController.currentIndexLetter.state;
    final selectedCategoryName = categories[selectedIndex]['name'];
    
    bool result = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Tolak $selectedCategoryName'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Anda yakin ingin menolak ${approval["pegawaiNama"]} untuk $selectedCategoryName?'),
            const SizedBox(height: 16),
            TextField(
              controller: commentController,
              decoration: const InputDecoration(
                labelText: 'Alasan Penolakan (wajib)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () {
              if (commentController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Alasan penolakan wajib diisi')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Tolak'),
          ),
        ],
      ),
    );
    
    if (result == true) {
      _performReject(approval, commentController.text);
    }
  }
  
  // Perform approve action
  Future<void> _performApprove(Map<String, dynamic> approval, String comment) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get letter type from the selected category
      final categories = appController.letterCategoryListMap;
      final selectedIndex = letterController.currentIndexLetter.state;
      final selectedCategoryName = categories[selectedIndex]['name'];
      
      // Prepare request body
      Map<String, String> body;
      
      if (selectedCategoryName == 'Surat Lembur') {
        body = {
          'status': '2', // 2 for approval
          'comment': comment,
        };
      } else {
        body = {
          'verif': '1', // 1 for approval
          'comment': comment,
        };
      }
      
      // Get approval ID
      String approvalId = approval['id'].toString();
      
      // Call appropriate API based on letter type with token refresh handling
      Map<String, dynamic> response;
      
      if (selectedCategoryName == 'Surat Lembur') {
        response = await _api.handleTokenRefreshAndRetry(() async {
          return await _api.approvalLemburBySupervisor(approvalId, body);
        });
      } else if (selectedCategoryName == 'Surat Cuti') {
        response = await _api.handleTokenRefreshAndRetry(() async {
          return await _api.approvalCutiBySupervisor(approvalId, body);
        });
      } else if (selectedCategoryName == 'Surat Sakit') {
        response = await _api.handleTokenRefreshAndRetry(() async {
          return await _api.approvalSakitBySupervisor(approvalId, body);
        });
      } else { // Surat Izin
        response = await _api.handleTokenRefreshAndRetry(() async {
          return await _api.approvalIzinBySupervisor(approvalId, body);
        });
      }
      
      // Handle response
      if (response['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$selectedCategoryName berhasil disetujui')),
        );
        // Reload data
        _loadApprovalData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menyetujui: ${response['message']}')),
        );
      }
    } catch (e) {
      print('Error approving letter: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Perform reject action
  Future<void> _performReject(Map<String, dynamic> approval, String comment) async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get letter type from the selected category
      final categories = appController.letterCategoryListMap;
      final selectedIndex = letterController.currentIndexLetter.state;
      final selectedCategoryName = categories[selectedIndex]['name'];
      
      // Prepare request body
      Map<String, String> body;
      
      if (selectedCategoryName == 'Surat Lembur') {
        body = {
          'status': '3', // 3 for rejection
          'comment': comment,
        };
      } else {
        body = {
          'verif': '2', // 2 for rejection
          'comment': comment,
        };
      }
      
      // Get approval ID
      String approvalId = approval['id'].toString();
      
      // Call appropriate API based on letter type with token refresh handling
      Map<String, dynamic> response;
      
      if (selectedCategoryName == 'Surat Lembur') {
        response = await _api.handleTokenRefreshAndRetry(() async {
          return await _api.approvalLemburBySupervisor(approvalId, body);
        });
      } else if (selectedCategoryName == 'Surat Cuti') {
        response = await _api.handleTokenRefreshAndRetry(() async {
          return await _api.approvalCutiBySupervisor(approvalId, body);
        });
      } else if (selectedCategoryName == 'Surat Sakit') {
        response = await _api.handleTokenRefreshAndRetry(() async {
          return await _api.approvalSakitBySupervisor(approvalId, body);
        });
      } else { // Surat Izin
        response = await _api.handleTokenRefreshAndRetry(() async {
          return await _api.approvalIzinBySupervisor(approvalId, body);
        });
      }
      
      // Handle response
      if (response['status'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$selectedCategoryName berhasil ditolak')),
        );
        // Reload data
        _loadApprovalData();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal menolak: ${response['message']}')),
        );
      }
    } catch (e) {
      print('Error rejecting letter: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Terjadi kesalahan: $e')),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  // Helper method to build info row
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }
  
  // Helper method to build approval status
  Widget _buildApprovalStatus(String role, String name, String status, Color statusColor, dynamic comment, dynamic approvedAt) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('$role: ', style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(name),
              const Spacer(),
            ],
          ),
          if (approvedAt != null && approvedAt.toString().isNotEmpty) ...[            
            const SizedBox(height: 4),
            Text('Tanggal: ${_formatDateTime(approvedAt.toString())}', style: const TextStyle(fontSize: 12)),
          ],
          if (comment != null && comment.toString().isNotEmpty) ...[            
            const SizedBox(height: 4),
            Text('Komentar: ${comment.toString()}', style: const TextStyle(fontSize: 12)),
          ],
          SizedBox(height: 0.02*MediaQuery.of(context).size.height,),
           Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
        ],
      ),
    );
  }
  
  // Helper method to get letter icon
  IconData _getLetterIcon(String letterType) {
    switch (letterType) {
      case 'Surat Lembur':
        return Icons.access_time;
      case 'Surat Cuti':
        return Icons.beach_access;
      case 'Surat Sakit':
        return Icons.healing;
      case 'Surat Izin':
        return Icons.event_note;
      default:
        return Icons.description;
    }
  }
  
  // Helper method to get letter color
  Color _getLetterColor(String letterType) {
    switch (letterType) {
      case 'Surat Lembur':
        return Colors.orange;
      case 'Surat Cuti':
        return Colors.blue;
      case 'Surat Sakit':
        return Colors.red;
      case 'Surat Izin':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }
  
  // Helper method to get lembur type
  String _getLemburType(dynamic jenisLembur) {
    if (jenisLembur == null) return 'Tidak diketahui';
    
    final jenis = jenisLembur is String ? int.tryParse(jenisLembur) ?? 0 : jenisLembur;
    
    switch (jenis) {
      case 1:
        return 'Lembur Biasa';
      case 2:
        return 'Lembur Hari Libur';
      default:
        return 'Tidak diketahui';
    }
  }
  
  // Helper method to format date time
  String _formatDateTime(String? dateTimeStr) {
    if (dateTimeStr == null || dateTimeStr.isEmpty) return '-';
    try {
      final dateTime = DateTime.parse(dateTimeStr);
      return DateFormat('dd MMM yyyy HH:mm').format(dateTime);
    } catch (e) {
      return dateTimeStr;
    }
  }
  // Helper method to get status text
  String _getStatusText(dynamic status) {
    if (status == null) return 'Menunggu Persetujuan';
    
    // Get letter type from the selected category
    final categories = appController.letterCategoryListMap;
    final selectedIndex = letterController.currentIndexLetter.state;
    final selectedCategoryName = categories[selectedIndex]['name'];
    
    // Konversi status ke integer
    final statusInt = status is String ? int.tryParse(status) ?? 0 : status;
    
    // Logika baru: null/0/1 = pending, 2 = approve, 3 = reject
    switch (statusInt) {
      case 2:
        return 'Disetujui';
      case 3:
        return 'Ditolak';
      case 0:
      case 1:
      default:
        return 'Menunggu Persetujuan';
    }
  }
  
  // Helper method to get status color
  Color _getStatusColor(dynamic status) {
    if (status == null) return Colors.orange;
    
    // Konversi status ke integer
    final statusInt = status is String ? int.tryParse(status) ?? 0 : status;
    
    // Logika baru: null/0/1 = pending (orange), 2 = approve (green), 3 = reject (red)
    switch (statusInt) {
      case 2:
        return Colors.green;
      case 3:
        return Colors.red;
      case 0:
      case 1:
      default:
        return Colors.orange;
    }
  }

  // Helper method to format date
  String _formatDate(String dateStr) {
    if (dateStr == '-') return dateStr;
    try {
      final DateTime date = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateStr;
    }
  }
}

// Approval Card Widget
class ApprovalCard extends StatelessWidget {
  final Map<String, dynamic> approval;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onInfo;
  final String Function(dynamic) getStatusText;
  final Color Function(dynamic) getStatusColor;
  final String Function(String) formatDate;

  const ApprovalCard({
    super.key,
    required this.approval,
    required this.onApprove,
    required this.onReject,
    required this.onInfo,
    required this.getStatusText,
    required this.getStatusColor,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    // Get letter type from the selected category
    final categories = appController.letterCategoryListMap;
    final selectedIndex = letterController.currentIndexLetter.state;
    final selectedCategoryName = categories[selectedIndex]['name'];
    
    // Set letterType in approval data
    approval['letterType'] = selectedCategoryName;
    
    // Determine icon and color based on letter type
    IconData letterIcon;
    Color letterColor;

    switch (selectedCategoryName) {
      case 'Surat Lembur':
        letterIcon = Icons.access_time;
        letterColor = Colors.orange;
        break;
      case 'Surat Cuti':
        letterIcon = Icons.beach_access;
        letterColor = Colors.blue;
        break;
      case 'Surat Sakit':
        letterIcon = Icons.healing;
        letterColor = Colors.red;
        break;
      case 'Surat Izin':
        letterIcon = Icons.event_note;
        letterColor = Colors.purple;
        break;
      default:
        letterIcon = Icons.description;
        letterColor = Colors.grey;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onInfo, // Make the entire card clickable to show details
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: letterColor.withOpacity(0.2),
                    child: Icon(letterIcon, color: letterColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          approval['pegawaiNama'] ?? 'Staff',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          approval['pegawaiJabatan'] ?? 'Employee',
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                        onPressed: onApprove,
                        tooltip: 'Setujui',
                      ),
                      IconButton(
                        icon: const Icon(Icons.cancel, color: Colors.red, size: 24),
                        onPressed: onReject,
                        tooltip: 'Tolak',
                      ),
                      IconButton(
                        icon: const Icon(Icons.info_outline, size: 24),
                        onPressed: onInfo,
                        tooltip: 'Detail',
                      ),
                    ],
                  ),
                ],
              ),
              const Divider(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _infoColumn(
                      context,
                      selectedCategoryName == 'Surat Lembur'
                          ? 'Tanggal'
                          : 'Tanggal Mulai',
                      selectedCategoryName == 'Surat Lembur'
                          ? formatDate(approval['tanggal'] ?? '-')
                          : formatDate(approval['tanggalAwal'] ?? approval['tanggalMulai'] ?? '-'),
                    ),
                  ),
                  Expanded(
                    child: _infoColumn(
                      context,
                      selectedCategoryName == 'Surat Lembur'
                          ? 'Jam'
                          : 'Tanggal Selesai',
                      selectedCategoryName == 'Surat Lembur'
                          ? '${approval['jamMulai'] ?? '-'} - ${approval['jamSelesai'] ?? '-'}'
                          : formatDate(approval['tanggalAkhir'] ?? approval['tanggalSelesai'] ?? '-'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildStatusBadge(
                      context,
                      'Supervisor',
                      selectedCategoryName == 'Surat Lembur' ? 
                        approval['statusSupervisor'] : 
                        approval['verifSupervisor'],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildStatusBadge(
                      context,
                      'HRD',
                      selectedCategoryName == 'Surat Lembur' ? 
                        approval['statusHRD'] : 
                        approval['verifHrd'],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoColumn(BuildContext context, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context, String label, dynamic status) {
    // Get letter type from the selected category
    final categories = appController.letterCategoryListMap;
    final selectedIndex = letterController.currentIndexLetter.state;
    final selectedCategoryName = categories[selectedIndex]['name'];
    
    String statusText = getStatusText(status);
    Color statusColor = getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: statusColor.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 2),
          Text(
            statusText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: statusColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}