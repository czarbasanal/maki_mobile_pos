import 'package:flutter_test/flutter_test.dart';
import 'package:maki_mobile_pos/presentation/providers/cart_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/inventory_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/receiving_provider.dart';
import 'package:maki_mobile_pos/presentation/providers/user_provider.dart';

void main() {
  group('UserOperationsState value equality', () {
    test('identical fields compare equal', () {
      // ignore: prefer_const_constructors
      final a = UserOperationsState(isLoading: true);
      // ignore: prefer_const_constructors
      final b = UserOperationsState(isLoading: true);
      expect(identical(a, b), isFalse);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
    test('differing fields compare unequal', () {
      // ignore: prefer_const_constructors
      final a = UserOperationsState(isLoading: true);
      // ignore: prefer_const_constructors
      final b = UserOperationsState(isLoading: false);
      expect(a, isNot(equals(b)));
    });
  });

  group('InventoryState value equality', () {
    test('identical fields compare equal', () {
      // ignore: prefer_const_constructors
      final a = InventoryState(searchQuery: 'x');
      // ignore: prefer_const_constructors
      final b = InventoryState(searchQuery: 'x');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
    test('differing fields compare unequal', () {
      // ignore: prefer_const_constructors
      final a = InventoryState(searchQuery: 'x');
      // ignore: prefer_const_constructors
      final b = InventoryState(searchQuery: 'y');
      expect(a, isNot(equals(b)));
    });
  });

  group('CartState value equality', () {
    test('identical fields compare equal', () {
      // ignore: prefer_const_constructors
      final a = CartState(amountReceived: 10);
      // ignore: prefer_const_constructors
      final b = CartState(amountReceived: 10);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
    test('differing fields compare unequal', () {
      // ignore: prefer_const_constructors
      final a = CartState(amountReceived: 10);
      // ignore: prefer_const_constructors
      final b = CartState(amountReceived: 20);
      expect(a, isNot(equals(b)));
    });
  });

  group('CurrentReceivingState value equality', () {
    test('identical fields compare equal', () {
      // ignore: prefer_const_constructors
      final a = CurrentReceivingState(referenceNumber: 'RCV-1');
      // ignore: prefer_const_constructors
      final b = CurrentReceivingState(referenceNumber: 'RCV-1');
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
    test('differing fields compare unequal', () {
      // ignore: prefer_const_constructors
      final a = CurrentReceivingState(referenceNumber: 'RCV-1');
      // ignore: prefer_const_constructors
      final b = CurrentReceivingState(referenceNumber: 'RCV-2');
      expect(a, isNot(equals(b)));
    });
  });
}
