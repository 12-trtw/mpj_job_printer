import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mpj_job_printer/features/print/presentation/providers/print_dashboard.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final TextEditingController _startDateCtrl = TextEditingController();
  final TextEditingController _endDateCtrl = TextEditingController();

  String _selectedMode = 'job';

  @override
  void initState() {
    super.initState();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _startDateCtrl.text = today;
    _endDateCtrl.text = today;
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final notifier = ref.read(dashboardProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: Center(
        child: Container(
          width: 1000,
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
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
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('ระบบบริหารจัดการงานพิมพ์ (MPJ Print Dashboard)',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827))),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                        color: _selectedMode == 'job'
                            ? const Color(0xFF065F46)
                            : const Color(0xFF1E3A8A),
                        borderRadius: BorderRadius.circular(20)),
                    child: Text(
                        _selectedMode == 'job'
                            ? 'พิมพ์ลงฟอร์มสำเร็จรูป'
                            : 'พิมพ์กระดาษต่อเนื่อง (RAW)',
                        style: TextStyle(
                            color: _selectedMode == 'job'
                                ? const Color(0xFF34D399)
                                : const Color(0xFF93C5FD),
                            fontSize: 12,
                            fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ChoiceChip(
                    label: const Text('📋 ใบสั่งปฏิบัติงาน (Job Order)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    selected: _selectedMode == 'job',
                    selectedColor: const Color(0xFFD1FAE5),
                    onSelected: (bool selected) {
                      if (selected) setState(() => _selectedMode = 'job');
                    },
                  ),
                  const SizedBox(width: 12),
                  ChoiceChip(
                    label: const Text('⛽ ใบสั่งเติมน้ำมัน (Fuel Order)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    selected: _selectedMode == 'fuel',
                    selectedColor: const Color(0xFFDBEAFE),
                    onSelected: (bool selected) {
                      if (selected) setState(() => _selectedMode = 'fuel');
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
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildDateInput(_startDateCtrl, 'ตั้งแต่วันที่'),
                        const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Text('-')),
                        _buildDateInput(_endDateCtrl, 'ถึงวันที่'),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF10B981),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 16)),
                          onPressed: state.isLoading
                              ? null
                              : () => notifier.fetchJobs(_selectedMode,
                                  _startDateCtrl.text, _endDateCtrl.text),
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
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.print,
                            color: Color(0xFF4B5563), size: 20),
                        const SizedBox(width: 8),
                        const Text('เครื่องพิมพ์:',
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: Color(0xFF374151))),
                        const SizedBox(width: 8),
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
                        IconButton(
                          icon: const Icon(Icons.refresh,
                              color: Color(0xFF6B7280)),
                          tooltip: 'รีเฟรชเครื่องพิมพ์',
                          onPressed: notifier.fetchPrinters,
                        )
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2563EB),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 16),
                        disabledBackgroundColor: const Color(0xFF9CA3AF),
                      ),
                      onPressed:
                          (state.selectedKeys.isEmpty || state.isPrinting)
                              ? null
                              : () => notifier.printSelectedJobs(_selectedMode),
                      icon: state.isPrinting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.print_outlined, size: 20),
                      label: Text(
                          '🖨️ สั่งพิมพ์ (${state.selectedKeys.length})',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                    ),
                  ],
                ),
              ),
              if (state.statusMessage.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: state.isError
                        ? const Color(0xFFFEE2E2)
                        : const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                        color: state.isError
                            ? const Color(0xFFEF4444)
                            : const Color(0xFF10B981)),
                  ),
                  child: Text(
                    state.statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: state.isError
                            ? const Color(0xFF991B1B)
                            : const Color(0xFF166534),
                        fontSize: 14),
                  ),
                ),
              const SizedBox(height: 16),
              if (state.jobs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8, left: 4),
                  child: Row(
                    children: [
                      Checkbox(
                        value: state.selectedKeys.length == state.jobs.length,
                        onChanged: (val) => notifier.selectAll(val ?? false),
                      ),
                      const Text('เลือกทั้งหมด',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 14)),
                      const Spacer(),
                      Text('แสดงทั้งหมด ${state.jobs.length} รายการ',
                          style: const TextStyle(
                              color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ),
              Expanded(
                child: state.isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : state.jobs.isEmpty
                        ? const Center(
                            child: Text(
                                'ไม่มีข้อมูล กดปุ่มค้นหาเพื่อดึงข้อมูลใหม่...',
                                style: TextStyle(
                                    color: Colors.grey, fontSize: 15)))
                        : ListView.builder(
                            itemCount: state.jobs.length,
                            itemBuilder: (context, index) {
                              final item = state.jobs[index];

                              final uniqueKey = _selectedMode == 'job'
                                  ? '${item['job_no']}_$index'
                                  : '${item['fleet_id']}_$index';

                              final isSelected =
                                  state.selectedKeys.contains(uniqueKey);

                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? const Color(0xFFEFF6FF)
                                      : Colors.white,
                                  border: Border.all(
                                      color: isSelected
                                          ? const Color(0xFF3B82F6)
                                          : const Color(0xFFE5E7EB)),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: ListTile(
                                  onTap: () =>
                                      notifier.toggleSelection(uniqueKey),
                                  leading: Checkbox(
                                    value: isSelected,
                                    onChanged: (_) =>
                                        notifier.toggleSelection(uniqueKey),
                                  ),
                                  title: Text(
                                    _selectedMode == 'job'
                                        ? 'Job No: ${item['job_no']} | ลูกค้า: ${item['customer_name'] ?? '-'}'
                                        : 'ทะเบียน: ${item['vehicle_name'] ?? '-'} | Job: ${item['job_no'] ?? '-'}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: Color(0xFF111827)),
                                  ),
                                  subtitle: Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Row(
                                      children: [
                                        Expanded(
                                            child: Text(
                                                _selectedMode == 'job'
                                                    ? 'ประเภทงาน: ${item['type_name'] ?? '-'}'
                                                    : 'วันที่: ${item['finish_date'] != null ? DateFormat('dd/MM/yyyy').format(DateTime.parse(item['finish_date'])) : '-'} | คนขับ: ${item['driver'] ?? '-'}',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF4B5563)))),
                                        Expanded(
                                            child: Text(
                                                _selectedMode == 'job'
                                                    ? 'ทะเบียนรถ: ${item['vehicle_name'] ?? '-'} | ตู้: ${item['container_no'] ?? '-'}'
                                                    : 'ปริมาณน้ำมัน: ${item['fuel_qty'] ?? 0} ลิตร',
                                                style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Color(0xFF4B5563)))),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
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
