import 'package:resgate_client/client.dart';
import 'package:resgate_client/model.dart';

class ResCollection<T extends ResModel> {
  final ResClient _client;
  final String _rid;
  final T Function() _modelFactory;

  final Map data;

  /// The list of model instances, do not modify this list!
  final List<T> models = [];

  ResCollection({
    required ResClient client,
    required String rid,
    required T Function() modelFactory,
    required this.data,
  })  : _client = client,
        _rid = rid,
        _modelFactory = modelFactory {
    final Map modelsMap = data["models"];

    for (var MapEntry(key: rid, value: json) in modelsMap.entries) {
      models.add(_createModelFromJson(rid, json));
    }

    // Listen to add events for this collection.
    _client.listen((json) {
      final rid = json["data"]["value"]["rid"];
      final idx = json["data"]["idx"];
      final model = json["data"]["models"][rid];
      models.insert(idx, _createModelFromJson(rid, model));
    }, filter: (json) => json["event"] == "$_rid.add");

    // Listen to remove events for this collection.
    _client.listen((json) {
      final idx = json["data"]["idx"];
      final model = models.removeAt(idx);
      model.destroy();
    }, filter: (json) => json["event"] == "$_rid.remove");
  }

  T _createModelFromJson(String rid, Map json) {
    final model = _modelFactory();
    model.init(_client, rid);
    model.updateFromJson(json);
    return model;
  }
}
