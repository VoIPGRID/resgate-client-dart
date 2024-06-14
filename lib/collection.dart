import 'dart:async';
import 'dart:collection';

import 'package:resgate_client/client.dart';
import 'package:resgate_client/model.dart';

class ResCollection<T extends ResModel> {
  // Everytime the collection is updated an event is added to this stream.
  // This allows clients to add multiple listeners per collection.
  final StreamController<T> _addEventsController = StreamController.broadcast();
  final StreamController<T> _removeEventsController =
      StreamController.broadcast();

  final ResClient _client;
  final T Function() _modelFactory;
  final List<T> _models = [];

  final String rid;
  final Map data;

  ResCollection({
    required ResClient client,
    required this.rid,
    required T Function() modelFactory,
    required this.data,
  })  : _client = client,
        _modelFactory = modelFactory {
    // Go through the data of the collection and create instances for each model.
    final List modelRids = data["collections"][rid];

    for (var ridData in modelRids) {
      final rid = ridData["rid"];
      final modelData = data["models"][rid];
      _models.add(_createModelFromJson(rid, modelData));
    }

    // Listen to add events for this collection.
    _client.listen(
      (msg) {
        final rid = msg["data"]["value"]["rid"];
        final idx = msg["data"]["idx"];
        final data = msg["data"]["models"][rid];
        final model = _createModelFromJson(rid, data);

        _models.insert(idx, model);
        _addEventsController.add(model);
      },
      filter: (msg) => msg["event"] == "$rid.add",
    );

    // Listen to remove events for this collection.
    _client.listen(
      (msg) {
        final idx = msg["data"]["idx"];
        final model = _models.removeAt(idx);

        model.destroy();
        _removeEventsController.add(model);
      },
      filter: (msg) => msg["event"] == "$rid.remove",
    );
  }

  /// Execute [handler] everytime a model is added to this colletion.
  StreamSubscription onAdd(void Function(T) handler) {
    return _addEventsController.stream.listen((model) => handler(model));
  }

  /// Execute [handler] everytime a model is removed from the collection.
  StreamSubscription onRemove(void Function(T) handler) {
    return _removeEventsController.stream.listen((model) => handler(model));
  }

  /// Create an instance of a model, add it to the list and listen for events.
  T _createModelFromJson(String rid, Map json) {
    final model = _modelFactory();
    model.init(_client, rid);
    model.updateFromJson(json);
    return model;
  }

  /// Unsubscribe from this collection and close the event streams.
  void destroy() {
    _client.send("unsubscribe", rid, null);
    _addEventsController.close();
    _removeEventsController.close();
  }

  /// Get a read-only list of the models within this collection.
  UnmodifiableListView<T> get models {
    return UnmodifiableListView(_models);
  }
}
