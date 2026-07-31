import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mpj_job_printer/src/services/windows_printer_service.dart';
import 'package:mpj_job_printer/src/features/utils/print/data/datasources/lq310_form_builder.dart';
import 'package:mpj_job_printer/src/features/utils/print/data/datasources/lq310_fuel_builder.dart';

class PrintDashboardState {
  final bool isLoading;
  final bool isPrinting;
  final String statusMessage;

  final List<Map<String, dynamic>> allJobs;
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
  final bool isDemoMode;

  PrintDashboardState({
    this.isLoading = false,
    this.isPrinting = false,
    this.statusMessage = '',
    this.allJobs = const [],
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
    this.currentLimit = 999999,
    this.isDemoMode = false,
  });

  PrintDashboardState copyWith({
    bool? isLoading,
    bool? isPrinting,
    String? statusMessage,
    List<Map<String, dynamic>>? allJobs,
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
    bool? isDemoMode,
  }) {
    return PrintDashboardState(
      isLoading: isLoading ?? this.isLoading,
      isPrinting: isPrinting ?? this.isPrinting,
      statusMessage: statusMessage ?? this.statusMessage,
      allJobs: allJobs ?? this.allJobs,
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
      isDemoMode: isDemoMode ?? this.isDemoMode,
    );
  }
}

class PrintDashboardNotifier extends StateNotifier<PrintDashboardState> {
  final WindowsPrinterService _printerService = WindowsPrinterService();

  PrintDashboardNotifier() : super(PrintDashboardState()) {
    fetchPrinters();
  }

  String get _baseUrl => state.isDemoMode
      ? 'http://tmsthai.com:9100/mpj-v1' // Demo
      : 'https://tms.mpjdc.com:7049'; // Production

  void setEnvironment(bool isDemo) {
    if (state.isDemoMode == isDemo) return;
    state = state.copyWith(
        isDemoMode: isDemo,
        statusMessage: isDemo
            ? 'เปลี่ยนเป็นโหมด Demo แล้ว'
            : 'เปลี่ยนเป็นโหมด Production แล้ว');

    fetchJobs(
      mode: state.currentMode,
      startDate: state.currentStartDate,
      endDate: state.currentEndDate,
    );
  }

  void setPrinter(String? printerName) {
    state = state.copyWith(selectedPrinter: printerName);
  }

