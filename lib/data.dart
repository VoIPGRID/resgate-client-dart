import 'dart:async';

import 'package:resgate_client/client.dart';

class ResException implements Exception {
  Map data;

  ResException(this.data);

  get message {
    return data["message"];
  }

  get code {
    return data["code"];
  }

  @override
  String toString() {
    return "Resgate error: $message ($code)";
  }
}

class ResModel {
  final StreamController<Map> _broadcast = StreamController.broadcast();

  late ResClient client;
  late String rid;
  late StreamSubscription _changes;

  _listen() async {
    _changes = await client.on('change', rid, (json) {
      _broadcast.add(json["data"]["values"]);
    });
  }

  _stop() {
    _changes.cancel();
  }

  get stream {
    return _broadcast.stream;
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
