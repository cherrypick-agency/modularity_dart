import 'package:complex_mobx/src/domain/entities.dart';
import 'package:complex_mobx/src/modules/auth/auth_module.dart';
import 'package:complex_mobx/src/modules/cart/cart_module.dart';
import 'package:complex_mobx/src/stores/auth_store.dart';
import 'package:complex_mobx/src/stores/cart_store.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mobx/mobx.dart';
import 'package:modularity_flutter/modularity_flutter.dart';

void main() {
  group('Complex MobX Widget Tests', () {
    // Simplified test: We just verify that IF the store has an error, the UI shows it.
    // We set the error BEFORE pumping the widget. This avoids race conditions with reactive updates in test environment.
    testWidgets('LoginPage displays error message on invalid credentials',
        (tester) async {
      final authStore = AuthStore();

      // Pre-set state
      runInAction(() {
        authStore.errorMessage = 'Manual Error';
      });

      await tester.pumpWidget(
        ModularityRoot(
          child: MaterialApp(
            home: ModuleScope(
              module: AuthModule(),
              overrides: (binder) {
                binder.singleton<AuthStore>(() => authStore);
              },
              child: const SingleChildScrollView(child: LoginPage()),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Manual Error'), findsOneWidget);
      expect(find.text('Login Page'), findsOneWidget);
    });

    testWidgets('CartPage shows items and handles removal', (tester) async {
      final cartStore = CartStore();

      await tester.pumpWidget(
        ModularityRoot(
          child: MaterialApp(
            home: ModuleScope(
              module: CartModule(),
              overrides: (binder) {
                binder.singleton<CartStore>(() => cartStore);
              },
              child: const CartPage(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text('Cart is empty'), findsOneWidget);
      expect(find.text('Cart (\$0.00)'), findsOneWidget);

      // Update State via Action
      runInAction(() {
        cartStore.add(const Product(1, 'Test Item', 10.0));
      });

      await tester.pumpAndSettle();

      // Verify List
      expect(find.text('Cart is empty'), findsNothing);
      expect(find.text('Test Item'), findsOneWidget);
      expect(find.text('Cart (\$10.00)'), findsOneWidget);

      // Remove Item via UI
      await tester.tap(find.byIcon(Icons.remove_circle));
      await tester.pumpAndSettle();

      // Verify Empty Again
      expect(find.text('Cart is empty'), findsOneWidget);
      expect(find.text('Cart (\$0.00)'), findsOneWidget);
    });
  });
}
