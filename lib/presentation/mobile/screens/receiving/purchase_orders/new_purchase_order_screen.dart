import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Reorder-suggestions screen; drafts one PO per supplier. Built in Task 13.
class NewPurchaseOrderScreen extends ConsumerStatefulWidget {
  const NewPurchaseOrderScreen({super.key});

  @override
  ConsumerState<NewPurchaseOrderScreen> createState() =>
      NewPurchaseOrderScreenState();
}

class NewPurchaseOrderScreenState
    extends ConsumerState<NewPurchaseOrderScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Purchase Order')),
      body: const SizedBox.shrink(),
    );
  }
}
