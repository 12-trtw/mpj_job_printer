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

  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

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
                const Icon(Icons.person, color: Colors.white),
                const SizedBox(width: 8),
                Text('Administrator',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9), fontSize: 13)),
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
                                      : () => notifier.printSelectedJobs(),
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
                                  : () => _fetchData(notifier),
                              icon: const Icon(Icons.filter_alt, size: 16),
                              label: const Text('กรองวันที่',
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
                                    labelText: 'ค้นหา (Job/ทะเบียน)...',
                                    isDense: true,
                                    border: OutlineInputBorder(),
                                    prefixIcon: Icon(Icons.search, size: 18)),
                                style: const TextStyle(fontSize: 13),
                                onSubmitted: (_) => _fetchData(notifier),
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.blue.shade700,
                                  foregroundColor: Colors.white,
                                  fixedSize: const Size.fromHeight(35)),
                              onPressed: state.isLoading
                                  ? null
                                  : () => _fetchData(notifier),
                              icon: state.isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : const Icon(Icons.search, size: 16),
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
                                    width: _selectedMode == 'job' ? 2600 : 1200,
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
                                                final globalIndex =
                                                    ((state.currentPage - 1) *
                                                            _selectedLimit) +
                                                        index +
                                                        1;

                                                final refId = item['job_no'] ??
                                                    item['fleet_id'] ??
                                                    index.toString();
                                                final uniqueKey =
                                                    '${refId}_$index';
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
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                  ),
                  if (state.jobs.isNotEmpty && !state.isLoading)
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
                                    value: _selectedLimit,
                                    items: [10, 25, 50, 100]
                                        .map((v) => DropdownMenuItem(
                                            value: v,
                                            child: Text('$v',
                                                style: const TextStyle(
                                                    fontSize: 13))))
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
          await notifier.getPrintPreviewData(_selectedMode, jobNo);
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
                    Text('ตัวอย่างข้อมูลก่อนพิมพ์ - $jobNo',
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
                      notifier.executePrint(_selectedMode, previewData);
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

  Widget _previewText(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
              width: 100,
              child: Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.grey))),
          Expanded(
              child: Text(value?.toString() ?? '-',
                  style: const TextStyle(fontWeight: FontWeight.bold))),
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

    return Container(
      height: 40,
      decoration: BoxDecoration(
          color: const Color(0xFF94A3B8),
          border: Border.all(color: Colors.grey.shade400)),
      child: _selectedMode == 'job'
          ? Row(
              children: [
                _hCell(50, '',
                    child: Checkbox(
                        value: isAllSelected,
                        onChanged: (v) => notifier.selectAll(v ?? false),
                        activeColor: const Color(0xFFF97316))),
                _hCell(50, 'NO#'),
                _hCell(130, 'JOB NO'),
                _hCell(120, 'Job start'),
                _hCell(120, 'Job End'),
                _hCell(150, 'Job Type'),
                _hCell(120, 'Vessel'),
                _hCell(120, 'Booking BL'),
                _hCell(110, 'Contrainer Size'),
                _hCell(120, 'Contrainer No'),
                _hCell(100, 'Seal No'),
                _hCell(100, 'Plate'),
                _hCell(150, 'Driver'),
                _hCell(110, 'traller Plate'),
                _hCell(200, 'customer'),
                _hCell(150, 'Consignee'),
                _hCell(120, 'Route'),
                _hCell(150, 'Drop'),
                _hCell(100, 'Created By'),
                _hCell(120, 'Created Date'),
                _hCell(120, 'Update Date'),
                _hCell(60, 'Print', align: Alignment.center),
              ],
            )
          : Row(
              children: [
                _hCell(50, '',
                    child: Checkbox(
                        value: isAllSelected,
                        onChanged: (v) => notifier.selectAll(v ?? false),
                        activeColor: const Color(0xFFF97316))),
                _hCell(50, 'No#'),
                _hCell(130, 'Job no'),
                _hCell(120, 'job start'),
                _hCell(100, 'ทะเบียนรถ'),
                _hCell(150, 'พนักงานขับรถ'),
                _hCell(100, 'ปริมาณน้ำมัน'),
                _hCell(150, 'JOB Type'),
                _hCell(120, 'Route'),
                _hCell(150, 'drop'),
                _hCell(60, 'Print', align: Alignment.center),
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
          _dCell(context, 50, globalIndex.toString(),
              align: Alignment.topCenter),
          _dCell(context, 130, item['job_no']),
          _dCell(context, 120, _formatDateTime(item['job_start'])),
          _dCell(context, 120, _formatDateTime(item['job_end'])),
          _dCell(context, 150, item['type_name'] ?? item['job_type_name']),
          _dCell(context, 120, item['vessel']),
          _dCell(context, 120, item['booking_bl']),
          _dCell(context, 110, item['container_size']),
          _dCell(context, 120, item['container_no']),
          _dCell(context, 100, item['seal_no'] ?? '-'),
          _dCell(context, 100, item['vehicle_name']),
          _dCell(context, 150, item['driver_name'] ?? item['driver'],
              link: true),
          _dCell(context, 110, item['trailer_name'] ?? '-', link: true),
          _dCell(context, 200, item['customer_name']),
          _dCell(context, 150, item['consignee_name'] ?? '-'),
          _dCell(context, 120, item['route_master_name']),
          _dCell(context, 150,
              item['route_stations'] ?? item['station_place'] ?? '-'),
          _dCell(context, 100, item['create_by'] ?? '-'),
          _dCell(context, 120, _formatDateTime(item['create_date'])),
          _dCell(context, 120, _formatDateTime(item['update_date'])),
          _actionCell(60, () => _showPreviewAndPrint(item['job_no'], notifier)),
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
          _dCell(context, 50, globalIndex.toString(),
              align: Alignment.topCenter),
          _dCell(context, 130, item['job_no']),
          _dCell(context, 120, _formatDateTime(item['job_start'])),
          _dCell(context, 100, item['vehicle_name']),
          _dCell(context, 150, item['driver_name'] ?? item['driver']),
          _dCell(context, 100, '${item['fuel_qty'] ?? 0} L'),
          _dCell(context, 150, item['type_name'] ?? item['job_type_name']),
          _dCell(context, 120, item['route_master_name']),
          _dCell(context, 150,
              item['drop_point'] ?? item['route_stations'] ?? '-'),
          _actionCell(60, () => _showPreviewAndPrint(item['job_no'], notifier)),
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

  Widget _actionCell(double w, VoidCallback onTap) {
    return Container(
      width: w,
      padding: const EdgeInsets.only(top: 8),
      alignment: Alignment.topCenter,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: Colors.orange.shade400,
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
