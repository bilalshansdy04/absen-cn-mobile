import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import '../test/e2e_flow_test.dart' as e2e;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  e2e.main();
}
