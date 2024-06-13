import 'package:resgate_client/client.dart';
import 'package:resgate_client/model.dart';

class QueueModel extends ResModel {
  int waitingCallers = 0;

  @override
  updateFromJson(Map json) {
    if (json.containsKey("waiting_callers")) {
      waitingCallers = json["waiting_callers"];
    }
  }
}

void main() async {
  final client =
      ResClient('wss://frontend-resgate-mocking.stag.holodeck.spindle.dev');

  await client.authenticate("usertoken.login", {"token": "my-vg-api-token"});

  final collection = await client.getCollection(
      "dashboard.client.abc-123", () => QueueModel());

  final model = collection.models[2];

  model.onChange((values) {
    print(values);
    print(model.waitingCallers);
  });
}
