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
  final int currentLimit; // [NEW] เพิ่มตัวแปรเก็บจำนวณแถวต่อหน้า

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
    this.currentLimit = 25, // [NEW] ค่าเริ่มต้นเป็น 25
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
    int? currentLimit, // [NEW]
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
      currentLimit: currentLimit ?? this.currentLimit, // [NEW]
    );
  }
}

class PrintDashboardNotifier extends StateNotifier<PrintDashboardState> {
  final PrintRepository _repository = PrintRepository();
  final WindowsPrinterService _printerService = WindowsPrinterService();

  // [REMOVED] ลบ _itemsPerPage ที่เป็นค่าคงที่ออกไป เพื่อใช้ currentLimit ใน State แทน

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
        statusMessage: '❌ ดึงรายชื่อเครื่องพิมพ์ล้มเหลว: $e',
      );
    }
  }

  // [MODIFIED] เพิ่มการรับค่า limit เข้ามาที่ฟังก์ชัน
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
      currentLimit: limit, // [NEW] จดจำค่า limit ที่ผู้ใช้เลือกไว้
    );

    try {
      final response = await _repository.fetchReportData(
        mode: mode,
        startDate: startDate,
        endDate: endDate,
        page: page,
        limit: limit, // [MODIFIED] ส่ง limit เข้า API แทนค่าคงที่
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
        statusMessage: '❌ ข้อผิดพลาด: $e',
      );
    }
  }

  // [MODIFIED] อัปเดตให้ส่งค่า limit เดิมไปเวลาผู้ใช้กดเปลี่ยนหน้า
  void changePage(int newPage) {
    if (newPage > 0 && newPage <= state.totalPages) {
      fetchJobs(
        mode: state.currentMode,
        startDate: state.currentStartDate,
        endDate: state.currentEndDate,
        keyword: state.currentKeyword,
        page: newPage,
        limit: state.currentLimit, // โยน limit ที่จำไว้เข้าไป
      );
    }
  }

  Future<void> printSelectedJobs() async {
    if (state.selectedPrinter == null || state.selectedPrinter!.isEmpty) {
      state = state.copyWith(statusMessage: '❌ กรุณาเลือกเครื่องพิมพ์ก่อนครับ');
      return;
    }

    state = state.copyWith(
      isPrinting: true,
      statusMessage: '⏳ กำลังประมวลผลคำสั่งพิมพ์...',
    );

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

      if (itemsToPrint.isEmpty) {
        throw Exception('ไม่พบข้อมูลที่ต้องการพิมพ์');
      }

      final rawBytes = state.currentMode == 'job'
          ? await Lq310FormBuilder().buildPrintBuffer(itemsToPrint)
          : await Lq310FuelOrderBuilder().buildPrintBuffer(itemsToPrint);

      await _printerService.printRawData(
        printerName: state.selectedPrinter!,
        rawTis620Bytes: rawBytes,
      );

      state = state.copyWith(
        isPrinting: false,
        statusMessage: '✅ ส่งคำสั่งพิมพ์เข้าเครื่องสำเร็จแล้ว!',
        selectedKeys: const {},
      );
    } catch (e) {
      state = state.copyWith(
        isPrinting: false,
        statusMessage: '❌ พิมพ์ล้มเหลว: $e',
      );
    }
  }
}

final dashboardProvider =
    StateNotifierProvider<PrintDashboardNotifier, PrintDashboardState>((ref) {
  return PrintDashboardNotifier();
});
