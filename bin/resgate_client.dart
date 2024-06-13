import 'package:resgate_client/client.dart';
import 'package:resgate_client/model.dart';

class QueueModel extends ResModel {
  int waitingCallers = 0;

  @override
  updatFromJson(Map json) {
    if (json.containsKey("waiting_callers")) {
      waitingCallers = json["waiting_callers"];
    }
  }
}

void main() async {
  final client =
      ResClient('wss://frontend-resgate-mocking.stag.holodeck.spindle.dev');

  await client.version();
  await client.authenticate("usertoken.login", {"token": "my-vg-api-token"});

  final collection = await client.getCollection(
      "dashboard.client.abc-123", () => QueueModel());

  collection.models[2].stream.listen(print);
}
