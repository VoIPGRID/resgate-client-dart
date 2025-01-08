import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:resgate_client/client.dart';
import 'package:resgate_client/model.dart';

class ResCollection<T extends ResModel> {
  // Everytime the collection is updated an event is added to this stream.
  // This allows clients to add multiple listeners per collection.
  StreamController<T> addEventsController = StreamController.broadcast();
  StreamController<T> removeEventsController = StreamController.broadcast();

  ResClient client;
  String rid;
  Map data;
  T Function() modelFactory;

  /// The internal list of models, this should not be accessed directly as the collection maintains this list.
  /// For public use there is a read-only view of the list, see [models].
  final List<T> _models = [];

  ResCollection({
    required this.client,
    required this.rid,
    required this.modelFactory,
    required this.data,
    bool subscribe = true,
  }) {
    // Go through the data of the collection and create instances for each model.
    for (var collection in data["collections"][rid]) {
      var rid = collection["rid"];
      var model = data["models"][rid];
      _models.add(createModelFromJson(rid, model));
    }

    if (subscribe) {
      // Listen to add events for this collection.
      client.listen(
        (msg) {
          var rid = msg["data"]["value"]["rid"];
          var idx = msg["data"]["idx"];
          var data = msg["data"]["models"][rid];
          var model = createModelFromJson(rid, data);
          _models.insert(idx, model);
          addEventsController.add(model);
        },
        filter: (msg) => msg["event"] == "$rid.add",
      );

      // Listen to remove events for this collection.
      client.listen(
        (msg) {
          var idx = msg["data"]["idx"];
          var model = _models.removeAt(idx);
          model.destroy();
          removeEventsController.add(model);
        },
        filter: (msg) => msg["event"] == "$rid.remove",
      );
    }
  }

  /// Execute [handler] everytime a model is added to this collection.
  StreamSubscription onAdd(void Function(T) handler) {
    return addEventsController.stream.listen((model) => handler(model));
  }

  /// Execute [handler] everytime a model is removed from the collection.
  StreamSubscription onRemove(void Function(T) handler) {
    return removeEventsController.stream.listen((model) => handler(model));
  }

  /// Create an instance of a model, add it to the list and listen for events.
  T createModelFromJson(String rid, Map json) {
    var model = modelFactory();
    model.init(client, rid);
    model.updateFromJson(json);
    return model;
  }

  /// Unsubscribe from this collection and close the event streams
  /// Also closes the event stream of each model within this collection.
  void destroy() {
    client.send("unsubscribe", rid, null);

    addEventsController.close();
    removeEventsController.close();

    for (var model in models) {
      model.destroy();
    }
  }

  /// Get a read-only list of the models within this collection.
  UnmodifiableListView<T> get models {
    return UnmodifiableListView(_models);
  }
}
