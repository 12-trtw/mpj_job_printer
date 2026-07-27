import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mpj_job_printer/src/features/presentation/controller/print_controller.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _startDateCtrl = TextEditingController();
  final TextEditingController _endDateCtrl = TextEditingController();
  final TextEditingController _keywordCtrl = TextEditingController();

  String _selectedMode = 'job';
  int _selectedLimit = 25;

  @override
  void initState() {
    super.initState();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _startDateCtrl.text = today;
    _endDateCtrl.text = today;
  }

  @override
  void dispose() {
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _keywordCtrl.dispose();
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
    if (data['shipto_status']?.toString() == '99')
      return const Color(0xFFFEF3C7);
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
    if (dateString == null || dateString.isEmpty) return '-';
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

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            height: 55,
            color: const Color(0xFFF97316),
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Row(
              children: [
                Icon(Icons.apps, color: Colors.white),
                SizedBox(width: 12),
                Text('Print Management',
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
                Spacer(),
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
                                  title: '📋 รายการ JOB',
                                  color: const Color(0xFF2563EB),
                                  isSelected: _selectedMode == 'job',
                                  onTap: () {
                                    setState(() => _selectedMode = 'job');
                                    _fetchData(notifier);
                                  },
                                ),
                                const SizedBox(width: 12),
                                _buildModeButton(
                                  title: '⛽ รายการเติมน้ำมัน',
                                  color: const Color(0xFF10B981),
                                  isSelected: _selectedMode == 'fuel',
                                  onTap: () {
                                    setState(() => _selectedMode = 'fuel');
                                    _fetchData(notifier);
                                  },
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.print,
                                    color: Colors.grey, size: 24),
                                const SizedBox(width: 8),
                                Container(
                                  height: 45,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12),
                                  decoration: BoxDecoration(
                                      border: Border.all(
                                          color: Colors.grey.shade400),
                                      borderRadius: BorderRadius.circular(4)),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: state.selectedPrinter,
                                      hint: const Text('เลือกเครื่องพิมพ์...',
                                          style: TextStyle(fontSize: 16)),
                                      items: state.availablePrinters
                                          .map((p) => DropdownMenuItem(
                                              value: p,
                                              child: Text(p,
                                                  style: const TextStyle(
                                                      fontSize: 16))))
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
                                      fixedSize: const Size.fromHeight(45)),
                                  onPressed: (state.selectedKeys.isEmpty ||
                                          state.isPrinting)
                                      ? null
                                      : () =>
                                          _showBatchPreviewAndPrint(notifier),
                                  icon: state.isPrinting
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white))
                                      : const Icon(Icons.print, size: 20),
                                  label: Text(
                                      'ปริ้นที่เลือก (${state.selectedKeys.length})',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
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
                                child:
                                    Text('-', style: TextStyle(fontSize: 18))),
                            _buildDateInput(_endDateCtrl, 'ถึงวันที่'),
                            const SizedBox(width: 12),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blueGrey,
                                  foregroundColor: Colors.white,
                                  fixedSize: const Size.fromHeight(45)),
                              onPressed: state.isLoading
                                  ? null
                                  : () => _fetchData(notifier),
                              icon: const Icon(Icons.filter_alt, size: 20),
                              label: const Text('กรองวันที่',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 300,
                              height: 45,
                              child: TextField(
                                controller: _keywordCtrl,
                                decoration: const InputDecoration(
                                    labelText: 'ค้นหา (Job/ทะเบียน)...',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.search, size: 20)),
                                style: const TextStyle(fontSize: 16),
                                onSubmitted: (_) => _fetchData(notifier),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  fixedSize: const Size.fromHeight(45)),
                              onPressed: state.isLoading
                                  ? null
                                  : () => _fetchData(notifier),
                              icon: state.isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.search, size: 20),
                              label: const Text('ค้นหา',
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16)),
                            ),
                          ],
                        ),
                        if (state.statusMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(state.statusMessage,
                                style: TextStyle(
                                    fontSize: 16,
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
                                    style: TextStyle(
                                        color: Colors.grey, fontSize: 20)))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: _selectedMode == 'job' ? 3900 : 1900,
                                  child: Column(
                                    children: [
                                      _buildTableHeader(state, notifier),
                                      Expanded(
                                        child: ListView.builder(
                                          itemCount: state.jobs.length,
                                          itemBuilder: (context, index) {
                                            final item = state.jobs[index];
                                            final rowColor = _getRowColor(item);
                                            final globalIndex =
                                                ((state.currentPage - 1) *
                                                        _selectedLimit) +
                                                    index +
                                                    1;

                                            final refId = item['job_no'] ??
                                                item['fleet_id'] ??
                                                index.toString();
                                            final uniqueKey = '${refId}_$index';
                                            final isSelected = state
                                                .selectedKeys
                                                .contains(uniqueKey);

                                            return _selectedMode == 'job'
                                                ? _buildJobRow(
                                                    context,
                                                    item,
                                                    globalIndex,
                                                    rowColor,
                                                    notifier,
                                                    uniqueKey,
                                                    isSelected)
                                                : _buildFuelRow(
                                                    context,
                                                    item,
                                                    globalIndex,
                                                    rowColor,
                                                    notifier,
                                                    uniqueKey,
                                                    isSelected);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                  ),
                  if (state.jobs.isNotEmpty && !state.isLoading)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      decoration: BoxDecoration(
                          border: Border(
                              top: BorderSide(color: Colors.grey.shade300))),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('Show ',
                                  style: TextStyle(fontSize: 16)),
                              Container(
                                height: 35,
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
                                    value: _selectedLimit,
                                    items: [10, 25, 50, 100]
                                        .map((v) => DropdownMenuItem(
                                            value: v,
                                            child: Text('$v',
                                                style: const TextStyle(
                                                    fontSize: 16))))
                                        .toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _selectedLimit = val);
                                        _fetchData(notifier);
                                      }
                                    },
                                  ),
                                ),
                              ),
                              Text(' entries (Total: ${state.totalItems})',
                                  style: const TextStyle(fontSize: 16)),
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
                                    minimumSize: const Size(80, 40)),
                                child: const Text('Prev',
                                    style: TextStyle(fontSize: 16)),
                              ),
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 16),
                                child: Text(
                                    '${state.currentPage} / ${state.totalPages}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                              ),
                              OutlinedButton(
                                onPressed: state.currentPage < state.totalPages
                                    ? () => notifier
                                        .changePage(state.currentPage + 1)
                                    : null,
                                style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(80, 40)),
                                child: const Text('Next',
                                    style: TextStyle(fontSize: 16)),
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

  void _fetchData(PrintDashboardNotifier notifier) {
    notifier.fetchJobs(
      mode: _selectedMode,
      startDate: _startDateCtrl.text,
      endDate: _endDateCtrl.text,
      keyword: _keywordCtrl.text,
      page: 1,
      limit: _selectedLimit,
    );
  }

  void _showPreviewAndPrint(
      String? jobNo, PrintDashboardNotifier notifier) async {
    if (jobNo == null || jobNo.isEmpty) return;
    final state = ref.read(dashboardProvider);
    if (state.selectedPrinter == null || state.selectedPrinter!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรุณาเลือกเครื่องพิมพ์ก่อนครับ',
              style: TextStyle(fontSize: 16)),
          backgroundColor: Colors.red));
      return;
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()));

    try {
      final previewData =
          await notifier.getPrintPreviewData(_selectedMode, jobNo);
      if (!mounted) return;
      Navigator.pop(context);

      if (previewData == null || previewData.isEmpty)
        throw Exception('ไม่พบข้อมูลสำหรับปริ้น');
      final detail = previewData.first;

      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.print, color: Color(0xFFF97316)),
                    const SizedBox(width: 8),
                    Text('ตัวอย่างก่อนพิมพ์ - $jobNo',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
                content: SizedBox(
                  width: 500,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _previewText('ประเภทงาน:', detail['type_name']),
                      _previewText('ทะเบียนรถ:', detail['vehicle_name']),
                      _previewText(
                          'คนขับ:', detail['driver_name'] ?? detail['driver']),
                      _previewText('ลูกค้า:', detail['customer_name']),
                      if (_selectedMode == 'fuel')
                        _previewText(
                            'ปริมาณน้ำมัน:', '${detail['fuel_qty'] ?? 0} ลิตร'),
                      if (_selectedMode == 'job')
                        _previewText('เบอร์ตู้:',
                            '${detail['container_size'] ?? ''} ${detail['container_no'] ?? ''}'),
                      const SizedBox(height: 16),
                      const Text('ตรวจสอบความถูกต้องแล้วกด "ยืนยันสั่งพิมพ์"',
                          style: TextStyle(color: Colors.grey, fontSize: 16)),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('ยกเลิก',
                          style: TextStyle(color: Colors.grey, fontSize: 18))),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        fixedSize: const Size.fromHeight(45)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      notifier.executePrint(_selectedMode, previewData);
                    },
                    icon: const Icon(Icons.print, size: 20),
                    label: const Text('ยืนยันสั่งพิมพ์',
                        style: TextStyle(fontSize: 18)),
                  )
                ],
              ));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red));
    }
  }

  void _showBatchPreviewAndPrint(PrintDashboardNotifier notifier) async {
    final state = ref.read(dashboardProvider);
    if (state.selectedPrinter == null || state.selectedPrinter!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('กรุณาเลือกเครื่องพิมพ์ก่อนครับ',
              style: TextStyle(fontSize: 16)),
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

      if (previewData == null || previewData.isEmpty)
        throw Exception('ไม่พบข้อมูลสำหรับปริ้น');

      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
                title: Row(
                  children: [
                    const Icon(Icons.print, color: Color(0xFFF97316)),
                    const SizedBox(width: 8),
                    Text('ตัวอย่างก่อนพิมพ์ (${previewData.length} รายการ)',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
                content: SizedBox(
                  width: 600,
                  height: 500,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                          'รายการต่อไปนี้จะถูกส่งเข้าเครื่องพิมพ์ตามลำดับ:',
                          style: TextStyle(fontSize: 16)),
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
                                    Text('Job No: ${detail['job_no']}',
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18)),
                                    const SizedBox(height: 4),
                                    Text(
                                        'ทะเบียนรถ: ${detail['vehicle_name'] ?? '-'} | คนขับ: ${detail['driver_name'] ?? detail['driver'] ?? '-'}',
                                        style: const TextStyle(fontSize: 16)),
                                    if (_selectedMode == 'job')
                                      Text(
                                          'เบอร์ตู้: ${detail['container_size'] ?? ''} ${detail['container_no'] ?? ''}',
                                          style: const TextStyle(fontSize: 16)),
                                    if (_selectedMode == 'fuel')
                                      Text(
                                          'ปริมาณน้ำมัน: ${detail['fuel_qty'] ?? 0} ลิตร',
                                          style: const TextStyle(fontSize: 16)),
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
                          style: TextStyle(color: Colors.grey, fontSize: 18))),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF97316),
                        foregroundColor: Colors.white,
                        fixedSize: const Size.fromHeight(45)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      notifier.executePrint(_selectedMode, previewData);
                    },
                    icon: const Icon(Icons.print, size: 20),
                    label: const Text('ยืนยันสั่งพิมพ์ทั้งหมด',
                        style: TextStyle(fontSize: 18)),
                  )
                ],
              ));
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(e.toString(), style: const TextStyle(fontSize: 16)),
          backgroundColor: Colors.red));
    }
  }

  Widget _previewText(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 120,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                      fontSize: 18))),
          Expanded(
              child: Text(value?.toString() ?? '-',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 18))),
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
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
                fontSize: 16)),
      ),
    );
  }

  Widget _buildTableHeader(
      PrintDashboardState state, PrintDashboardNotifier notifier) {
    bool isAllSelected =
        state.jobs.isNotEmpty && state.selectedKeys.length == state.jobs.length;

    return Container(
      height: 60,
      decoration: BoxDecoration(
          color: const Color(0xFF94A3B8),
          border: Border.all(color: Colors.grey.shade400)),
      child: _selectedMode == 'job'
          ? Row(
              children: [
                _hCell(70, '',
                    child: Checkbox(
                        value: isAllSelected,
                        onChanged: (v) => notifier.selectAll(v ?? false),
                        activeColor: const Color(0xFFF97316))),
                _hCell(80, 'NO#'),
                _hCell(180, 'JOB NO'),
                _hCell(180, 'Job start'),
                _hCell(180, 'Job End'),
                _hCell(240, 'Job Type'),
                _hCell(160, 'Vessel'),
                _hCell(160, 'Booking BL'),
                _hCell(160, 'Contrainer Size'),
                _hCell(180, 'Contrainer No'),
                _hCell(140, 'Seal No'),
                _hCell(140, 'Plate'),
                _hCell(240, 'Driver'),
                _hCell(160, 'traller Plate'),
                _hCell(300, 'customer'),
                _hCell(250, 'Consignee'),
                _hCell(220, 'Route'),
                _hCell(250, 'Drop'),
                _hCell(180, 'Created By'),
                _hCell(180, 'Created Date'),
                _hCell(180, 'Update Date'),
                _hCell(100, 'Print', align: Alignment.center),
              ],
            )
          : Row(
              children: [
                _hCell(70, '',
                    child: Checkbox(
                        value: isAllSelected,
                        onChanged: (v) => notifier.selectAll(v ?? false),
                        activeColor: const Color(0xFFF97316))),
                _hCell(80, 'No#'),
                _hCell(180, 'Job no'),
                _hCell(180, 'job start'),
                _hCell(140, 'ทะเบียนรถ'),
                _hCell(240, 'พนักงานขับรถ'),
                _hCell(140, 'ปริมาณน้ำมัน'),
                _hCell(240, 'JOB Type'),
                _hCell(220, 'Route'),
                _hCell(250, 'drop'),
                _hCell(100, 'Print', align: Alignment.center),
              ],
            ),
    );
  }

  Widget _buildJobRow(
      BuildContext context,
      Map<String, dynamic> item,
      int globalIndex,
      Color rowColor,
      PrintDashboardNotifier notifier,
      String uniqueKey,
      bool isSelected) {
    return Container(
      constraints: const BoxConstraints(minHeight: 65),
      decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : rowColor,
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 0.5))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            padding: const EdgeInsets.only(top: 8),
            alignment: Alignment.topCenter,
            child: Checkbox(
                value: isSelected,
                onChanged: (_) => notifier.toggleSelection(uniqueKey),
                activeColor: const Color(0xFFF97316)),
          ),
          _dCell(context, 80, globalIndex.toString(),
              align: Alignment.topCenter),
          _dCell(context, 180, item['job_no']),
          _dCell(context, 180, _formatDateTime(item['job_start'])),
          _dCell(context, 180, _formatDateTime(item['job_end'])),
          _dCell(context, 240, item['type_name'] ?? item['job_type_name']),
          _dCell(context, 160, item['vessel']),
          _dCell(context, 160, item['booking_bl']),
          _dCell(context, 160, item['container_size']),
          _dCell(context, 180, item['container_no']),
          _dCell(context, 140, item['seal_no'] ?? '-'),
          _dCell(context, 140, item['vehicle_name']),
          _dCell(context, 240, item['driver_name'] ?? item['driver'],
              link: true),
          _dCell(context, 160, item['trailer_name'] ?? '-', link: true),
          _dCell(context, 300, item['customer_name']),
          _dCell(context, 250, item['consignee_name'] ?? '-'),
          _dCell(context, 220, item['route_master_name']),
          _dCell(context, 250,
              item['route_stations'] ?? item['station_place'] ?? '-'),
          _dCell(context, 180, item['create_by'] ?? '-'),
          _dCell(context, 180, _formatDateTime(item['create_date'])),
          _dCell(context, 180, _formatDateTime(item['update_date'])),
          _actionCell(
              100, () => _showPreviewAndPrint(item['job_no'], notifier)),
        ],
      ),
    );
  }

  Widget _buildFuelRow(
      BuildContext context,
      Map<String, dynamic> item,
      int globalIndex,
      Color rowColor,
      PrintDashboardNotifier notifier,
      String uniqueKey,
      bool isSelected) {
    return Container(
      constraints: const BoxConstraints(minHeight: 65),
      decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : rowColor,
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 0.5))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 70,
            padding: const EdgeInsets.only(top: 8),
            alignment: Alignment.topCenter,
            child: Checkbox(
                value: isSelected,
                onChanged: (_) => notifier.toggleSelection(uniqueKey),
                activeColor: const Color(0xFFF97316)),
          ),
          _dCell(context, 80, globalIndex.toString(),
              align: Alignment.topCenter),
          _dCell(context, 180, item['job_no']),
          _dCell(context, 180, _formatDateTime(item['job_start'])),
          _dCell(context, 140, item['vehicle_name']),
          _dCell(context, 240, item['driver_name'] ?? item['driver']),
          _dCell(context, 140, '${item['fuel_qty'] ?? 0} L'),
          _dCell(context, 240, item['type_name'] ?? item['job_type_name']),
          _dCell(context, 220, item['route_master_name']),
          _dCell(context, 250,
              item['drop_point'] ?? item['route_stations'] ?? '-'),
          _actionCell(
              100, () => _showPreviewAndPrint(item['job_no'], notifier)),
        ],
      ),
    );
  }

  Widget _hCell(double w, String text,
      {Alignment align = Alignment.centerLeft, Widget? child}) {
    return Container(
      width: w,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: align,
      child: child ??
          Text(text,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white)),
    );
  }

  Widget _dCell(BuildContext context, double w, dynamic text,
      {bool link = false, Alignment align = Alignment.topLeft}) {
    final str = text?.toString() ?? '-';
    return Container(
      width: w,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      alignment: align,
      child: Tooltip(
        message: 'คลิกเพื่อคัดลอก',
        child: InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: str));
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('คัดลอก "$str" ลงคลิปบอร์ดแล้ว',
                  style: const TextStyle(fontFamily: 'Sarabun', fontSize: 16)),
              duration: const Duration(seconds: 1),
              backgroundColor: Colors.green.shade600,
            ));
          },
          child: Text(str,
              style: TextStyle(
                  fontSize: 18,
                  color: link ? Colors.blue.shade700 : Colors.black87,
                  decoration: link ? TextDecoration.underline : null,
                  height: 1.5)),
        ),
      ),
    );
  }

  Widget _actionCell(double w, VoidCallback onTap) {
    return Container(
      width: w,
      padding: const EdgeInsets.only(top: 10),
      alignment: Alignment.topCenter,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.orange.shade400,
              borderRadius: BorderRadius.circular(4)),
          child: const Icon(Icons.print, size: 24, color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildDateInput(TextEditingController ctrl, String label) {
    return SizedBox(
      width: 160,
      height: 45,
      child: TextField(
        controller: ctrl,
        readOnly: true,
        onTap: () => _pickDate(ctrl),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 16),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        style: const TextStyle(fontSize: 16),
      ),
    );
  }
}
