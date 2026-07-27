import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mpj_job_printer/src/services/windows_printer_service.dart';
import 'package:mpj_job_printer/src/features/utils/print/data/datasources/lq310_form_builder.dart';
import 'package:mpj_job_printer/src/features/utils/print/data/datasources/lq310_fuel_builder.dart';

class PrintDashboardState {
  final bool isLoading;
  final bool isPrinting;
  final String statusMessage;
  final List<Map<String, dynamic>> jobs;
  final List<String> availablePrinters;
  final String? selectedPrinter;

  final int currentPage;
  final int totalPages;
  final int totalItems;
  final String currentMode;
  final String currentStartDate;
  final String currentEndDate;
  final String currentKeyword;
  final int currentLimit;

  PrintDashboardState({
    this.isLoading = false,
    this.isPrinting = false,
    this.statusMessage = '',
    this.jobs = const [],
    this.availablePrinters = const [],
    this.selectedPrinter,
    this.currentPage = 1,
    this.totalPages = 1,
    this.totalItems = 0,
    this.currentMode = 'job',
    this.currentStartDate = '',
    this.currentEndDate = '',
    this.currentKeyword = '',
    this.currentLimit = 25,
  });

  PrintDashboardState copyWith({
    bool? isLoading,
    bool? isPrinting,
    String? statusMessage,
    List<Map<String, dynamic>>? jobs,
    List<String>? availablePrinters,
    String? selectedPrinter,
    int? currentPage,
    int? totalPages,
    int? totalItems,
    String? currentMode,
    String? currentStartDate,
    String? currentEndDate,
    String? currentKeyword,
    int? currentLimit,
  }) {
    return PrintDashboardState(
      isLoading: isLoading ?? this.isLoading,
      isPrinting: isPrinting ?? this.isPrinting,
      statusMessage: statusMessage ?? this.statusMessage,
      jobs: jobs ?? this.jobs,
      availablePrinters: availablePrinters ?? this.availablePrinters,
      selectedPrinter: selectedPrinter ?? this.selectedPrinter,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalItems: totalItems ?? this.totalItems,
      currentMode: currentMode ?? this.currentMode,
      currentStartDate: currentStartDate ?? this.currentStartDate,
      currentEndDate: currentEndDate ?? this.currentEndDate,
      currentKeyword: currentKeyword ?? this.currentKeyword,
      currentLimit: currentLimit ?? this.currentLimit,
    );
  }
}

class PrintDashboardNotifier extends StateNotifier<PrintDashboardState> {
  final WindowsPrinterService _printerService = WindowsPrinterService();

  PrintDashboardNotifier() : super(PrintDashboardState()) {
    fetchPrinters();
  }

  void setPrinter(String? printerName) {
    state = state.copyWith(selectedPrinter: printerName);
  }

  Future<void> fetchPrinters() async {
    try {
      final printers = await _printerService.getInstalledPrinters();
      String? defaultPrinter;
      if (printers.isNotEmpty) {
        try {
          defaultPrinter = printers.firstWhere((p) =>
              p.toUpperCase().contains('LQ-310') ||
              p.toUpperCase().contains('EPSON'));
        } catch (_) {
          defaultPrinter = printers.first;
        }
      }
      state = state.copyWith(
          availablePrinters: printers, selectedPrinter: defaultPrinter);
    } catch (e) {
      state =
          state.copyWith(statusMessage: '❌ ดึงรายชื่อเครื่องพิมพ์ล้มเหลว: $e');
    }
  }

