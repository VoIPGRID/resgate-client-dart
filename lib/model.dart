import 'dart:async';

import 'package:resgate_client/client.dart';

abstract class ResModel {
  /// Everytime the model is updated an event is added to this stream.
  /// This allows clients to add multiple listeners per model.
  final StreamController _changeController = StreamController.broadcast();

  // Use late initialization for these properties so it is easier for the
  // clients to create their own models.
  late final ResClient _client;
  late final String _rid;
  late final StreamSubscription _changeListener;

  init(ResClient client, String rid) {
    _client = client;
    _rid = rid;
    _listen();
  }

  _listen() {
    _changeListener = _client.listen(
      (json) {
        final values = json["data"]["values"];
        updateFromJson(values);
        _changeController.add(values);
      },
      filter: (json) => json["event"] == "$_rid.change",
    );
  }

  /// Listen to changes to this model.
  StreamSubscription onChange(void Function(Map) handler) {
    return _changeController.stream.listen((values) => handler(values));
  }

  /// This model should not be used anymore after being destroyed as no events
  /// will be emitted from this model anymore.
  destroy() {
    _changeController.close();
    _changeListener.cancel();
  }

  updateFromJson(Map json);
}
