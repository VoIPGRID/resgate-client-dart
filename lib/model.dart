import 'dart:async';

import 'package:resgate_client/client.dart';

class ResModel {
  /// The model specific event stream, everytime the model is updated an event
  /// is added to this stream. This allows clients to listen to change
  /// events per model.
  final StreamController<Map> _stream = StreamController.broadcast();

  // Use late initialization for these properties so it is easier for the
  // clients to deserialize their own models.
  late ResClient client;
  late String rid;
  late StreamSubscription _changes;

  listen() {
    _changes = client.listen(
      (json) {
        _stream.add(json["data"]["values"]);
      },
      filter: (json) => json["event"] == "$rid.change",
    );
  }

  stop() {
    _changes.cancel();
  }

  get stream {
    return _stream.stream;
  }
}
