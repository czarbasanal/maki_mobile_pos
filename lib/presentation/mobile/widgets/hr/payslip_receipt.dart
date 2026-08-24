// Receipt-style payslip — the mobile render of the design handoff already
// shipped on web (web_admin PayslipCard): dark #121c1d header with the yellow
// MAKI mark and two-line company name, centered employee block, dashed-rule
// attendance chips, earnings rows with a mono hours×rate note, deduction
// amounts in #b23b3b, dashed totals with the '– ' prefix, the dark NET PAY
// bar with the brand-yellow label, and the system-generated footnote.
//
// Deliberate substitutions vs web, both accepted in the plan:
// - Fonts: the app's Figtree/RobotoMono instead of Inter/JetBrains Mono —
//   layout and color carry the design.
// - The design colors are fixed (a receipt looks the same in dark mode), so
//   values are hardcoded hex, not theme tokens.
//
// Renders the STORED computed figures verbatim — a payslip is a frozen
// snapshot (rules: update:false); nothing here recomputes.
import 'package:flutter/material.dart';
import 'package:maki_mobile_pos/core/theme/theme.dart';
import 'package:maki_mobile_pos/core/extensions/num_extensions.dart';
import 'package:maki_mobile_pos/domain/entities/entities.dart';
import 'package:maki_mobile_pos/domain/hr/pay_period.dart';

const _ink = Color(0xFF121C1D);
const _body = Color(0xFF1E2829);
const _secondary = Color(0xFF4A5152);
const _muted = Color(0xFF6B7273);
const _faint = Color(0xFF8A9192);
const _faintNote = Color(0xFFA3A9A9);
const _headerSub = Color(0xFF9AA5A6);
const _yellow = Color(0xFFF5B921);
const _deductionRed = Color(0xFFB23B3B);
const _rule = Color(0xFFCFD3D3);

class PayslipReceipt extends StatelessWidget {
  const PayslipReceipt({super.key, required this.payslip});

  final PayslipEntity payslip;

