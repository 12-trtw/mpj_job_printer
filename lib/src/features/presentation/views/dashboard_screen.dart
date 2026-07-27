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

  String _selectedMode = 'job'; // 'job' หรือ 'fuel'
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

  // ปรับโทนสีแถวให้เหมือนหน้าเว็บ (สีครีม/เหลืองอ่อน เป็นค่าเริ่มต้น)
  Color _getRowColor(Map<String, dynamic> data) {
    final fleetStatus = data['fleet_status']?.toString();
    final shiptoStatus = data['shipto_status']?.toString();

    if (fleetStatus == '99') return const Color(0xFFF3F4F6); // Canceled (เทา)
    if (shiptoStatus == '99')
      return const Color(0xFFFEF3C7); // Hold (เหลืองส้ม)
    if (fleetStatus == '5')
      return const Color(0xFFD1FAE5); // Approved (เขียวอ่อน)
    if (fleetStatus == '100') return const Color(0xFFDBEAFE); // Completed (ฟ้า)
    if (fleetStatus == '95')
      return const Color(0xFFCCFBF1); // Delivery (เขียวมินต์)
    if (fleetStatus == '10')
      return const Color(0xFFF3E8FF); // Billing (ม่วงอ่อน)

    // Default สีครีม/ส้มอ่อน ตามรูปภาพ UI อ้างอิง
    return const Color(0xFFFDE68A).withOpacity(0.4);
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
      backgroundColor: const Color(0xFFF3F4F6), // พื้นหลังสีเทาอ่อน
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // =======================================
          // 1. App Header (โทนสีส้มตามเว็บ)
          // =======================================
          Container(
            height: 50,
            color: const Color(0xFFF97316), // สีส้มแบบรูปภาพ
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Row(
              children: [
                Icon(Icons.print_outlined, color: Colors.white),
                SizedBox(width: 10),
                Text('MPJ Print Dashboard',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white)),
              ],
            ),
          ),

          // =======================================
          // 2. Toolbar & Filters
          // =======================================
          Expanded(
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.05), blurRadius: 4)
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // --- ปุ่มเลือกโหมด (ซ้ายบน) และ ตัวกรอง ---
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Mode Switcher (น้ำเงิน/เขียว)
                        Row(
                          children: [
                            _buildModeButton(
                              title: '📋 รายการ JOB',
                              color: const Color(0xFF1D4ED8), // น้ำเงิน
                              isSelected: _selectedMode == 'job',
                              onTap: () => setState(() {
                                _selectedMode = 'job';
                                _fetchData(notifier);
                              }),
                            ),
                            const SizedBox(width: 12),
                            _buildModeButton(
                              title: '⛽ รายการเติมน้ำมัน',
                              color: const Color(0xFF047857), // เขียว
                              isSelected: _selectedMode == 'fuel',
                              onTap: () => setState(() {
                                _selectedMode = 'fuel';
                                _fetchData(notifier);
                              }),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Filters
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _buildDateInput(_startDateCtrl, 'ตั้งแต่วันที่'),
                            const Text('-'),
                            _buildDateInput(_endDateCtrl, 'ถึงวันที่'),
                            SizedBox(
                              width: 180,
                              height: 35,
                              child: TextField(
                                controller: _keywordCtrl,
                                decoration: const InputDecoration(
                                  labelText: 'ค้นหา...',
                                  isDense: true,
                                  border: OutlineInputBorder(),
                                  prefixIcon: Icon(Icons.search, size: 18),
                                ),
                                style: const TextStyle(fontSize: 13),
                                onSubmitted: (_) => _fetchData(notifier),
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF3B82F6),
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
                              label: const Text('ดึงข้อมูล'),
                            ),
                            const SizedBox(width: 16),

                            // เครื่องพิมพ์
                            Container(
                              height: 35,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 12),
                              decoration: BoxDecoration(
                                  border:
                                      Border.all(color: Colors.grey.shade400),
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
                          ],
                        ),
                        if (state.statusMessage.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 12),
                            child: Text(state.statusMessage,
                                style: TextStyle(
                                    color: state.statusMessage.contains('')
                                        ? Colors.red
                                        : Colors.green,
                                    fontWeight: FontWeight.bold)),
                          )
                      ],
                    ),
                  ),

                  // =======================================
                  // 3. Data Table
                  // =======================================
                  Expanded(
                    child: state.isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : state.jobs.isEmpty
                            ? const Center(
                                child: Text('ไม่มีข้อมูล',
                                    style: TextStyle(color: Colors.grey)))
                            : SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: SizedBox(
                                  width: _selectedMode == 'job'
                                      ? 2750
                                      : 1250, // ปรับความกว้างตามโหมด
                                  child: Column(
                                    children: [
                                      _buildTableHeader(),
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

                                            return _selectedMode == 'job'
                                                ? _buildJobRow(
                                                    item,
                                                    globalIndex,
                                                    rowColor,
                                                    notifier)
                                                : _buildFuelRow(
                                                    item,
                                                    globalIndex,
                                                    rowColor,
                                                    notifier);
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                  ),

                  // =======================================
                  // 4. Pagination
                  // =======================================
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

  // --- ปุ่มเลือกโหมด ---
  Widget _buildModeButton(
      {required String title,
      required Color color,
      required bool isSelected,
      required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color : Colors.white,
          border: Border.all(color: color),
          borderRadius: BorderRadius.circular(20),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                      color: color.withOpacity(0.3),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Text(
          title,
          style: TextStyle(
              color: isSelected ? Colors.white : color,
              fontWeight: FontWeight.bold,
              fontSize: 14),
        ),
      ),
    );
  }

  // --- หัวตาราง (สลับคอลัมน์ตามโหมด) ---
  Widget _buildTableHeader() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
          color: const Color(0xFF94A3B8),
          border:
              Border.all(color: Colors.grey.shade400)), // หัวตารางสีฟ้าอมเทา
      child: _selectedMode == 'job'
          ? Row(
              children: [
                _hCell(50, 'No#'),
                _hCell(130, 'Job No'),
                _hCell(120, 'Job Start'),
                _hCell(120, 'Job End'),
                _hCell(150, 'Job Type'),
                _hCell(130, 'Vessel'),
                _hCell(130, 'Booking BL'),
                _hCell(110, 'Container Size'),
                _hCell(120, 'Container No'),
                _hCell(100, 'Seal No'),
                _hCell(100, 'Plate'),
                _hCell(150, 'Driver'),
                _hCell(110, 'Trailer Plate'),
                _hCell(200, 'Customer'),
                _hCell(200, 'Consignee'),
                _hCell(120, 'Route'),
                _hCell(150, 'Drop'),
                _hCell(120, 'Created By'),
                _hCell(120, 'Created Date'),
                _hCell(120, 'Update Date'),
                _hCell(80, 'Print', align: Alignment.center),
              ],
            )
          : Row(
              children: [
                _hCell(50, 'No#'),
                _hCell(130, 'Job No'),
                _hCell(120, 'Job Start'),
                _hCell(120, 'ทะเบียนรถ'),
                _hCell(180, 'พนักงานขับรถ'),
                _hCell(120, 'ปริมาณน้ำมัน'),
                _hCell(150, 'Job Type'),
                _hCell(150, 'Route'),
                _hCell(150, 'Drop'),
                _hCell(80, 'Print', align: Alignment.center),
              ],
            ),
    );
  }

  // --- แถวตาราง โหมด JOB ---
  Widget _buildJobRow(Map<String, dynamic> item, int index, Color rowColor,
      PrintDashboardNotifier notifier) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
          color: rowColor,
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 0.5))),
      child: Row(
        children: [
          _dCell(50, index.toString()),
          _dCell(130, item['job_no']),
          _dCell(120, _formatDateTime(item['job_start'])),
          _dCell(120, _formatDateTime(item['job_end'])),
          _dCell(150, item['job_type_name']),
          _dCell(130, item['vessel']),
          _dCell(130, item['booking_bl']),
          _dCell(110, item['container_size']),
          _dCell(120, item['container_no']),
          _dCell(100, item['seal_no']),
          _dCell(100, item['vehicle_name']),
          _dCell(150, item['driver_name'] ?? item['driver'], link: true),
          _dCell(110, item['trailer_name'], link: true),
          _dCell(200, item['customer_name']),
          _dCell(200, item['consignee_name']),
          _dCell(120, item['route_master_name']),
          _dCell(150, item['station_place']),
          _dCell(120, item['create_by']),
          _dCell(120, _formatDateTime(item['create_date'])),
          _dCell(120, _formatDateTime(item['update_date'])),
          _actionCell(
              80, () => _handleIndividualPrint(item['job_no'], notifier)),
        ],
      ),
    );
  }

  // --- แถวตาราง โหมด FUEL ---
  Widget _buildFuelRow(Map<String, dynamic> item, int index, Color rowColor,
      PrintDashboardNotifier notifier) {
    return Container(
      height: 45,
      decoration: BoxDecoration(
          color: rowColor,
          border: Border(
              bottom: BorderSide(color: Colors.grey.shade300, width: 0.5))),
      child: Row(
        children: [
          _dCell(50, index.toString()),
          _dCell(130, item['job_no']),
          _dCell(120, _formatDateTime(item['job_start'])),
          _dCell(120, item['vehicle_name']),
          _dCell(180, item['driver_name'] ?? item['driver']),
          _dCell(120, '${item['fuel_qty'] ?? 0} L'),
          _dCell(150, item['job_type_name']),
          _dCell(150, item['route_master_name']),
          _dCell(150, item['station_place']),
          _actionCell(
              80, () => _handleIndividualPrint(item['job_no'], notifier)),
        ],
      ),
    );
  }

  // ฟังก์ชันย่อยสำหรับสั่งพิมพ์ทีละใบ
  void _handleIndividualPrint(String? jobNo, PrintDashboardNotifier notifier) {
    if (jobNo == null || jobNo.isEmpty) return;

    // เคลียร์ Checkbox เก่า -> เลือกแถวนี้ -> สั่ง Print
    notifier.selectAll(false);
    notifier.toggleSelection('${jobNo}_0'); // ต้องแมปคีย์ให้ตรงกับใน Provider

    // หมายเหตุ: โลจิกตรงนี้ในอนาคต Controller ต้องถูกอัปเดตไปเรียก API /job-info ก่อนพิมพ์
    notifier.printSelectedJobs();
  }

  Widget _hCell(double w, String text,
      {Alignment align = Alignment.centerLeft}) {
    return Container(
      width: w,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: align,
      child: Text(text,
          style: const TextStyle(
              fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white)),
    );
  }

  Widget _dCell(double w, dynamic text, {bool link = false}) {
    final str = text?.toString() ?? '-';
    return Container(
      width: w,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      alignment: Alignment.centerLeft,
      child: Text(str,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: 12,
              color: link ? Colors.blue.shade700 : Colors.black87,
              decoration: link ? TextDecoration.underline : null)),
    );
  }

  Widget _actionCell(double w, VoidCallback onTap) {
    return Container(
      width: w,
      alignment: Alignment.center,
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
