import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mpj_job_printer/src/features/presentation/controller/auth_controller.dart';
import 'package:mpj_job_printer/src/features/presentation/controller/print_controller.dart';
import 'login_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _startDateCtrl = TextEditingController();
  final TextEditingController _endDateCtrl = TextEditingController();
  final TextEditingController _keywordCtrl = TextEditingController();

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final sevenDaysAgo = today.subtract(const Duration(days: 7));

    _startDateCtrl.text = DateFormat('yyyy-MM-dd').format(sevenDaysAgo);
    _endDateCtrl.text = DateFormat('yyyy-MM-dd').format(today);
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _keywordCtrl.dispose();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(TextEditingController ctrl) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      ctrl.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  Color _getRowColor(Map<String, dynamic> data) {
    final fleetStatus = data['fleet_status']?.toString();
    if (fleetStatus == '99') return const Color(0xFFF3F4F6);
    if (data['shipto_status']?.toString() == '99') {
      return const Color(0xFFFEF3C7);
    }
    if (fleetStatus == '5') return const Color(0xFFD1FAE5);
    if (fleetStatus == '100') return const Color(0xFFDBEAFE);
    if (fleetStatus == '95') return const Color(0xFFCCFBF1);
    if (fleetStatus == '10') return const Color(0xFFF3E8FF);
    if (fleetStatus == '0' && data['job_end'] != null) {
      try {
        if (DateTime.parse(data['job_end'].toString())
            .isBefore(DateTime.now())) {
          return const Color(0xFFFEE2E2);
        }
      } catch (_) {}
    }
    return const Color(0xFFFDE68A).withOpacity(0.3);
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null ||
        dateString.isEmpty ||
        dateString.startsWith('0000-00-00')) return '-';
    try {
      return DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(dateString));
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);

    final authState = ref.watch(authProvider);
    final displayName =
        (authState.employeeName != null && authState.employeeName!.isNotEmpty)
            ? authState.employeeName!
            : (authState.username ?? 'ผู้ใช้งานระบบ');

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 55,
            color: const Color(0xFFF97316),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Icon(Icons.apps, color: Colors.white),
                const SizedBox(width: 12),
                const Text('Plan Report - Print Management',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.account_circle,
                          color: Colors.white, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        displayName,
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Tooltip(
                  message: 'ออกจากระบบ',
                  child: InkWell(
                    onTap: () {
                      ref.read(authProvider.notifier).logout();
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const LoginScreen()),
                      );
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: Colors.white.withOpacity(0.5), width: 1),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.logout, color: Colors.white, size: 16),
                          SizedBox(width: 6),
                          Text(
                            'Logout',
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (state.isDemoMode) ...[
                  const SizedBox(width: 16),
                  Container(
                      width: 1,
                      height: 24,
                      color: Colors.white.withOpacity(0.5)),
                  const SizedBox(width: 16),
                  Container(
                    margin: const EdgeInsets.only(right: 16),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.red.shade600,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white, width: 1)),
                    child: const Text('DEMO MODE',
                        style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13)),
                  ),
                  PopupMenuButton<bool>(
                    icon: const Icon(Icons.settings, color: Colors.white),
                    tooltip: 'ตั้งค่า',
                    offset: const Offset(0, 45),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    onSelected: (bool isDemo) {
                      notifier.setEnvironment(isDemo);
                    },
                    itemBuilder: (BuildContext context) => [
                      PopupMenuItem<bool>(
                        value: false,
                        child: Row(
                          children: [
                            Icon(Icons.rocket_launch,
                                color: !state.isDemoMode
                                    ? Colors.green
                                    : Colors.grey,
                                size: 20),
                            const SizedBox(width: 12),
                            Text('Production',
                                style: TextStyle(
                                    fontWeight: !state.isDemoMode
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 16)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(),
                      PopupMenuItem<bool>(
                        value: true,
                        child: Row(
                          children: [
                            Icon(Icons.bug_report,
                                color:
                                    state.isDemoMode ? Colors.red : Colors.grey,
                                size: 20),
                            const SizedBox(width: 12),
                            Text('Demo',
                                style: TextStyle(
                                    fontWeight: state.isDemoMode
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 16)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(width: 8),
              ],
            ),
          ),
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  boxShadow: [
                    BoxShadow(
                        color: Colors.black.withOpacity(0.05), blurRadius: 4)
                  ]),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                _buildModeButton(
                                  title: '📋 รายการ ORDER',
                                  color: const Color(0xFF8B5CF6),
                                  isSelected: state.currentMode == 'order',
                                  onTap: () {
                                    if (state.currentMode == 'order') return;
                                    notifier.fetchJobs(
                                      mode: 'order',
                                      startDate: _startDateCtrl.text,
                                      endDate: _endDateCtrl.text,
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                _buildModeButton(
                                  title: '📋 รายการ JOB',
                                  color: const Color(0xFF2563EB),
                                  isSelected: state.currentMode == 'job',
                                  onTap: () {
                                    if (state.currentMode == 'job') return;
                                    notifier.fetchJobs(
                                      mode: 'job',
                                      startDate: _startDateCtrl.text,
                                      endDate: _endDateCtrl.text,
                                    );
                                  },
                                ),
                                const SizedBox(width: 12),
                                _buildModeButton(
                                  title: '⛽ รายการเติมน้ำมัน',
                                  color: const Color(0xFF10B981),
                                  isSelected: state.currentMode == 'fuel',
                                  onTap: () {
                                    if (state.currentMode == 'fuel') return;
                                    notifier.fetchJobs(
                                      mode: 'fuel',
                                      startDate: _startDateCtrl.text,
                                      endDate: _endDateCtrl.text,
                                    );
                                  },
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.print,
                                    color: Colors.grey, size: 20),
                                const SizedBox(width: 8),
                                Container(
                                  height: 35,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: state.selectedPrinter,
                                      hint: const Text('เลือกเครื่องพิมพ์...'),
                                      items: state.availablePrinters
                                          .map((p) => DropdownMenuItem(
                                              value: p,
                                              child: Text(p,
                                                  style: const TextStyle(
                                                      fontSize: 13))))
                                          .toList(),
                                      onChanged: notifier.setPrinter,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFF97316),
                                      foregroundColor: Colors.white,
                                      fixedSize: const Size.fromHeight(35)),
                                  onPressed: (state.selectedKeys.isEmpty ||
                                          state.isPrinting)
                                      ? null
                                      : () =>
                                          _showBatchPreviewAndPrint(notifier),
                                  icon: state.isPrinting
                                      ? const SizedBox(
                                          width: 16,
                                          height: 16,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.print, size: 16),
                                  label: Text(
                                      'ปริ้นที่เลือก (${state.selectedKeys.length})',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            _buildDateInput(_startDateCtrl, 'ตั้งแต่วันที่'),
                            const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text('-')),
                            _buildDateInput(_endDateCtrl, 'ถึงวันที่'),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  foregroundColor: Colors.white,
                                  fixedSize: const Size.fromHeight(35)),
                              onPressed: state.isLoading
                                  ? null
                                  : () {
                                      notifier.fetchJobs(
                                        mode: state.currentMode,
                                        startDate: _startDateCtrl.text,
                                        endDate: _endDateCtrl.text,
                                      );
                                    },
                              icon: const Icon(Icons.filter_alt, size: 16),
                              label: const Text('ดึงข้อมูลตามวันที่',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 250,
                              height: 35,
                              child: TextField(
                                controller: _keywordCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'ค้นหาในตาราง (Real-time)...',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.search, size: 18)),
                                style: const TextStyle(fontSize: 13),
                                onChanged: (val) => notifier.filterLocal(val),
                                onSubmitted: (val) => notifier.filterLocal(val),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  fixedSize: const Size.fromHeight(35)),
                              onPressed: () =>
                                  notifier.filterLocal(_keywordCtrl.text),
                              icon: const Icon(Icons.search, size: 16),
                              label: const Text('ค้นหา',
                                  style:
                                      TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        if (state.statusMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(state.statusMessage,
                                style: TextStyle(
                                    color: state.statusMessage.contains('❌')
                                        ? Colors.red
                                        : Colors.green,
                                    fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                  ),
                  Expanded(
                    child: state.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : state.jobs.isEmpty
                            ? const Center(
                                child: Text('ไม่มีข้อมูล',
                                    style: TextStyle(color: Colors.grey)))
                            : Scrollbar(
                                controller: _horizontalScrollController,
                                thumbVisibility: true,
                                trackVisibility: true,
                                child: SingleChildScrollView(
                                  controller: _horizontalScrollController,
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: state.currentMode == 'job'
                                        ? 2500
                                        : (state.currentMode == 'order'
                                            ? 1900
                                            : 1150),
                                    child: Column(
                                      children: [
                                        _buildTableHeader(state, notifier),
                                        Expanded(
                                          child: Scrollbar(
                                            controller:
                                                _verticalScrollController,
                                            thumbVisibility: true,
                                            trackVisibility: true,
                                            child: ListView.builder(
                                              controller:
                                                  _verticalScrollController,
                                              itemCount: state.jobs.length,
                                              itemBuilder: (context, index) {
                                                final item = state.jobs[index];
                                                final rowColor =
                                                    _getRowColor(item);

                                                final refId = item['job_no']
                                                        ?.toString() ??
                                                    item['order_number']
                                                        ?.toString() ??
                                                    item['fleet_id']
                                                        ?.toString() ??
                                                    '';

                                                final uniqueKey =
                                                    refId.isNotEmpty
                                                        ? refId
                                                        : index.toString();
                                                final isSelected = state
                                                    .selectedKeys
                                                    .contains(uniqueKey);

                                                if (state.currentMode ==
                                                    'job') {
                                                  return _buildJobInfoRow(
                                                      context,
                                                      item,
                                                      rowColor,
                                                      notifier,
                                                      uniqueKey,
                                                      isSelected,
                                                      refId);
                                                } else if (state.currentMode ==
                                                    'order') {
                                                  return _buildOrderRow(
                                                      context,
                                                      item,
                                                      rowColor,
                                                      notifier,
                                                      uniqueKey,
                                                      isSelected,
                                                      refId);
                                                } else {
                                                  return _buildFuelRow(
                                                      context,
                                                      item,
                                                      rowColor,
                                                      notifier,
                                                      uniqueKey,
                                                      isSelected,
                                                      refId);
                                                }
                                              },
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                  ),
                  if (state.allJobs.isNotEmpty && !state.isLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 16),
                      decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(color: Colors.grey.shade300))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('Show ',
                                  style: TextStyle(fontSize: 13)),
                              Container(
                                height: 28,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 8),
                                decoration: BoxDecoration(
                                    border:
                                        Border.all(color: Colors.grey.shade400),
                                    borderRadius: BorderRadius.circular(4)),
                                child: DropdownButtonHideUnderline(
                                  child: DropdownButton<int>(
                                    value: state.currentLimit,
                                    items: [10, 25, 50, 100, 999999]
                                        .map((v) => DropdownMenuItem(
                                            value: v,
                                            child: Text(
                                                v == 999999 ? 'ALL' : '$v',
                                                style: const TextStyle(
                                                    fontSize: 13))))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        notifier.changeLimit(val);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              Text(' entries (Total: ${state.totalItems})',
                                  style: const TextStyle(fontSize: 13)),
                            ],
                          ),
                          Row(
                            children: [
                              OutlinedButton(
                                onPressed: state.currentPage > 1
                                    ? () => notifier
                                        .changePage(state.currentPage - 1)
                                    : null,
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(60, 32)),
                                child: const Text('Prev'),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: Text(
                                    '${state.currentPage} / ${state.totalPages}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                              ),
                              OutlinedButton(
                                onPressed: state.currentPage < state.totalPages
                                    ? () => notifier
                                        .changePage(state.currentPage + 1)
                                    : null,
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(60, 32)),
                                child: const Text('Next'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPreviewAndPrint(
      String? refId, PrintDashboardNotifier notifier) async {
    if (refId == null || refId.isEmpty) return;
    final state = ref.read(dashboardProvider);
    if (state.selectedPrinter == null || state.selectedPrinter!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรุณาเลือกเครื่องพิมพ์ก่อนครับ'),
          backgroundColor: Colors.red));
      return;
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final previewData =
          await notifier.getPrintPreviewData(state.currentMode, refId);
      if (!mounted) return;
      Navigator.pop(context);

      if (previewData == null || previewData.isEmpty) {
        throw Exception('ไม่พบข้อมูลสำหรับปริ้น');
      }
      final detail = previewData.first;
      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.print, color: Color(0xFFF97316)),
                    const SizedBox(width: 8),
                    Text('ตัวอย่างข้อมูลก่อนพิมพ์ - $refId',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                content: SizedBox(
                  width: 400,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _previewText('เครื่องพิมพ์:', state.selectedPrinter,
                          isHighlight: true),
                      const Divider(),
                      _previewText('ประเภทงาน:', detail['type_name']),
                      _previewText('ทะเบียนรถ:', detail['vehicle_name']),
                      _previewText(
                          'คนขับ:', detail['driver_name'] ?? detail['driver']),
                      _previewText('ลูกค้า:', detail['customer_name']),
                      if (state.currentMode == 'fuel')
                        _previewText(
                            'ปริมาณน้ำมัน:', '${detail['fuel_qty'] ?? 0} ลิตร'),
                      if (state.currentMode == 'job' ||
                          state.currentMode == 'order')
                        _previewText('เบอร์ตู้:',
                            '${detail['container_size'] ?? ''} ${detail['container_no'] ?? ''}'),
                      const SizedBox(height: 16),
                      const Text('ตรวจสอบความถูกต้องแล้วกด "ยืนยันสั่งพิมพ์"',
                          style: TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ยกเลิก',
                          style: TextStyle(color: Colors.grey))),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.pop(ctx);
                      final currentUsername =
                          ref.read(authProvider).username ?? '';
                      notifier.executePrint(state.currentMode, previewData,
                          username: currentUsername);
                    },
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('ยืนยันสั่งพิมพ์'),
                  )
                ],
              ));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  void _showBatchPreviewAndPrint(PrintDashboardNotifier notifier) async {
    final currentUsername = ref.read(authProvider).username ?? '';
    final state = ref.read(dashboardProvider);
    if (state.selectedPrinter == null || state.selectedPrinter!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรุณาเลือกเครื่องพิมพ์ก่อนครับ'),
          backgroundColor: Colors.red));
      return;
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final previewData = await notifier.getBatchPrintPreviewData();
      if (!mounted) return;
      Navigator.pop(context);

      if (previewData == null || previewData.isEmpty) {
        throw Exception('ไม่พบข้อมูลสำหรับปริ้น');
      }

      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.print, color: Color(0xFFF97316)),
                    const SizedBox(width: 8),
                    Text('ตัวอย่างก่อนพิมพ์ (${previewData.length} รายการ)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 18)),
                  ],
                ),
                content: SizedBox(
                  width: 500,
                  height: 400,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'รายการต่อไปนี้จะถูกส่งเข้าเครื่องพิมพ์ตามลำดับ:',
                          style: TextStyle(fontSize: 14)),
                      const SizedBox(height: 8),
                      Text('🖨️ เครื่องพิมพ์ปลายทาง: ${state.selectedPrinter}',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF2563EB))),
                      const SizedBox(height: 12),
                      Expanded(
                        child: ListView.builder(
                          itemCount: previewData.length,
                          itemBuilder: (context, index) {
                            final detail = previewData[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 8),
                              child: Padding(
                                padding: const EdgeInsets.all(12.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                        'Job No: ${detail['job_no'] ?? detail['order_number']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16)),
                                    const SizedBox(height: 4),
                                    Text(
                                        'ทะเบียนรถ: ${detail['vehicle_name'] ?? '-'} | คนขับ: ${detail['driver_name'] ?? detail['driver'] ?? '-'}',
                                        style: const TextStyle(fontSize: 14)),
                                    if (state.currentMode == 'job' ||
                                        state.currentMode == 'order')
                                      Text(
                                          'เบอร์ตู้: ${detail['container_size'] ?? ''} ${detail['container_no'] ?? ''}',
                                          style: const TextStyle(fontSize: 14)),
                                    if (state.currentMode == 'fuel')
                                      Text(
                                          'ปริมาณน้ำมัน: ${detail['fuel_qty'] ?? 0} ลิตร',
                                          style: const TextStyle(fontSize: 14)),
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
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ยกเลิก',
                          style: TextStyle(color: Colors.grey, fontSize: 16))),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white),
                    onPressed: () {
                      Navigator.pop(ctx);
                      notifier.executePrint(state.currentMode, previewData,
                          username: currentUsername);
                    },
                    icon: const Icon(Icons.print, size: 18),
                    label: const Text('ยืนยันสั่งพิมพ์ทั้งหมด',
                        style: TextStyle(fontSize: 16)),
                  )
                ],
              ));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red));
    }
  }

  Widget _previewText(String label, dynamic value, {bool isHighlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color:
                          isHighlight ? Colors.blue.shade700 : Colors.grey))),
          Expanded(
              child: Text(value?.toString() ?? '-',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: isHighlight
                          ? Colors.blue.shade700
                          : Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildModeButton(
      {required String title,
      required Color color,
      required bool isSelected,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(4),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Text(title,
            style: TextStyle(
                color: isSelected ? Colors.white : color,
                fontWeight: FontWeight.bold,
                fontSize: 14)),
      ),
    );
  }

  Widget _buildTableHeader(
      PrintDashboardState state, PrintDashboardNotifier notifier) {
    bool isAllSelected =
        state.jobs.isNotEmpty && state.selectedKeys.length == state.jobs.length;

    if (state.currentMode == 'job') {
      return Container(
        height: 40,
        decoration: BoxDecoration(
            color: const Color(0xFF94A3B8),
            border: Border.all(color: Colors.grey.shade400)),
        child: Row(
          children: [
            _hCell(50, '',
                child: Checkbox(
                    value: isAllSelected,
                    onChanged: (v) => notifier.selectAll(v ?? false),
                    activeColor: const Color(0xFFF97316))),
            _hCell(60, 'Print', align: Alignment.center),
            _hCell(130, 'Job No'),
            _hCell(120, 'Job Start'),
            _hCell(120, 'Job End'),
            _hCell(150, 'Job Type'),
            _hCell(150, 'Customer'),
            _hCell(150, 'Consinee'),
            _hCell(100, 'Agent'),
            _hCell(120, 'Booking No'),
            _hCell(80, 'Cont. Size'),
            _hCell(120, 'Cont. No'),
            _hCell(100, 'Seal'),
            _hCell(100, 'Plate'),
            _hCell(80, 'Veh Code'),
            _hCell(150, 'Driver'),
            _hCell(120, 'Enter to Work'),
            _hCell(120, 'Out to Work'),
            _hCell(100, 'Drop 1'),
            _hCell(100, 'Drop 2'),
            _hCell(100, 'Drop 3'),
          ],
        ),
      );
    } else if (state.currentMode == 'order') {
      return Container(
        height: 40,
        decoration: BoxDecoration(
            color: const Color(0xFF94A3B8),
            border: Border.all(color: Colors.grey.shade400)),
        child: Row(
          children: [
            _hCell(50, '',
                child: Checkbox(
                    value: isAllSelected,
                    onChanged: (v) => notifier.selectAll(v ?? false),
                    activeColor: const Color(0xFFF97316))),
            _hCell(60, 'Print', align: Alignment.center),
            _hCell(130, 'Order No'),
            _hCell(150, 'Job Type'),
            _hCell(120, 'Vessel'),
            _hCell(100, 'Agent'),
            _hCell(120, 'Booking BL'),
            _hCell(110, 'Contrainer Size'),
            _hCell(120, 'Contrainer No'),
            _hCell(100, 'Seal No'),
            _hCell(200, 'customer'),
            _hCell(150, 'Consignee'),
            _hCell(120, 'Route'),
            _hCell(150, 'Drop'),
            _hCell(100, 'Created By'),
            _hCell(120, 'Created Date'),
            _hCell(120, 'Update Date'),
          ],
        ),
      );
    } else {
      return Container(
        height: 40,
        decoration: BoxDecoration(
            color: const Color(0xFF94A3B8),
            border: Border.all(color: Colors.grey.shade400)),
        child: Row(
          children: [
            _hCell(50, '',
                child: Checkbox(
                    value: isAllSelected,
                    onChanged: (v) => notifier.selectAll(v ?? false),
                    activeColor: const Color(0xFFF97316))),
            _hCell(60, 'Print', align: Alignment.center),
            _hCell(130, 'Job no'),
            _hCell(120, 'job start'),
            _hCell(100, 'ทะเบียนรถ'),
            _hCell(150, 'พนักงานขับรถ'),
            _hCell(100, 'ปริมาณน้ำมัน'),
            _hCell(150, 'JOB Type'),
            _hCell(120, 'Route'),
            _hCell(150, 'drop'),
          ],
        ),
      );
    }
  }

  Widget _buildJobInfoRow(
      BuildContext context,
      Map<String, dynamic> item,
      Color rowColor,
      PrintDashboardNotifier notifier,
      String uniqueKey,
      bool isSelected,
      String refId) {
    final isPrinted = (item['print_job']?.toString() == '1') ||
        (item['print_status']?.toString() == '1');

    return Container(
      constraints: const BoxConstraints(minHeight: 45),
      decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : rowColor,
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 0.5))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            padding: const EdgeInsets.only(top: 4),
            alignment: Alignment.topCenter,
            child: Checkbox(
                value: isSelected,
                onChanged: (_) => notifier.toggleSelection(uniqueKey),
                activeColor: const Color(0xFFF97316)),
          ),
          _actionCell(
              60, () => _showPreviewAndPrint(refId, notifier), isPrinted),
          _dCell(context, 130, item['job_no']),
          _dCell(context, 120, _formatDateTime(item['job_start'])),
          _dCell(context, 120, _formatDateTime(item['job_end'])),
          _dCell(context, 150, item['type_name']),
          _dCell(context, 150, item['customer_name']),
          _dCell(context, 150, item['consignee_name'] ?? '-'),
          _dCell(context, 100, item['agent']),
          _dCell(context, 120, item['booking_no']),
          _dCell(context, 80, item['container_size']),
          _dCell(context, 120, item['container_no']),
          _dCell(context, 100, item['seal_desc']),
          _dCell(context, 100, item['vehicle_name']),
          _dCell(context, 80, item['veh_code']),
          _dCell(context, 150, item['driver'], link: true),
          _dCell(context, 120, _formatDateTime(item['enter_to_work'])),
          _dCell(context, 120, _formatDateTime(item['out_to_work'])),
          _dCell(context, 100, item['drop1']),
          _dCell(context, 100, item['drop2']),
          _dCell(context, 100, item['drop3']),
        ],
      ),
    );
  }

  Widget _buildOrderRow(
      BuildContext context,
      Map<String, dynamic> item,
      Color rowColor,
      PrintDashboardNotifier notifier,
      String uniqueKey,
      bool isSelected,
      String refId) {
    final isPrinted = (item['print_job']?.toString() == '1') ||
        (item['print_status']?.toString() == '1');

    return Container(
      constraints: const BoxConstraints(minHeight: 45),
      decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : rowColor,
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 0.5))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            padding: const EdgeInsets.only(top: 4),
            alignment: Alignment.topCenter,
            child: Checkbox(
                value: isSelected,
                onChanged: (_) => notifier.toggleSelection(uniqueKey),
                activeColor: const Color(0xFFF97316)),
          ),
          _actionCell(
              60, () => _showPreviewAndPrint(refId, notifier), isPrinted),
          _dCell(context, 130, item['order_number']),
          _dCell(context, 150, item['type_name'] ?? item['job_type_name']),
          _dCell(context, 120, item['vessel'] ?? '-'),
          _dCell(context, 100, item['agent']),
          _dCell(context, 120, item['booking_no'] ?? '-'),
          _dCell(context, 110, item['container_size']),
          _dCell(context, 120, item['container_no'] ?? '-'),
          _dCell(context, 100, item['seal_desc'] ?? '-'),
          _dCell(context, 200, item['customer_name']),
          _dCell(context, 150, item['consignee_name'] ?? '-'),
          _dCell(context, 120, item['route_master_name']),
          _dCell(context, 150,
              item['route_stations'] ?? item['drop_point'] ?? '-'),
          _dCell(context, 100, item['create_by'] ?? '-'),
          _dCell(context, 120, _formatDateTime(item['create_date'])),
          _dCell(context, 120, _formatDateTime(item['updated_date'])),
        ],
      ),
    );
  }

  Widget _buildFuelRow(
      BuildContext context,
      Map<String, dynamic> item,
      Color rowColor,
      PrintDashboardNotifier notifier,
      String uniqueKey,
      bool isSelected,
      String refId) {
    final isPrinted = (item['print_fuel']?.toString() == '1') ||
        (item['print_job']?.toString() == '1') ||
        (item['print_status']?.toString() == '1');

    return Container(
      constraints: const BoxConstraints(minHeight: 45),
      decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : rowColor,
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 0.5))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 50,
            padding: const EdgeInsets.only(top: 4),
            alignment: Alignment.topCenter,
            child: Checkbox(
                value: isSelected,
                onChanged: (_) => notifier.toggleSelection(uniqueKey),
                activeColor: const Color(0xFFF97316)),
          ),
          _actionCell(
              60, () => _showPreviewAndPrint(refId, notifier), isPrinted),
          _dCell(context, 130, item['job_no']),
          _dCell(context, 120, _formatDateTime(item['job_start'])),
          _dCell(context, 100, item['vehicle_name']),
          _dCell(context, 150, item['driver_name'] ?? item['driver']),
          _dCell(context, 100, '${item['fuel_qty'] ?? 0} L'),
          _dCell(context, 150, item['type_name'] ?? item['job_type_name']),
          _dCell(context, 120, item['route_master_name']),
          _dCell(context, 150,
              item['drop_point'] ?? item['route_stations'] ?? '-'),
        ],
      ),
    );
  }

  Widget _hCell(double w, String text,
      {Alignment align = Alignment.centerLeft, Widget? child}) {
    return Container(
      width: w,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: align,
      child: child ??
          Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  color: Colors.white)),
    );
  }

  Widget _dCell(BuildContext context, double w, dynamic text,
      {bool link = false, Alignment align = Alignment.topLeft}) {
    final str = text?.toString() ?? '-';
    return Container(
      width: w,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      alignment: align,
      child: Tooltip(
        message: 'คลิกเพื่อคัดลอก',
        child: InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: str));
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('คัดลอก "$str" ลงคลิปบอร์ดแล้ว',
                  style: const TextStyle(fontFamily: 'Sarabun')),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.green.shade600,
            ));
          },
          child: Text(str,
              style: TextStyle(
                  fontSize: 12,
                  color: link ? Colors.blue.shade700 : Colors.black87,
                  decoration: link ? TextDecoration.underline : null,
                  height: 1.5)),
        ),
      ),
    );
  }

  Widget _actionCell(double w, VoidCallback onTap, bool isPrinted) {
    return Container(
      width: w,
      padding: const EdgeInsets.only(top: 8),
      alignment: Alignment.topCenter,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: isPrinted ? Colors.green.shade500 : Colors.orange.shade400,
              borderRadius: BorderRadius.circular(4)),
          child: const Icon(Icons.print, size: 16, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDateInput(TextEditingController ctrl, String label) {
    return SizedBox(
      width: 120,
      height: 35,
      child: TextField(
        controller: ctrl,
        readOnly: true,
        onTap: () => _pickDate(ctrl),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 14),
        ),
        style: const TextStyle(fontSize: 12),
      ),
    );
  }
}
