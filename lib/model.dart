import 'dart:async';

import 'package:resgate_client/client.dart';

abstract class ResModel {
  /// The model specific event stream, everytime the model is updated an event
  /// is added to this stream. This allows clients to listen to change
  /// events per model.
  final StreamController _stream = StreamController.broadcast();

  // Use late initialization for these properties so it is easier for the
  // clients to create their own models.
  late ResClient _client;
  late String _rid;
  late StreamSubscription _changeListener;

  init(ResClient client, String rid) {
    _client = client;
    _rid = rid;
    _listen();
  }

  /// Listen for change events.
  _listen() {
    _changeListener = _client.listen(
      (json) {
        final values = json["data"]["values"];
        updatFromJson(values);
        _stream.add(values);
      },
      filter: (json) => json["event"] == "$_rid.change",
    );
  }

  /// This model should not be used anymore after being destroyed as no events
  /// will be emitted from this model anymore.
  destroy() {
    _changeListener.cancel();
  }

  Stream get stream {
    return _stream.stream;
  }

  updatFromJson(Map json);
}
