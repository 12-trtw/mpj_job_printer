import 'package:get/get.dart';

class JobModel {
  final String id;
  final String jobNo;
  final DateTime? jobStart;
  final String vehicleName;
  final RxBool isSelected;

  JobModel({
    required this.id,
    required this.jobNo,
    this.jobStart,
    required this.vehicleName,
    bool selected = false,
  }) : isSelected = selected.obs;

  String get formattedJobStart {
    if (jobStart == null) return '-';
    return '${jobStart!.day}/${jobStart!.month}/${jobStart!.year + 543}';
  }

  factory JobModel.fromJson(Map<String, dynamic> json) {
    return JobModel(
      id: json['fleet_id']?.toString() ??
          json['order_number']?.toString() ??
          '',
      jobNo: json['job_no']?.toString() ?? '-',
      jobStart: json['job_start'] != null
          ? DateTime.tryParse(json['job_start'])
          : null,
      vehicleName: json['vehicle_name']?.toString() ?? '-',
    );
  }
}
