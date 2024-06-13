import 'package:resgate_client/client.dart';
import 'package:resgate_client/data.dart';

class QueueModel extends ResModel {
  int waitingCallers;

  QueueModel({
    required this.waitingCallers,
  });

  factory QueueModel.fromJson(Map json) {
    return QueueModel(
      waitingCallers: json["waiting_callers"],
    );
  }
}

void main() async {
  final client =
      ResClient('wss://frontend-resgate-mocking.stag.holodeck.spindle.dev');

  await client.authenticate("usertoken.login", {"token": "my-vg-api-token"});

  final collection = await client.getCollection(
      "dashboard.client.abc-123", (json) => QueueModel.fromJson(json));

  collection.models[2].stream.listen(print);
}
