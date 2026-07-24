import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

import '../../../services/windows_printer_service.dart';
import '../../utils/print/data/datasources/lq310_form_builder.dart';
import '../../utils/print/data/datasources/lq310_fuel_builder.dart';

class PrintDashboardState {
  final bool isLoading;
  final bool isPrinting;
  final bool isError;
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

  PrintDashboardState({
    this.isLoading = false,
    this.isPrinting = false,
    this.isError = false,
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
  });

  PrintDashboardState copyWith({
    bool? isLoading,
    bool? isPrinting,
    bool? isError,
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
  }) {
    return PrintDashboardState(
      isLoading: isLoading ?? this.isLoading,
      isPrinting: isPrinting ?? this.isPrinting,
      isError: isError ?? this.isError,
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
    );
  }
}

class PrintDashboardNotifier extends StateNotifier<PrintDashboardState> {
  final WindowsPrinterService _printerService = WindowsPrinterService();
  final int _itemsPerPage = 25;

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
      state = state.copyWith(
          isError: true, statusMessage: 'ดึงรายชื่อเครื่องพิมพ์ล้มเหลว: $e');
    }
  }

  Future<void> fetchJobs(String mode, String startDate, String endDate,
      {int page = 1}) async {
    state = state.copyWith(
      isLoading: true,
      isError: false,
      statusMessage: '',
      jobs: [],
      selectedKeys: const {},
      currentMode: mode,
      currentStartDate: startDate,
      currentEndDate: endDate,
    );

    try {
      final String apiUrl = mode == 'job'
          ? 'http://tmsthai.com:9100/mpj-v1/report/job-info'
          : 'http://tmsthai.com:9100/mpj-v1/report/order-fuel';

      final Map<String, dynamic> payload = {
        "job_no": [],
        "start_date": startDate,
        "end_date": endDate,
        "page": page,
        "limit": _itemsPerPage
      };

      final response = await http.post(
        Uri.parse(apiUrl),
        headers: {'Content-Type': 'application/json', 'license': 'mpj'},
        body: jsonEncode([payload]),
      );

      if (response.statusCode != 200) {
        throw Exception('API Error: ${response.statusCode}');
      }

      final List<dynamic> responseData = jsonDecode(response.body);
      if (responseData.isNotEmpty && responseData[0]['status'] == 'success') {
        final List<dynamic> dataList = responseData[0]['data'] ?? [];
        final List<Map<String, dynamic>> typedData =
            List<Map<String, dynamic>>.from(dataList);

        int total = responseData[0]['total'] != null
            ? int.tryParse(responseData[0]['total'].toString()) ?? 0
            : 0;
        int calcTotalPages = 1;

        if (total > 0) {
          calcTotalPages = (total / _itemsPerPage).ceil();
        } else {
          calcTotalPages = dataList.length == _itemsPerPage ? page + 1 : page;
        }

        state = state.copyWith(
          isLoading: false,
          jobs: typedData,
          currentPage: page,
          totalPages: calcTotalPages,
          totalItems: total,
        );
      } else {
        throw Exception('API ส่งสถานะล้มเหลวกลับมา');
      }
    } catch (e) {
      state = state.copyWith(
          isLoading: false,
          isError: true,
          statusMessage: 'ข้อผิดพลาดเครือข่าย: $e');
    }
  }

  void changePage(int newPage) {
    if (newPage > 0 && newPage <= state.totalPages) {
      fetchJobs(state.currentMode, state.currentStartDate, state.currentEndDate,
          page: newPage);
    }
  }

  Future<void> printSelectedJobs(String mode) async {
    if (state.selectedPrinter == null || state.selectedPrinter!.isEmpty) {
      state = state.copyWith(
          isError: true, statusMessage: 'กรุณาเลือกเครื่องพิมพ์ก่อนครับ');
      return;
    }
    state = state.copyWith(
        isPrinting: true,
        isError: false,
        statusMessage: 'กำลังประมวลผลคำสั่งพิมพ์...');
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

      if (itemsToPrint.isEmpty) throw Exception('ไม่พบข้อมูลที่ต้องการพิมพ์');

      final rawBytes = mode == 'job'
          ? await Lq310FormBuilder().buildPrintBuffer(itemsToPrint)
          : await Lq310FuelOrderBuilder().buildPrintBuffer(itemsToPrint);

      await _printerService.printRawData(
          printerName: state.selectedPrinter!, rawTis620Bytes: rawBytes);

      state = state.copyWith(
          isPrinting: false,
          isError: false,
          statusMessage: 'ส่งคำสั่งพิมพ์เข้าเครื่องสำเร็จแล้ว!',
          selectedKeys: const {});
    } catch (e) {
      state = state.copyWith(
          isPrinting: false, isError: true, statusMessage: 'พิมพ์ล้มเหลว: $e');
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<PrintDashboardNotifier, PrintDashboardState>((ref) {
  return PrintDashboardNotifier();
});
