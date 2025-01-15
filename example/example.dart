import 'package:resgate_client/client.dart';
import 'package:resgate_client/model.dart';

class MyModel extends ResModel {
  int counter = 0;

  @override
  void updateFromJson(Map<String, dynamic> json) {
    if (json.containsKey("counter")) {
      counter = json["counter"];
    }
  }
}

void main() async {
  var client = ResClient();

  client.connect('wss://example.com');

  // You need to authenticate in order to subscribe.
  // Try commenting this out to see an access denied error.
  await client.authenticate(
    "usertoken.login",
    {
      "token": "my-api-token",
    },
  );

  // Subscribe to a subject, supply the model factory so that each model
  // can be updated on a change event. Hence this model should extend ResModel
  // and implement the `updateFromJson` method.
  var collection =
      await client.getCollection("example.collection.1", () => MyModel());

  // React when a model is added or removed from a collection.
  collection.onAdd(print);
  collection.onRemove(print);

  // A collection holds an internal list of models that can be read.
  var model = collection.models[0];

  // React when a model updates.
  model.onChange((values) {
    print(values);
    // You can also get the updated value straight from the model instance.
    print(model.counter);
  });

  // When you're done with the collection you can call destroy on it.
  // collection.destroy();
}
