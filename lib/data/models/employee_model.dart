import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Data model for [EmployeeEntity] with Firestore serialization.
///
/// Doc shape is shared with the web admin (employeeConverter.ts): timestamps
/// only, no actor attribution (an accepted slice-1 decision), `weekStartDay`
/// null = use the shop-wide HR setting, and `payslipDefaults` a nested map
/// that create never writes at all — only "Save as defaults" does.
class EmployeeModel {
  final String id;
  final String name;
  final double dailyRate;
  final bool isActive;
  final int? weekStartDay;
  final PayslipDefaults? payslipDefaults;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const EmployeeModel({
    required this.id,
    required this.name,
    required this.dailyRate,
    required this.isActive,
    this.weekStartDay,
    this.payslipDefaults,
    this.createdAt,
    this.updatedAt,
  });

  factory EmployeeModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      EmployeeModel.fromMap(doc.data()!, doc.id);

  factory EmployeeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return EmployeeModel(
      id: documentId,
      name: map['name'] as String? ?? '',
      dailyRate: _num(map['dailyRate']),
      isActive: map['isActive'] as bool? ?? true,
      weekStartDay: (map['weekStartDay'] as num?)?.toInt(),
      payslipDefaults: _defaultsFromMap(map['payslipDefaults']),
      createdAt: _parseTimestamp(map['createdAt']),
      updatedAt: _parseTimestamp(map['updatedAt']),
    );
  }

  static PayslipDefaults? _defaultsFromMap(dynamic raw) {
    if (raw is! Map) return null;
    final map = Map<String, dynamic>.from(raw);
    return PayslipDefaults(
      hoursWorked: _num(map['hoursWorked']),
      overtimeHours: _num(map['overtimeHours']),
      overtimeRatePerHour: _num(map['overtimeRatePerHour']),
      regularHolidayDays: _num(map['regularHolidayDays']),
      specialHolidayDays: _num(map['specialHolidayDays']),
      incentives: _num(map['incentives']),
      deductions: deductionsFromMap(map['deductions']),
      dayPattern: (map['dayPattern'] is List)
          ? (map['dayPattern'] as List)
              .map((v) => DayStatus.fromString(v as String?))
              .toList()
          : const [],
    );
  }

  /// Shared with [PayslipModel] — the nested deductions map is identical on
  /// both docs.
  static PayslipDeductions deductionsFromMap(dynamic raw) {
    if (raw is! Map) return PayslipDeductions.empty;
    final map = Map<String, dynamic>.from(raw);
    return PayslipDeductions(
      sss: _num(map['sss']),
      philhealth: _num(map['philhealth']),
      pagibig: _num(map['pagibig']),
      late: _num(map['late']),
      absences: _num(map['absences']),
      cashAdvance: _num(map['cashAdvance']),
      others: (map['others'] is List)
          ? (map['others'] as List)
              .whereType<Map>()
              .map((o) => OtherDeduction(
                    label: o['label'] as String? ?? '',
                    amount: _num(o['amount']),
                  ))
              .toList()
          : const [],
    );
  }

  static Map<String, dynamic> deductionsToMap(PayslipDeductions d) => {
        'sss': d.sss,
        'philhealth': d.philhealth,
        'pagibig': d.pagibig,
        'late': d.late,
        'absences': d.absences,
        'cashAdvance': d.cashAdvance,
        'others': d.others
            .map((o) => {'label': o.label, 'amount': o.amount})
            .toList(),
      };

  static Map<String, dynamic> defaultsToMap(PayslipDefaults d) => {
        'hoursWorked': d.hoursWorked,
        'overtimeHours': d.overtimeHours,
        'overtimeRatePerHour': d.overtimeRatePerHour,
        'regularHolidayDays': d.regularHolidayDays,
        'specialHolidayDays': d.specialHolidayDays,
        'incentives': d.incentives,
        'deductions': deductionsToMap(d.deductions),
        'dayPattern': d.dayPattern.map((s) => s.value).toList(),
      };

  Map<String, dynamic> toMap({bool forCreate = false, bool forUpdate = false}) {
    final map = <String, dynamic>{
      'name': name,
      'dailyRate': dailyRate,
      'isActive': isActive,
      'weekStartDay': weekStartDay,
    };

    if (forCreate) {
      // Web parity: create never writes a payslipDefaults key — the field
      // only appears once "Save as defaults" runs.
      map['createdAt'] = FieldValue.serverTimestamp();
      map['updatedAt'] = FieldValue.serverTimestamp();
    } else if (forUpdate) {
      map['updatedAt'] = FieldValue.serverTimestamp();
      map['payslipDefaults'] =
          payslipDefaults == null ? null : defaultsToMap(payslipDefaults!);
    } else {
      map['payslipDefaults'] =
          payslipDefaults == null ? null : defaultsToMap(payslipDefaults!);
      if (createdAt != null) map['createdAt'] = Timestamp.fromDate(createdAt!);
      if (updatedAt != null) map['updatedAt'] = Timestamp.fromDate(updatedAt!);
    }
    return map;
  }

  EmployeeEntity toEntity() => EmployeeEntity(
        id: id,
        name: name,
        dailyRate: dailyRate,
        isActive: isActive,
        weekStartDay: weekStartDay,
        payslipDefaults: payslipDefaults,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  factory EmployeeModel.fromEntity(EmployeeEntity e) => EmployeeModel(
        id: e.id,
        name: e.name,
        dailyRate: e.dailyRate,
        isActive: e.isActive,
        weekStartDay: e.weekStartDay,
        payslipDefaults: e.payslipDefaults,
        createdAt: e.createdAt,
        updatedAt: e.updatedAt,
      );

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
