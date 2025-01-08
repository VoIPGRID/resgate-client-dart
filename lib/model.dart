import 'dart:async';

import 'package:resgate_client/client.dart';

abstract class ResModel {
  // Everytime the model is updated an event is added to this stream.
  // This allows clients to add multiple listeners per model.
  StreamController<Map> changeEventsController = StreamController.broadcast();

  // Use late initialization for these properties so it is easier for the
  // developers that use this package to create their own models.
  late ResClient client;
  late StreamSubscription changeListener;
  late String rid;

  /// Initialize the model and start listening for events.
  init(ResClient client, String rid) {
    this.client = client;
    this.rid = rid;
    changeListener = client.listen(
      (msg) {
        var updatedValues = msg["data"]["values"];
        updateFromJson(updatedValues);
        changeEventsController.add(updatedValues);
      },
      filter: (msg) => msg["event"] == "$rid.change",
    );
  }

  /// Execute [handler] everytime this model receives an update (change event).
  StreamSubscription onChange(void Function(Map) handler) {
    return changeEventsController.stream.listen((values) => handler(values));
  }

  /// Close the event stream and stop listening for changes.
  void destroy() {
    changeEventsController.close();
    changeListener.cancel();
  }

  /// Update the data of this model using the [json] data.
  /// NOTE: only the updated values are available in the [json] data.
  void updateFromJson(Map json);
}
