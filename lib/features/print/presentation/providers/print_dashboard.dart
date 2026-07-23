import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/services/windows_printer_service.dart';
import '../../data/datasources/lq310_form_builder.dart';
import '../../data/datasources/tms_remote_datasource.dart';

// --- Providers Setup ---
final tmsDataSourceProvider = Provider((ref) => TmsRemoteDataSource());
final windowsPrinterServiceProvider =
    Provider((ref) => WindowsPrinterService());
final lq310FormBuilderProvider = Provider((ref) => Lq310FormBuilder());

final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  return DashboardNotifier(
    tmsDataSource: ref.read(tmsDataSourceProvider),
    printerService: ref.read(windowsPrinterServiceProvider),
    formBuilder: ref.read(lq310FormBuilderProvider),
  );
});

// --- State Class ---
class DashboardState {
  final bool isLoading;
  final bool isPrinting;
  final List<Map<String, dynamic>> jobs;
  final Set<String> selectedKeys; // เก็บ unique key: job_no_index
  final List<String> availablePrinters;
  final String? selectedPrinter;
  final String statusMessage;
  final bool isError;

  DashboardState({
    this.isLoading = false,
    this.isPrinting = false,
    this.jobs = const [],
    this.selectedKeys = const {},
    this.availablePrinters = const [],
    this.selectedPrinter,
    this.statusMessage = '',
    this.isError = false,
  });

  DashboardState copyWith({
    bool? isLoading,
    bool? isPrinting,
    List<Map<String, dynamic>>? jobs,
    Set<String>? selectedKeys,
    List<String>? availablePrinters,
    String? selectedPrinter,
    String? statusMessage,
    bool? isError,
  }) {
    return DashboardState(
      isLoading: isLoading ?? this.isLoading,
      isPrinting: isPrinting ?? this.isPrinting,
      jobs: jobs ?? this.jobs,
      selectedKeys: selectedKeys ?? this.selectedKeys,
      availablePrinters: availablePrinters ?? this.availablePrinters,
      selectedPrinter: selectedPrinter ?? this.selectedPrinter,
      statusMessage: statusMessage ?? this.statusMessage,
      isError: isError ?? this.isError,
    );
  }
}

// --- Notifier Class ---
class DashboardNotifier extends StateNotifier<DashboardState> {
  final TmsRemoteDataSource tmsDataSource;
  final WindowsPrinterService printerService;
  final Lq310FormBuilder formBuilder;

  DashboardNotifier({
    required this.tmsDataSource,
    required this.printerService,
    required this.formBuilder,
  }) : super(DashboardState()) {
    fetchPrinters();
  }

  /// 1. ค้นหาเครื่องพิมพ์ในระบบ Windows และ Auto-Select LQ-310 / EPSON
  Future<void> fetchPrinters() async {
    try {
      final printers = await printerService.getInstalledPrinters();
      String? defaultPrinter;

      for (final p in printers) {
        final upper = p.toUpperCase();
        if (upper.contains('LQ-310') || upper.contains('EPSON')) {
          defaultPrinter = p;
          break;
        }
      }

      state = state.copyWith(
        availablePrinters: printers,
        selectedPrinter:
            defaultPrinter ?? (printers.isNotEmpty ? printers.first : null),
      );
    } catch (e) {
      state =
          state.copyWith(statusMessage: 'ข้อผิดพลาด Driver: $e', isError: true);
    }
  }

  /// 2. เลือกเปลี่ยนเครื่องพิมพ์
  void setPrinter(String? printerName) {
    state = state.copyWith(selectedPrinter: printerName);
  }

  /// 3. ดึงรายการ Job จาก TMS API
  Future<void> fetchJobs(String startDate, String endDate) async {
    if (startDate.isEmpty || endDate.isEmpty) {
      state = state.copyWith(
          statusMessage: 'กรุณาระบุช่วงวันที่ให้ครบถ้วน', isError: true);
      return;
    }

    state = state.copyWith(
        isLoading: true,
        statusMessage: 'กำลังดึงข้อมูลจาก TMS API...',
        isError: false,
        selectedKeys: {});
    try {
      final jobs = await tmsDataSource.fetchJobOrders(
          startDate: startDate, endDate: endDate);
      if (jobs.isEmpty) {
        state = state.copyWith(
            isLoading: false,
            jobs: [],
            statusMessage: 'ไม่พบข้อมูล Job ในช่วงเวลาดังกล่าว');
      } else {
        state = state.copyWith(
            isLoading: false,
            jobs: jobs,
            statusMessage: 'ดึงข้อมูลสำเร็จ ${jobs.length} รายการ');
      }
    } catch (e) {
      state = state.copyWith(
          isLoading: false,
          statusMessage: e.toString().replaceAll('Exception: ', ''),
          isError: true);
    }
  }

  /// 4. จัดการติ๊กเลือก Checkbox
  void toggleSelection(String uniqueKey) {
    final newSet = Set<String>.from(state.selectedKeys);
    if (newSet.contains(uniqueKey)) {
      newSet.remove(uniqueKey);
    } else {
      newSet.add(uniqueKey);
    }
    state = state.copyWith(selectedKeys: newSet);
  }

  void selectAll(bool select) {
    if (select) {
      final allKeys = {
        for (int i = 0; i < state.jobs.length; i++)
          '${state.jobs[i]['job_no']}_$i'
      };
      state = state.copyWith(selectedKeys: allKeys);
    } else {
      state = state.copyWith(selectedKeys: {});
    }
  }

  /// 5. สั่งแปลงข้อมูลและยิงเข้าท่อเครื่องพิมพ์ Windows Native
  Future<void> printSelectedJobs() async {
    if (state.selectedPrinter == null) {
      state = state.copyWith(
          statusMessage: '❌ กรุณาเลือกเครื่องพิมพ์เป้าหมายก่อนครับ',
          isError: true);
      return;
    }

    final selectedJobs = <Map<String, dynamic>>[];
    for (int i = 0; i < state.jobs.length; i++) {
      final key = '${state.jobs[i]['job_no']}_$i';
      if (state.selectedKeys.contains(key)) {
        selectedJobs.add(state.jobs[i]);
      }
    }

    if (selectedJobs.isEmpty) return;

    state = state.copyWith(
        isPrinting: true,
        statusMessage:
            '⏳ กำลังจัดพิกัดและส่งข้อมูลเข้าหัวเข็ม [${state.selectedPrinter}]...',
        isError: false);

    try {
      // แปลงข้อมูลเป็น TIS-620 Bytes
      final rawBytes = await formBuilder.buildPrintBuffer(selectedJobs);

      // ยิงข้อความดิบเข้า Driver ผ่าน Win32/PowerShell
      await printerService.printRawData(
        printerName: state.selectedPrinter!,
        rawTis620Bytes: rawBytes,
      );

      state = state.copyWith(
        isPrinting: false,
        statusMessage:
            '✅ ยิงพิกัดบิลลงฟอร์มผ่านเครื่อง [${state.selectedPrinter}] สำเร็จเรียบร้อย!',
        isError: false,
        selectedKeys: {}, // ล้างค่าที่เลือกเมื่อพิมพ์สำเร็จ
      );
    } catch (e) {
      state = state.copyWith(
        isPrinting: false,
        statusMessage:
            '❌ การพิมพ์ล้มเหลว: ${e.toString().replaceAll('Exception: ', '')}',
        isError: true,
      );
    }
  }
}
