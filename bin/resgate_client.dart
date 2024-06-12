import 'package:resgate_client/resgate_client.dart';

void main() async {
  final client =
      ResClient('wss://frontend-resgate-mocking.stag.holodeck.spindle.dev');

  final version = await client.version();
  final auth = await client.authenticate();
  final collection = await client.subscribe("availability.client.abc-123");

  print(version);
  print(auth);
  print(collection);
}
