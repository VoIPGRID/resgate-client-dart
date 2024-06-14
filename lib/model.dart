import 'dart:async';

import 'package:resgate_client/client.dart';

abstract class ResModel {
  // Everytime the model is updated an event is added to this stream.
  // This allows clients to add multiple listeners per model.
  final StreamController<Map> _changeEventsController =
      StreamController.broadcast();

  // Use late initialization for these properties so it is easier for the
  // clients to create their own models.
  late final ResClient _client;
  late final String rid;
  late final StreamSubscription _changeListener;

  /// Initialize the model and start listening for events.
  init(ResClient client, String rid) {
    _client = client;
    this.rid = rid;
    _listen();
  }

  /// Listen for events and broadcast them to those listening to this model.
  _listen() {
    _changeListener = _client.listen(
      (msg) {
        final updatedValues = msg["data"]["values"];

        updateFromJson(updatedValues);
        _changeEventsController.add(updatedValues);
      },
      filter: (msg) => msg["event"] == "$rid.change",
    );
  }

  /// Execute [handler] everytime this model receives an update (change event).
  StreamSubscription onChange(void Function(Map) handler) {
    return _changeEventsController.stream.listen((values) => handler(values));
  }

  /// Close the event stream and stop listening for changes.
  void destroy() {
    _changeEventsController.close();
    _changeListener.cancel();
  }

  /// Update the data of this model using the [json] data.
  /// NOTE: only updated values are available in the [json] data.
  void updateFromJson(Map json);
}