  void toggleSelection(String key) {
    final newKeys = Set<String>.from(state.selectedKeys);
    if (newKeys.contains(key))
      newKeys.remove(key);
    else
      newKeys.add(key);
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

  void _applyLocalFilterAndPagination() {
    List<Map<String, dynamic>> filtered = state.allJobs;
    if (state.currentKeyword.trim().isNotEmpty) {
      final lowerKey = state.currentKeyword.trim().toLowerCase();
      filtered = state.allJobs.where((item) {
        return item.values.any((val) {
          if (val == null) return false;
          return val.toString().toLowerCase().contains(lowerKey);
        });
      }).toList();
    }
    final totalItems = filtered.length;
    final limit = state.currentLimit;

    int totalPages = 1;
    if (limit != 999999 && totalItems > 0) {
      totalPages = (totalItems / limit).ceil();
    }

    int validPage = state.currentPage;
    if (validPage > totalPages) validPage = totalPages;
    if (validPage < 1) validPage = 1;

    List<Map<String, dynamic>> paginatedJobs = filtered;
    if (limit != 999999 && totalItems > 0) {
      final startIndex = (validPage - 1) * limit;
      var endIndex = startIndex + limit;
      if (endIndex > totalItems) endIndex = totalItems;

      if (startIndex < totalItems) {
        paginatedJobs = filtered.sublist(startIndex, endIndex);
      } else {
        paginatedJobs = [];
      }
    }

    state = state.copyWith(
      jobs: paginatedJobs,
      totalItems: totalItems,
      totalPages: totalPages,
      currentPage: validPage,
    );
  }

  void filterLocal(String keyword) {
    state = state.copyWith(
        currentKeyword: keyword, currentPage: 1, selectedKeys: const {});
    _applyLocalFilterAndPagination();
  }

  void changeLimit(int limit) {
    state = state
        .copyWith(currentLimit: limit, currentPage: 1, selectedKeys: const {});
    _applyLocalFilterAndPagination();
  }

  void changePage(int newPage) {
    if (newPage > 0 && newPage <= state.totalPages) {
      state = state.copyWith(currentPage: newPage, selectedKeys: const {});
      _applyLocalFilterAndPagination();
    }
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

  Future<void> fetchJobs({
    required String mode,
    required String startDate,
    required String endDate,
  }) async {
    state = state.copyWith(
      isLoading: true,
      statusMessage: '',
      allJobs: [],
      jobs: [],
      selectedKeys: const {},
      currentMode: mode,
      currentStartDate: startDate,
      currentEndDate: endDate,
      currentPage: 1,
    );

    try {
      final String apiUrl = mode == 'job'
          ? '$_baseUrl/report/order-job'
          : '$_baseUrl/report/order-fuel';

      final List<Map<String, dynamic>> payload = mode == 'job'
          ? [
              {
                "start_date": startDate,
                "end_date": endDate,
                "page": 1,
                "limit": 999999,
                "approve_status": "",
                "cost_status": "",
                "keyword": ""
              }
            ]
          : [
              {
                "job_no": [],
                "start_date": startDate,
                "end_date": endDate,
                "page": 1,
                "limit": 999999
              }
            ];

      final response = await http
          .post(
            Uri.parse(apiUrl),
            headers: {'Content-Type': 'application/json', 'license': 'mpj'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('API Error: ${response.statusCode}');
      }

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      List<dynamic> dataList = [];

      if (decoded is Map && decoded['status'] == 'success') {
        dataList = decoded['data'] ?? [];
      } else if (decoded is List &&
          decoded.isNotEmpty &&
          decoded[0]['status'] == 'success') {
        dataList = decoded[0]['data'] ?? [];
      }

      state = state.copyWith(
        isLoading: false,
        allJobs: List<Map<String, dynamic>>.from(dataList),
      );

      _applyLocalFilterAndPagination();
    } catch (e) {
      state =
          state.copyWith(isLoading: false, statusMessage: '❌ ข้อผิดพลาด: $e');
    }
  }

  Future<List<Map<String, dynamic>>?> getPrintPreviewData(
      String mode, String jobNo) async {
    try {
      final String apiUrl = mode == 'job'
          ? '$_baseUrl/report/job-info'
          : '$_baseUrl/report/order-fuel';
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
          .post(Uri.parse(apiUrl),
              headers: {'Content-Type': 'application/json', 'license': 'mpj'},
              body: jsonEncode(payload))
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200)
        throw Exception('API Error: HTTP ${response.statusCode}');

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      List<dynamic> data = [];
      if (decoded is List &&
          decoded.isNotEmpty &&
          decoded[0]['status'] == 'success')
        data = decoded[0]['data'] ?? [];
      else if (decoded is Map && decoded['status'] == 'success')
        data = decoded['data'] ?? [];

      if (data.isEmpty) throw Exception('ไม่พบข้อมูลรายละเอียดจากระบบ');
      return List<Map<String, dynamic>>.from(data);
    } catch (e) {
      throw Exception(e.toString());
    }
  }

  Future<List<Map<String, dynamic>>?> getBatchPrintPreviewData() async {
    if (state.selectedKeys.isEmpty)
      throw Exception('กรุณาเลือกรายการที่ต้องการพิมพ์');

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

    if (state.currentMode == 'job') {
      final List<String> jobNos = itemsToPrint
          .map((e) => e['job_no']?.toString() ?? '')
          .where((n) => n.isNotEmpty)
          .toList();
      final payload = [
        {
          "job_no": jobNos,
          "start_date": "",
          "end_date": "",
          "page": 1,
          "limit": 999
        }
      ];

      final response = await http
          .post(Uri.parse('$_baseUrl/report/job-info'),
              headers: {'Content-Type': 'application/json', 'license': 'mpj'},
              body: jsonEncode(payload))
          .timeout(const Duration(seconds: 45));
      if (response.statusCode != 200)
        throw Exception('API Error: ${response.statusCode}');

      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      List<dynamic> detailedData = [];
      if (decoded is List &&
          decoded.isNotEmpty &&
          decoded[0]['status'] == 'success')
        detailedData = decoded[0]['data'] ?? [];
      else if (decoded is Map && decoded['status'] == 'success')
        detailedData = decoded['data'] ?? [];

      if (detailedData.isEmpty) throw Exception('ไม่พบรายละเอียดในระบบ');
      return List<Map<String, dynamic>>.from(detailedData);
    } else {
      return itemsToPrint;
    }
  }

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
          statusMessage: '✅ ส่งคำสั่งพิมพ์เข้าเครื่องสำเร็จแล้ว!',
          selectedKeys: const {});
    } catch (e) {
      state = state.copyWith(
          isPrinting: false, statusMessage: '❌ พิมพ์ล้มเหลว: $e');
    }
  }

  Future<void> printSelectedJobs() async {
    if (state.selectedPrinter == null || state.selectedPrinter!.isEmpty) {
      state = state.copyWith(statusMessage: '❌ กรุณาเลือกเครื่องพิมพ์ก่อนครับ');
      return;
    }
    if (state.selectedKeys.isEmpty) {
      state =
          state.copyWith(statusMessage: '❌ กรุณาเลือกรายการที่ต้องการพิมพ์');
      return;
    }

    state = state.copyWith(
        isPrinting: true,
        statusMessage: '⏳ กำลังเตรียมข้อมูลเพื่อสั่งพิมพ์แบบกลุ่ม...');

    try {
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

      Uint8List rawBytes;

      if (state.currentMode == 'job') {
        final List<String> jobNos = itemsToPrint
            .map((e) => e['job_no']?.toString() ?? '')
            .where((n) => n.isNotEmpty)
            .toList();
        state = state.copyWith(
            statusMessage:
                '⏳ กำลังดึงรายละเอียดงาน ${jobNos.length} รายการ...');

        final payload = [
          {
            "job_no": jobNos,
            "start_date": "",
            "end_date": "",
            "page": 1,
            "limit": 999
          }
        ];
        final response = await http
            .post(Uri.parse('$_baseUrl/report/job-info'),
                headers: {'Content-Type': 'application/json', 'license': 'mpj'},
                body: jsonEncode(payload))
            .timeout(const Duration(seconds: 45));

        if (response.statusCode != 200)
          throw Exception('API Error: ${response.statusCode}');

        final decoded = jsonDecode(utf8.decode(response.bodyBytes));
        List<dynamic> detailedData = [];
        if (decoded is List &&
            decoded.isNotEmpty &&
            decoded[0]['status'] == 'success')
          detailedData = decoded[0]['data'] ?? [];
        else if (decoded is Map && decoded['status'] == 'success')
          detailedData = decoded['data'] ?? [];

        if (detailedData.isEmpty) throw Exception('ไม่พบรายละเอียดในระบบ');
        rawBytes = await Lq310FormBuilder()
            .buildPrintBuffer(List<Map<String, dynamic>>.from(detailedData));
      } else {
        rawBytes = await Lq310FuelOrderBuilder().buildPrintBuffer(itemsToPrint);
      }

      state =
          state.copyWith(statusMessage: '⏳ กำลังส่งข้อมูลเข้าเครื่องพิมพ์...');
      await _printerService.printRawData(
          printerName: state.selectedPrinter!, rawTis620Bytes: rawBytes);

      state = state.copyWith(
          isPrinting: false,
          statusMessage:
              '✅ ส่งคำสั่งพิมพ์ทั้ง ${itemsToPrint.length} ใบสำเร็จแล้ว!',
          selectedKeys: const {});
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
