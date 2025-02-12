import 'dart:async';

import 'client.dart';

abstract class ResModel {
  // Everytime the model is updated an event is added to this stream.
  // This allows clients to add multiple listeners per model.
  StreamController<Map<String, dynamic>> changeEventsController =
      StreamController.broadcast();

  // Use late initialization for these properties so it is easier for the
  // developers that use this abstract class to inherit from for their own models.
  // As these properties are initialized by the collection they are part of.
  late ResClient client;
  late StreamSubscription changeListener;
  late String rid;

  /// Listen to change events for this model.
  void listen() {
    changeListener = client.listen(
      (msg) {
        var updatedValues = msg["data"]["values"] as Map<String, dynamic>;
        updateFromJson(updatedValues);
        changeEventsController.add(updatedValues);
      },
      filter: (msg) => msg["event"] == "$rid.change",
    );
  }

  /// Execute [handler] everytime this model receives an update (change event).
  StreamSubscription onChange(void Function(Map<String, dynamic>) handler) {
    return changeEventsController.stream.listen((values) => handler(values));
  }

  /// Close the event stream and stop listening for changes.
  Future<void> destroy() async {
    await changeEventsController.close();
    await changeListener.cancel();
  }

  /// Update the data of this model using the [json] data.
  /// NOTE: only the updated values are available in the [json] data.
  void updateFromJson(Map<String, dynamic> json);
}
