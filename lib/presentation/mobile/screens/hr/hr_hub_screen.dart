// The HR hub — one Admin destination holding the three payroll surfaces as
// tabs (Employees | Payroll | Payslips), with HR Settings behind the gear.
// Mirrors the web sidebar's Admin > HR group.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:maki_mobile_pos/config/router/router.dart';
import 'package:maki_mobile_pos/core/extensions/navigation_extensions.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/hr/employees_tab.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/hr/payroll_tab.dart';
import 'package:maki_mobile_pos/presentation/mobile/screens/hr/payslips_tab.dart';

class HrHubScreen extends StatelessWidget {
  const HrHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(LucideIcons.chevronLeft),
            onPressed: () => context.goBackOr(RoutePaths.dashboard),
          ),
          title: const Text('HR'),
          actions: [
            IconButton(
              icon: const Icon(LucideIcons.calendarCog),
              tooltip: 'HR Settings',
              onPressed: () => context.push(RoutePaths.hrSettings),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Employees'),
              Tab(text: 'Payroll'),
              Tab(text: 'Payslips'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            EmployeesTab(),
            PayrollTab(),
            PayslipsTab(),
          ],
        ),
      ),
    );
  }
}
