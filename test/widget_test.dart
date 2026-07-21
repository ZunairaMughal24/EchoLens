import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:echolens/main.dart';

void main() {
  testWidgets('EchoLens boots into the spatial scan screen', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: EchoLensApp()));
    await tester.pump();

    expect(find.text('EchoLens'), findsOneWidget);
    expect(find.text('SCANNING PHYSICAL SPACE'), findsOneWidget);

    // flutter_animate schedules each entrance effect's `delay` via an
    // uncancellable Future.delayed, so give the longest-delayed card
    // (index 5 * 120ms) time to fire before tearing down. The Pulse Core
    // radar itself animates forever by design, so pumpAndSettle() would
    // never return — unmount explicitly instead to dispose its ticker and
    // cancel the live-scan stream subscription.
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pumpWidget(const SizedBox());
  });
}