  // --- 1. ฟังก์ชันสำหรับโหลดตาราง (ภาพรวม) ---
  Future<void> fetchJobs({
    required String mode,
    required String startDate,
    required String endDate,
    String keyword = '',
    int page = 1,
    int limit = 25,
  }) async {
    state = state.copyWith(
      isLoading: true,
      statusMessage: '',
      jobs: [],
      currentMode: mode,
      currentStartDate: startDate,
      currentEndDate: endDate,
      currentKeyword: keyword,
      currentLimit: limit,
    );

    try {
      final String apiUrl = mode == 'job'
          ? 'http://tmsthai.com:9100/mpj-v1/report/order-job'
          : 'http://tmsthai.com:9100/mpj-v1/report/order-fuel';

      // โครงสร้าง Payload แยกตามโหมด
      final List<Map<String, dynamic>> payload = mode == 'job'
          ? [
              {
                "start_date": startDate,
                "end_date": endDate,
                "page": page,
                "limit": limit,
                "approve_status": "",
                "cost_status": "",
                "keyword": keyword
              }
            ]
          : [
              {
                "job_no": [],
                "start_date": startDate,
                "end_date": endDate,
                "page": page,
                "limit": limit
              }
            ];

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json', 'license': 'mpj'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200)
        throw Exception('API Error: ${response.statusCode}');

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      List<dynamic> dataList = [];
      int totalPages = 1;
      int totalItems = 0;

      // จัดการโครงสร้าง JSON (order-job เป็น Object ส่วน order-fuel เป็น Array)
      if (decoded is Map && decoded['status'] == 'success') {
        dataList = decoded['data'] ?? [];
        totalPages = decoded['total_pages'] ?? 1;
        totalItems = decoded['total_items'] ?? 0;
      } else if (decoded is List &&
          decoded.isNotEmpty &&
          decoded[0]['status'] == 'success') {
        dataList = decoded[0]['data'] ?? [];
        totalPages = decoded[0]['total_pages'] ?? 1;
        totalItems = decoded[0]['total_items'] ?? 0;
      }

      state = state.copyWith(
        isLoading: false,
        jobs: List<Map<String, dynamic>>.from(dataList),
        currentPage: page,
        totalPages: totalPages,
        totalItems: totalItems,
      );
    } catch (e) {
      state =
          state.copyWith(isLoading: false, statusMessage: '❌ ข้อผิดพลาด: $e');
    }
  }

  void changePage(int newPage) {
    if (newPage > 0 && newPage <= state.totalPages) {
      fetchJobs(
        mode: state.currentMode,
        startDate: state.currentStartDate,
        endDate: state.currentEndDate,
        keyword: state.currentKeyword,
        page: newPage,
        limit: state.currentLimit,
      );
    }
  }

  // --- 2. ฟังก์ชันสำหรับโหลดข้อมูลเชิงลึก (ก่อนสั่งปริ้น) ---
  Future<List<Map<String, dynamic>>?> getPrintPreviewData(
      String mode, String jobNo) async {
    try {
      final String apiUrl = mode == 'job'
          ? 'http://tmsthai.com:9100/mpj-v1/report/job-info'
          : 'http://tmsthai.com:9100/mpj-v1/report/order-fuel';

      final payload = [
        {
          "job_no": [jobNo],
          "start_date": "",
          "end_date": "",
          "page": 1,
          "limit": 25
        }
      ];

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json', 'license': 'mpj'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 15));

      if (response.statusCode != 200)
        throw Exception('API Error: HTTP ${response.statusCode}');

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      List<dynamic> data = [];

      if (decoded is List &&
          decoded.isNotEmpty &&
          decoded[0]['status'] == 'success') {
        data = decoded[0]['data'] ?? [];
      } else if (decoded is Map && decoded['status'] == 'success') {
        data = decoded['data'] ?? [];
      }

      if (data.isEmpty) throw Exception('ไม่พบข้อมูลรายละเอียดจากระบบ');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  // --- 3. ฟังก์ชันสำหรับส่งคำสั่งปริ้นเข้าเครื่อง ---
  Future<void> executePrint(
      String mode, List<Map<String, dynamic>> dataToPrint) async {
    if (state.selectedPrinter == null || state.selectedPrinter!.isEmpty) {
      state = state.copyWith(statusMessage: '❌ กรุณาเลือกเครื่องพิมพ์ก่อนครับ');
      return;
    }

    state = state.copyWith(
        isPrinting: true,
        statusMessage: '⏳ กำลังส่งข้อมูลไปที่เครื่องพิมพ์...');
    try {
      final rawBytes = mode == 'job'
          ? await Lq310FormBuilder().buildPrintBuffer(dataToPrint)
          : await Lq310FuelOrderBuilder().buildPrintBuffer(dataToPrint);

      await _printerService.printRawData(
          printerName: state.selectedPrinter!, rawTis620Bytes: rawBytes);
      state = state.copyWith(
          isPrinting: false,
          statusMessage: '✅ ส่งคำสั่งพิมพ์เข้าเครื่องสำเร็จแล้ว!');
    } catch (e) {
      state = state.copyWith(
          isPrinting: false, statusMessage: '❌ พิมพ์ล้มเหลว: $e');
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<PrintDashboardNotifier, PrintDashboardState>((ref) {
  return PrintDashboardNotifier();
});
