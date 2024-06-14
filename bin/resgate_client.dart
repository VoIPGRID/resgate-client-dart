import 'package:resgate_client/client.dart';
import 'package:resgate_client/model.dart';

class QueueModel extends ResModel {
  int waitingCallers = 0;

  @override
  void updateFromJson(Map json) {
    if (json.containsKey("waiting_callers")) {
      waitingCallers = json["waiting_callers"];
    }
  }
}

void main() async {
  final client =
      ResClient('wss://frontend-resgate-mocking.stag.holodeck.spindle.dev');

  // You need to authenticate in order to subscribe.
  // Try commenting this out to see an access denied error.
  await client.authenticate(
    "usertoken.login",
    {
      "token": "my-vg-api-token",
    },
  );

  // Subscribe to a subject, supply the model factory so that each model
  // can be updated on a change event. Hence this model should extend ResModel
  // and implement the `updateFromJson` method.
  final collection = await client.getCollection(
      "dashboard.client.abc-123", () => QueueModel());

  // React when a model is added or removed from a collection.
  collection.onAdd(print);
  collection.onRemove(print);

  // A collection holds an internal list of models that can be read.
  final model = collection.models[2];

  // React when a model updates.
  model.onChange((values) {
    print(values);
    // You can also get the updated value straight from the model instance.
    print(model.waitingCallers);
  });

  // When you're done with the collection you can call destroy on it.
  // collection.destroy();
}
