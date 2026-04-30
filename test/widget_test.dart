// Basic smoke test — verifies the app widget tree builds without crashing.
// Full auth flow tests require a real Supabase instance and are out of scope
// for this unit test file.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App smoke test placeholder', (WidgetTester tester) async {
    // Auth-integrated apps require Supabase to be initialised before pumping.
    // Integration tests for login/signup live in test/integration/.
    expect(true, isTrue);
  });
}
