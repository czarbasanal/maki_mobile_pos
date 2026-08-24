import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:maki_mobile_pos/data/models/employee_model.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';

double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Data model for [PayslipEntity] — a FROZEN snapshot (firestore.rules:
/// payslips update:false), so this model is create-only by design: there is
/// deliberately no forUpdate path. `computed` is stored verbatim and read
/// back verbatim — never recomputed. Reads are defensive (web's converter has
/// no computed fallback; a malformed doc must not crash the phone).
class PayslipModel {
  final PayslipEntity entity;

  const PayslipModel(this.entity);

  factory PayslipModel.fromEntity(PayslipEntity e) => PayslipModel(e);

  factory PayslipModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) =>
      PayslipModel.fromMap(doc.data()!, doc.id);

  factory PayslipModel.fromMap(Map<String, dynamic> map, String documentId) {
    final inputsRaw =
        map['inputs'] is Map ? Map<String, dynamic>.from(map['inputs'] as Map) : <String, dynamic>{};
    final computedRaw = map['computed'] is Map
        ? Map<String, dynamic>.from(map['computed'] as Map)
        : <String, dynamic>{};
    return PayslipModel(PayslipEntity(
      id: documentId,
      employeeId: map['employeeId'] as String? ?? '',
      employeeName: map['employeeName'] as String? ?? '',
      periodStart: map['periodStart'] as String? ?? '',
      periodEnd: map['periodEnd'] as String? ?? '',
      days: (map['days'] is List)
          ? (map['days'] as List)
              .whereType<Map>()
              .map((d) => PayslipDay(
                    date: d['date'] as String? ?? '',
                    status: DayStatus.fromString(d['status'] as String?),
                  ))
              .toList()
          : const [],
      inputs: PayslipInputs(
        hoursWorked: _num(inputsRaw['hoursWorked']),
        dailyRate: _num(inputsRaw['dailyRate']),
        overtimeHours: _num(inputsRaw['overtimeHours']),
        overtimeRatePerHour: _num(inputsRaw['overtimeRatePerHour']),
        regularHolidayDays: _num(inputsRaw['regularHolidayDays']),
        specialHolidayDays: _num(inputsRaw['specialHolidayDays']),
        regularHolidayPct: _num(inputsRaw['regularHolidayPct']),
        specialHolidayPct: _num(inputsRaw['specialHolidayPct']),
        incentives: _num(inputsRaw['incentives']),
        deductions: EmployeeModel.deductionsFromMap(inputsRaw['deductions']),
      ),
      computed: PayslipComputed(
        hourlyRate: _num(computedRaw['hourlyRate']),
        basePay: _num(computedRaw['basePay']),
        overtimePay: _num(computedRaw['overtimePay']),
        holidayPay: _num(computedRaw['holidayPay']),
        gross: _num(computedRaw['gross']),
        totalDeductions: _num(computedRaw['totalDeductions']),
        net: _num(computedRaw['net']),
      ),
      createdAt: _parseTimestamp(map['createdAt']),
      createdBy: map['createdBy'] as String?,
      createdByName: map['createdByName'] as String?,
    ));
  }

  Map<String, dynamic> toMap({bool forCreate = false}) {
    final e = entity;
    return {
      'employeeId': e.employeeId,
      'employeeName': e.employeeName,
      'periodStart': e.periodStart,
      'periodEnd': e.periodEnd,
      'days': e.days
          .map((d) => {'date': d.date, 'status': d.status.value})
          .toList(),
      'inputs': {
        'hoursWorked': e.inputs.hoursWorked,
        'dailyRate': e.inputs.dailyRate,
        'overtimeHours': e.inputs.overtimeHours,
        'overtimeRatePerHour': e.inputs.overtimeRatePerHour,
        'regularHolidayDays': e.inputs.regularHolidayDays,
        'specialHolidayDays': e.inputs.specialHolidayDays,
        'regularHolidayPct': e.inputs.regularHolidayPct,
        'specialHolidayPct': e.inputs.specialHolidayPct,
        'incentives': e.inputs.incentives,
        'deductions': EmployeeModel.deductionsToMap(e.inputs.deductions),
      },
      'computed': {
        'hourlyRate': e.computed.hourlyRate,
        'basePay': e.computed.basePay,
        'overtimePay': e.computed.overtimePay,
        'holidayPay': e.computed.holidayPay,
        'gross': e.computed.gross,
        'totalDeductions': e.computed.totalDeductions,
        'net': e.computed.net,
      },
      'createdBy': e.createdBy,
      'createdByName': e.createdByName,
      'createdAt': forCreate
          ? FieldValue.serverTimestamp()
          : (e.createdAt != null ? Timestamp.fromDate(e.createdAt!) : null),
    };
  }

  PayslipEntity toEntity() => entity;

  static DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
  }
}
