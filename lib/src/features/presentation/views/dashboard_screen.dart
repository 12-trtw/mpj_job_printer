import 'package:flutter/material.dart';
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

  // =======================================
  // Logic การเทียบสีแถว
  // =======================================
  Color _getRowColor(Map<String, dynamic> data) {
    final fleetStatus = data['fleet_status']?.toString();
    final shiptoStatus = data['shipto_status']?.toString();

    if (fleetStatus == '99') return const Color(0xFFF3F4F6); // canceled_job
    if (shiptoStatus == '99') return const Color(0xFFFEF3C7); // hold_job
    if (fleetStatus == '5') return const Color(0xFFD1FAE5); // approved_job
    if (fleetStatus == '100') return const Color(0xFFDBEAFE); // completed_job
    if (fleetStatus == '95') return const Color(0xFFCCFBF1); // delivery-success
    if (fleetStatus == '10') return const Color(0xFFF3E8FF); // billing_job

    if (fleetStatus == '0' && data['job_end'] != null) {
      try {
        final jobEnd = DateTime.parse(data['job_end'].toString());
        if (jobEnd.isBefore(DateTime.now())) {
          return const Color(0xFFFEE2E2); // over-time
        }
      } catch (_) {}
    }
    return Colors.white;
  }

  String _formatDateTime(String? dateString) {
    if (dateString == null || dateString.isEmpty) return '-';
    try {
      final d = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy HH:mm').format(d);
    } catch (_) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFE5E7EB),
      body: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.95,
          margin: const EdgeInsets.symmetric(vertical: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // =======================================
              // 1. Header & Toolbar
              // =======================================
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('MPJ Print Dashboard',
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF111827))),
                        ChoiceChip(
                          label: const Text('📋 ใบสั่งปฏิบัติงาน',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          selected: _selectedMode == 'job',
                          selectedColor: const Color(0xFFD1FAE5),
                          onSelected: (val) {
                            if (val) setState(() => _selectedMode = 'job');
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0))),
                      child: Wrap(
                        spacing: 16,
                        runSpacing: 12,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          _buildDateInput(_startDateCtrl, 'ตั้งแต่วันที่'),
                          const Text('-'),
                          _buildDateInput(_endDateCtrl, 'ถึงวันที่'),
                          SizedBox(
                            width: 180,
                            height: 40,
                            child: TextField(
                              controller: _keywordCtrl,
                              decoration: const InputDecoration(
                                labelText: 'ค้นหา (Job/ทะเบียน)',
                                isDense: true,
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.search, size: 18),
                              ),
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.bold),
                              onSubmitted: (_) => _fetchData(notifier),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 16)),
                            onPressed: state.isLoading
                                ? null
                                : () => _fetchData(notifier),
                            icon: state.isLoading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.search, size: 18),
                            label: const Text('ดึงข้อมูล',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            height: 40,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(4),
                                border:
                                    Border.all(color: const Color(0xFF9CA3AF))),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: state.selectedPrinter,
                                hint: const Text('เลือกเครื่องพิมพ์...'),
                                items: state.availablePrinters
                                    .map((p) => DropdownMenuItem(
                                        value: p,
                                        child: Text(p,
                                            style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13))))
                                    .toList(),
                                onChanged: notifier.setPrinter,
                              ),
                            ),
                          ),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 16),
                            ),
                            onPressed:
                                (state.selectedKeys.isEmpty || state.isPrinting)
                                    ? null
                                    : notifier.printSelectedJobs,
                            icon: state.isPrinting
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.print, size: 20),
                            label: Text(
                                'สั่งพิมพ์ (${state.selectedKeys.length})',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    if (state.statusMessage.isNotEmpty)
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.only(top: 12),
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: state.statusMessage.contains('❌')
                              ? const Color(0xFFFEE2E2)
                              : const Color(0xFFDCFCE7),
                          border: Border.all(
                              color: state.statusMessage.contains('❌')
                                  ? const Color(0xFFEF4444)
                                  : const Color(0xFF10B981)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(state.statusMessage,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: state.statusMessage.contains('❌')
                                    ? const Color(0xFF991B1B)
                                    : const Color(0xFF166534))),
                      ),
                  ],
                ),
              ),

              // =======================================
              // 2. Data Table
              // =======================================
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.jobs.isEmpty
                        ? const Center(
                            child: Text('ไม่มีข้อมูล',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 16)))
                        : Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: SizedBox(
                                    width: 1850,
                                    child: Column(
                                      children: [
                                        _buildTableHeader(state, notifier),
                                        Expanded(
                                          child: ListView.builder(
                                            itemCount: state.jobs.length,
                                            itemBuilder: (context, index) {
                                              final item = state.jobs[index];
                                              final refId = item['job_no'] ??
                                                  item['fleet_id'] ??
                                                  index.toString();
                                              final uniqueKey =
                                                  '${refId}_$index';
                                              final isSelected = state
                                                  .selectedKeys
                                                  .contains(uniqueKey);
                                              final rowColor =
                                                  _getRowColor(item);

                                              return _buildTableRow(
                                                item: item,
                                                index: index,
                                                // [MODIFIED] คำนวณลำดับที่อิงตามจำนวน Limit ที่เลือก
                                                globalIndex:
                                                    ((state.currentPage - 1) *
                                                            _selectedLimit) +
                                                        index +
                                                        1,
                                                isSelected: isSelected,
                                                rowColor: rowColor,
                                                onTap: () => notifier
                                                    .toggleSelection(uniqueKey),
                                              );
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
              ),

              // =======================================
              // 3. Pagination Bar (พร้อมตัวเลือกหน้าเว็บ)
              // =======================================
              if (state.jobs.isNotEmpty && !state.isLoading)
                Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: BoxDecoration(
                      border:
                          Border(top: BorderSide(color: Colors.grey.shade300))),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // [NEW] Dropdown เลือก Limit
                      Row(
                        children: [
                          const Text('แสดงหน้าละ:',
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF4B5563))),
                          const SizedBox(width: 8),
                          Container(
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(color: Colors.grey.shade400),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<int>(
                                value: _selectedLimit,
                                items: [10, 25, 50, 100].map((int value) {
                                  return DropdownMenuItem<int>(
                                    value: value,
                                    child: Text('$value',
                                        style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold)),
                                  );
                                }).toList(),
                                onChanged: (int? newValue) {
                                  if (newValue != null) {
                                    setState(() => _selectedLimit = newValue);
                                    _fetchData(notifier); // สั่งโหลดใหม่ทันที
                                  }
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Text(
                              'Showing ${state.jobs.length} of ${state.totalItems} entries',
                              style: const TextStyle(
                                  color: Colors.grey,
                                  fontWeight: FontWeight.bold)),
                        ],
                      ),

                      Row(
                        children: [
                          OutlinedButton(
                            onPressed: state.currentPage > 1
                                ? () =>
                                    notifier.changePage(state.currentPage - 1)
                                : null,
                            child: const Text('Previous'),
                          ),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                                'Page ${state.currentPage} / ${state.totalPages}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                          ),
                          OutlinedButton(
                            onPressed: state.currentPage < state.totalPages
                                ? () =>
                                    notifier.changePage(state.currentPage + 1)
                                : null,
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

  Widget _buildTableHeader(
      PrintDashboardState state, PrintDashboardNotifier notifier) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade400, width: 2),
          top: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: Row(
        children: [
          _headerCell(
            width: 50,
            child: Checkbox(
              value: state.jobs.isNotEmpty &&
                  state.selectedKeys.length == state.jobs.length,
              onChanged: (val) => notifier.selectAll(val ?? false),
            ),
          ),
          _headerCell(width: 50, title: 'No#'),
          _headerCell(width: 140, title: 'Job No.'),
          _headerCell(width: 140, title: 'Job Start'),
          _headerCell(width: 150, title: 'Job Type'),
          _headerCell(width: 140, title: 'Booking BL'),
          _headerCell(width: 180, title: 'Container / Seal'),
          _headerCell(width: 120, title: 'Plate'),
          _headerCell(width: 180, title: 'Driver'),
          _headerCell(width: 250, title: 'Customer'),
          _headerCell(width: 150, title: 'Route'),
          _headerCell(width: 150, title: 'Created By'),
          _headerCell(width: 150, title: 'Status (Fleet)'),
        ],
      ),
    );
  }

  // --- ส่วนข้อมูลแต่ละแถว ---
  Widget _buildTableRow({
    required Map<String, dynamic> item,
    required int index,
    required int globalIndex,
    required bool isSelected,
    required Color rowColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 55,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFEFF6FF) : rowColor,
          border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
        ),
        child: Row(
          children: [
            _dataCell(
                width: 50,
                child: Checkbox(value: isSelected, onChanged: (_) => onTap())),
            _dataCell(
                width: 50,
                child: Text(globalIndex.toString(),
                    style: const TextStyle(color: Colors.grey))),
            _dataCell(
                width: 140,
                child: Text(item['job_no'] ?? '-',
                    style: const TextStyle(fontWeight: FontWeight.bold))),
            _dataCell(
                width: 140, child: Text(_formatDateTime(item['job_start']))),
            _dataCell(width: 150, child: Text(item['job_type_name'] ?? '-')),
            _dataCell(width: 140, child: Text(item['booking_bl'] ?? '-')),
            _dataCell(
                width: 180,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        '${item['container_size'] ?? ''} ${item['container_no'] ?? ''}'
                            .trim(),
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('Seal: ${item['seal_no'] ?? '-'}',
                        style:
                            const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                )),
            _dataCell(width: 120, child: Text(item['vehicle_name'] ?? '-')),
            _dataCell(
                width: 180,
                child: Text(item['driver_name'] ?? item['driver'] ?? '-',
                    overflow: TextOverflow.ellipsis)),
            _dataCell(
                width: 250,
                child: Text(item['customer_name'] ?? '-',
                    overflow: TextOverflow.ellipsis)),
            _dataCell(
                width: 150,
                child: Text(item['route_master_name'] ?? '-',
                    overflow: TextOverflow.ellipsis)),
            _dataCell(width: 150, child: Text(item['create_by'] ?? '-')),
            _dataCell(
                width: 150,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(4)),
                  child: Text('St: ${item['fleet_status'] ?? '-'}',
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 12)),
                )),
          ],
        ),
      ),
    );
  }

  Widget _headerCell({required double width, String? title, Widget? child}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: child ??
          Text(title!,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Color(0xFF4B5563))),
    );
  }

  Widget _dataCell({required double width, required Widget child}) {
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: DefaultTextStyle(
        style: const TextStyle(
            fontSize: 13, color: Color(0xFF111827), fontFamily: 'Sarabun'),
        child: child,
      ),
    );
  }

  Widget _buildDateInput(TextEditingController ctrl, String label) {
    return SizedBox(
      width: 140,
      child: TextField(
        controller: ctrl,
        readOnly: true,
        onTap: () => _pickDate(ctrl),
        decoration: InputDecoration(
          labelText: label,
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          border: const OutlineInputBorder(),
          suffixIcon: const Icon(Icons.calendar_today, size: 16),
        ),
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}
