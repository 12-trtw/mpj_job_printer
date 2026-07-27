import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mpj_job_printer/src/services/windows_printer_service.dart';
import 'package:mpj_job_printer/src/features/utils/print/data/datasources/lq310_form_builder.dart';
import 'package:mpj_job_printer/src/features/utils/print/data/datasources/lq310_fuel_builder.dart';
import 'package:mpj_job_printer/src/features/print_dashboard/data/repositories/print_repository.dart';

class PrintDashboardState {
  final bool isLoading;
  final bool isPrinting;
  final String statusMessage;
  final List<Map<String, dynamic>> jobs;
  final Set<String> selectedKeys;
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
    this.selectedKeys = const {},
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
    Set<String>? selectedKeys,
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
      selectedKeys: selectedKeys ?? this.selectedKeys,
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
  final PrintRepository _repository = PrintRepository();
  final WindowsPrinterService _printerService = WindowsPrinterService();

  PrintDashboardNotifier() : super(PrintDashboardState()) {
    fetchPrinters();
  }

  void setPrinter(String? printerName) {
    state = state.copyWith(selectedPrinter: printerName);
  }

  void toggleSelection(String key) {
    final newKeys = Set<String>.from(state.selectedKeys);
    if (newKeys.contains(key)) {
      newKeys.remove(key);
    } else {
      newKeys.add(key);
    }
    state = state.copyWith(selectedKeys: newKeys);
  }

  void selectAll(bool select) {
    if (select) {
      final keys = state.jobs.asMap().entries.map((e) {
        final item = e.value;
        final refId = item['job_no'] ?? item['fleet_id'] ?? e.key.toString();
        return '${refId}_${e.key}';
      }).toSet();
      state = state.copyWith(selectedKeys: keys);
    } else {
      state = state.copyWith(selectedKeys: const {});
    }
  }