  @override
  Widget build(BuildContext context) {
    final c = payslip.computed;
    final i = payslip.inputs;

    return Container(
      width: 380,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _employeeBlock(),
                const SizedBox(height: 20),
                _attendance(),
                const SizedBox(height: 20),
                _sectionLabel('Earnings'),
                const SizedBox(height: 10),
                _row('Base Pay', c.basePay,
                    note:
                        '${_trimZero(i.hoursWorked)}h × ${c.hourlyRate.toCurrency()}/hr'),
                const SizedBox(height: 9),
                _row('Overtime', c.overtimePay),
                const SizedBox(height: 9),
                _row('Holiday Pay', c.holidayPay),
                const SizedBox(height: 9),
                _row('Incentives', i.incentives),
                if (_deductionRows().isNotEmpty) ...[
                  const SizedBox(height: 18),
                  _sectionLabel('Deductions'),
                  const SizedBox(height: 10),
                  for (final (index, d) in _deductionRows().indexed) ...[
                    if (index > 0) const SizedBox(height: 9),
                    _row(d.$1, d.$2, deduction: true),
                  ],
                ],
                const SizedBox(height: 18),
                _totals(c),
                const SizedBox(height: 16),
                _netPayBar(c.net),
              ],
            ),
          ),
          _footer(),
        ],
      ),
    );
  }

  Widget _header() {
    return Container(
      color: _ink,
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 20),
      child: Row(
        children: [
          Image.asset(
            'assets/icon/maki_logo_yellow.png',
            width: 40,
            height: 40,
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'MAKI MOTORCYCLE PARTS\n& ACCESSORIES SHOP',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Buanoy, Balamban, Cebu',
                  style: TextStyle(
                    color: _headerSub,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _employeeBlock() {
    return Column(
      children: [
        const Text(
          'PAYSLIP',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: _faint,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          payslip.employeeName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w700,
            color: _ink,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _periodLabel(payslip.periodStart, payslip.periodEnd),
          style: const TextStyle(fontSize: 13, color: _muted),
        ),
      ],
    );
  }

  Widget _attendance() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        border: Border(
          top: BorderSide(color: _rule, width: 1),
          bottom: BorderSide(color: _rule, width: 1),
        ),
      ),
      child: Column(
        children: [
          const Text(
            'ATTENDANCE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.4,
              color: _faint,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final day in payslip.days) Expanded(child: _dayChip(day)),
            ],
          ),
        ],
      ),
    );
  }

  static const _chip = {
    // Design defines present ✓ green and off — gray; absent renders on the
    // off-gray with an ✗ in the deduction red — the same deliberate extension
    // the web card carries (an absent day must not look like a day off when
    // Absences is deducted).
    DayStatus.present: (Color(0xFFE8F0EC), Color(0xFF2F7D5B), '✓'),
    DayStatus.dayOff: (Color(0xFFF0F1F1), Color(0xFFB0B6B6), '—'),
    DayStatus.absent: (Color(0xFFF0F1F1), _deductionRed, '✗'),
  };

  static const _weekdayLabels = [
    'MON',
    'TUE',
    'WED',
    'THU',
    'FRI',
    'SAT',
    'SUN'
  ];

  Widget _dayChip(PayslipDay day) {
    final (bg, fg, mark) = _chip[day.status]!;
    final weekday = parseIsoLocalDate(day.date).weekday;
    return Column(
      children: [
        Text(
          _weekdayLabels[weekday - 1],
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: _faint,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 24,
          height: 24,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
          child: Text(
            mark,
            style:
                TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg),
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: _faint,
      ),
    );
  }

  List<(String, double)> _deductionRows() {
    final d = payslip.inputs.deductions;
    return [
      if (d.sss != 0) ('SSS', d.sss),
      if (d.philhealth != 0) ('PhilHealth', d.philhealth),
      if (d.pagibig != 0) ('Pag-IBIG', d.pagibig),
      if (d.late != 0) ('Late', d.late),
      if (d.absences != 0) ('Absences', d.absences),
      if (d.cashAdvance != 0) ('Cash advance', d.cashAdvance),
      for (final o in d.others) (o.label, o.amount),
    ];
  }

  Widget _row(String label, double amount,
      {String? note, bool deduction = false}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              text: label,
              style: const TextStyle(fontSize: 14, color: _body),
              children: [
                if (note != null)
                  TextSpan(
                    text: '  $note',
                    style: TextStyle(
                      fontSize: 11,
                      color: const Color(0xFF9AA0A0),
                      fontFamily: AppTextStyles.monoFontFamily,
                    ),
                  ),
              ],
            ),
          ),
        ),
        Text(
          amount.toCurrency(),
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: deduction ? _deductionRed : _body,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _totals(PayslipComputed c) {
    return Container(
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _rule, width: 1)),
      ),
      child: Column(
        children: [
          _totalRow('Gross', c.gross.toCurrency()),
          const SizedBox(height: 8),
          _totalRow('Total Deductions', '– ${c.totalDeductions.toCurrency()}'),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Text(label,
              style: const TextStyle(fontSize: 14, color: _secondary)),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            color: _secondary,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _netPayBar(double net) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: _ink,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Expanded(
            child: Text(
              'NET PAY',
              style: TextStyle(
                color: _yellow,
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
              ),
            ),
          ),
          Text(
            net.toCurrency(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 23,
              fontWeight: FontWeight.w800,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _footer() {
    return Container(
      padding: const EdgeInsets.fromLTRB(28, 16, 28, 22),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _rule, width: 1)),
      ),
      child: Column(
        children: [
          Text(
            'Generated ${_generatedLabel(payslip.createdAt)}',
            style: const TextStyle(fontSize: 12, color: _muted),
          ),
          const SizedBox(height: 4),
          Text(
            'This is a System-Generated payslip. No signature required.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: _faintNote,
              letterSpacing: 0.4,
              fontFamily: AppTextStyles.monoFontFamily,
            ),
          ),
        ],
      ),
    );
  }

  static String _trimZero(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  static String _periodLabel(String start, String end) {
    final s = parseIsoLocalDate(start);
    final e = parseIsoLocalDate(end);
    return '${_months[s.month - 1]} ${s.day} – ${_months[e.month - 1]} ${e.day}, ${e.year}';
  }

  static String _generatedLabel(DateTime? createdAt) {
    if (createdAt == null) return '—';
    return '${_months[createdAt.month - 1]} ${createdAt.day}, ${createdAt.year}';
  }
}
