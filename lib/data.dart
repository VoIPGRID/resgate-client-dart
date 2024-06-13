import 'dart:async';

import 'package:resgate_client/client.dart';

class ResException implements Exception {
  Map data;

  ResException(this.data);

  get id {
    return data["id"];
  }

  get message {
    return data["error"]["message"];
  }

  get code {
    return data["error"]["code"];
  }

  @override
  String toString() {
    return "Resgate error for message with id: $id -> $message ($code)";
  }
}

class ResModel {
  /// The model specific event stream, everytime the model is updated an event
  /// is added to this stream. This allows clients to listen to change
  /// events per model.
  final StreamController<Map> _stream = StreamController.broadcast();

  late ResClient client;
  late String rid;
  late StreamSubscription _changes;

  _listen() {
    _changes = client.listen(
      (json) => _stream.add(json["data"]["values"]),
      (json) => json["event"] == "$rid.change",
    );
  }

  _stop() {
    _changes.cancel();
  }

  get stream {
    return _stream.stream;
  }
}

class ResCollection<T extends ResModel> {
  ResClient client;
  String rid;
  Map data;
  T Function(Map) modelFromJson;

  List<T> models = [];

  ResCollection({
    required this.client,
    required this.rid,
    required this.data,
    required this.modelFromJson,
  }) {
    (data["models"] as Map).forEach(
      (key, value) {
        models.add(_createModelFromJson(key, value));
      },
    );
  }

  _createModelFromJson(String rid, Map json) {
    final model = modelFromJson(json);
    model.client = client;
    model.rid = rid;
    model._listen();
    return model;
  }

  _onAdd(String rid, Map json) {
    models.add(_createModelFromJson(rid, json));
  }

  _onRemove(String rid) {
    final model = (models as List<T?>)
        .singleWhere((model) => model!.rid == rid, orElse: () => null);

    if (model != null) {
      models.remove(model);
      model._stop();
    }
  }
}
