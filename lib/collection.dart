import 'dart:async';

import 'package:resgate_client/client.dart';
import 'package:resgate_client/model.dart';

class ResCollection<T extends ResModel> {
  // Everytime the collection is updated an event is added to this stream.
  // This allows clients to add multiple listeners per collection.
  StreamController<T> addEventsController = StreamController.broadcast();
  StreamController<T> removeEventsController = StreamController.broadcast();

  late StreamSubscription<dynamic> addListener;
  late StreamSubscription<dynamic> removeListener;

  ResClient client;
  String rid;
  T Function() modelFactory;
  List<T> models = [];

  ResCollection({
    required this.client,
    required this.rid,
    required this.modelFactory,
  });

  // Listen to the add and remove events for this collection.
  void listen() {
    addListener = client.listen(
      (msg) {
        var rid = msg["data"]["value"]["rid"] as String;
        var idx = msg["data"]["idx"] as int;
        var data = msg["data"]["models"][rid] as Map<String, dynamic>;
        var model = createModelFromJson(rid, data);
        models.insert(idx, model);
        addEventsController.add(model);
      },
      filter: (msg) => msg["event"] == "$rid.add",
    );

    removeListener = client.listen(
      (msg) {
        var idx = msg["data"]["idx"] as int;
        var model = models.removeAt(idx);
        model.destroy();
        removeEventsController.add(model);
      },
      filter: (msg) => msg["event"] == "$rid.remove",
    );
  }

  /// Execute [handler] everytime a model is added to this collection.
  StreamSubscription<T> onAdd(void Function(T) handler) {
    return addEventsController.stream.listen((model) => handler(model));
  }

  /// Execute [handler] everytime a model is removed from the collection.
  StreamSubscription<T> onRemove(void Function(T) handler) {
    return removeEventsController.stream.listen((model) => handler(model));
  }

  /// Go through the data and create instances for each model and add them to the internal list.
  /// Also listens for change events for each created model.
  void addModelsFromJson(Map<String, dynamic> data) {
    for (var collection in data["collections"][rid] as Iterable) {
      var rid = collection["rid"] as String;
      var model = (data["models"][rid]) as Map<String, dynamic>;
      var instance = createModelFromJson(rid, model);
      models.add(instance);
    }
  }

  /// Create an instance of a model and listen for its change events.
  T createModelFromJson(String rid, Map<String, dynamic> json) {
    var model = modelFactory();
    model.client = client;
    model.rid = rid;
    model.updateFromJson(json);
    model.listen();
    return model;
  }

  /// Unsubscribe from this collection and close the event streams
  /// Also closes the event stream of each model within this collection.
  Future<void> destroy() {
    var future = client.send("unsubscribe", rid, null);

    addEventsController.close();
    removeEventsController.close();

    addListener.cancel();
    removeListener.cancel();

    for (var model in models) {
      model.destroy();
    }

    models.clear();

    return future;
  }
}