  Future<void> fetchPrinters() async {
    try {
      final printers = await _printerService.getInstalledPrinters();

      String? defaultPrinter;
      if (printers.isNotEmpty) {
        try {
          defaultPrinter = printers.firstWhere(
            (p) =>
                p.toUpperCase().contains('LQ-310') ||
                p.toUpperCase().contains('EPSON'),
          );
        } catch (_) {
          defaultPrinter = printers.first;
        }
      }

      state = state.copyWith(
        availablePrinters: printers,
        selectedPrinter: defaultPrinter,
      );
    } catch (e) {
      state = state.copyWith(
        statusMessage: ' ดึงรายชื่อเครื่องพิมพ์ล้มเหลว: $e',
      );
    }
  }

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
      selectedKeys: const {},
      currentMode: mode,
      currentStartDate: startDate,
      currentEndDate: endDate,
      currentKeyword: keyword,
      currentLimit: limit,
    );

    try {
      final response = await _repository.fetchReportData(
        mode: mode,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit,
        keyword: keyword,
      );

      final List<dynamic> dataList = response['data'] ?? [];
      final int totalPages = response['total_pages'] ?? 1;
      final int totalItems = response['total_items'] ?? 0;

      state = state.copyWith(
        isLoading: false,
        jobs: List<Map<String, dynamic>>.from(dataList),
        currentPage: page,
        totalPages: totalPages,
        totalItems: totalItems,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        statusMessage: ' ข้อผิดพลาด: $e',
      );
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

  // [MODIFIED] อัปเดตฟังก์ชันนี้เพื่อดึงข้อมูลจาก job-info ก่อนพิมพ์
  Future<void> printSelectedJobs() async {
    if (state.selectedPrinter == null || state.selectedPrinter!.isEmpty) {
      state = state.copyWith(statusMessage: ' กรุณาเลือกเครื่องพิมพ์ก่อนครับ');
      return;
    }

    state = state.copyWith(
      isPrinting: true,
      statusMessage: '⏳ กำลังเตรียมข้อมูลเพื่อสั่งพิมพ์...',
    );

    try {
      // 1. คัดกรองเอาเฉพาะ Job ที่ผู้ใช้ติ๊กเลือกไว้จากในตาราง
      final itemsToPrint = state.jobs
          .asMap()
          .entries
          .where((e) {
            final refId =
                e.value['job_no'] ?? e.value['fleet_id'] ?? e.key.toString();
            return state.selectedKeys.contains('${refId}_${e.key}');
          })
          .map((e) => e.value)
          .toList();

      if (itemsToPrint.isEmpty) {
        throw Exception('ไม่พบข้อมูลที่ต้องการพิมพ์');
      }

      Uint8List rawBytes;

      if (state.currentMode == 'job') {
        state =
            state.copyWith(statusMessage: '⏳ กำลังดึงข้อมูลรายละเอียด Job...');

        // 2. ดึงเฉพาะรหัส job_no ออกมาเป็น List
        final List<String> jobNos = itemsToPrint
            .map((e) => e['job_no']?.toString() ?? '')
            .where((no) => no.isNotEmpty && no != 'null')
            .toList();

        // 3. ยิง API เส้น job-info เพื่อขอรายละเอียดเชิงลึก
        final response = await http
            .post(
              Uri.parse('http://tmsthai.com:9100/mpj-v1/report/job-info'),
              headers: {'Content-Type': 'application/json', 'license': 'mpj'},
              body: jsonEncode([
                {
                  "job_no": jobNos, // ส่งอาร์เรย์ของ job_no ไปทั้งหมดทีเดียว
                  "start_date": "",
                  "end_date": "",
                  "page": 1,
                  "limit": 999
                }
              ]),
            )
            .timeout(const Duration(seconds: 20)); // ตั้ง Timeout กันค้าง

        if (response.statusCode != 200) {
          throw Exception(
              'เซิร์ฟเวอร์ job-info ตอบกลับผิดพลาด (HTTP ${response.statusCode})');
        }

        final List<dynamic> responseData =
            jsonDecode(utf8.decode(response.bodyBytes));
        if (responseData.isEmpty || responseData[0]['status'] != 'success') {
          throw Exception('API แจ้งเตือน: ไม่สามารถดึงข้อมูลรายละเอียดได้');
        }

        // 4. แปลงข้อมูลที่ได้กลับมา และส่งเข้า Builder ของเรา
        final List<dynamic> detailedDataList = responseData[0]['data'] ?? [];
        final List<Map<String, dynamic>> finalPrintData =
            List<Map<String, dynamic>>.from(detailedDataList);

        if (finalPrintData.isEmpty) {
          throw Exception('ไม่พบข้อมูลรายละเอียดจากระบบ (Data Empty)');
        }

        rawBytes = await Lq310FormBuilder().buildPrintBuffer(finalPrintData);
      } else {
        // สำหรับโหมด Fuel ใชัข้อมูลจากหน้าจอได้เลยไม่ต้องยิงเส้นใหม่
        rawBytes = await Lq310FuelOrderBuilder().buildPrintBuffer(itemsToPrint);
      }

      state =
          state.copyWith(statusMessage: '⏳ กำลังส่งข้อมูลเข้าเครื่องพิมพ์...');

      // 5. สั่งพิมพ์
      await _printerService.printRawData(
        printerName: state.selectedPrinter!,
        rawTis620Bytes: rawBytes,
      );

      state = state.copyWith(
        isPrinting: false,
        statusMessage: ' ส่งคำสั่งพิมพ์เข้าเครื่องสำเร็จแล้ว!',
        selectedKeys: const {},
      );
    } catch (e) {
      state = state.copyWith(
        isPrinting: false,
        statusMessage: ' พิมพ์ล้มเหลว: $e',
      );
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<PrintDashboardNotifier, PrintDashboardState>((ref) {
  return PrintDashboardNotifier();
});
