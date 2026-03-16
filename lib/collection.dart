import 'dart:async';

import 'client.dart';
import 'model.dart';

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

  /// Re-subscribe to this collection after a reconnect, updating existing
  /// model objects in-place so that external references remain valid.
  Future<void> resubscribe() async {
    final id = await client.send("subscribe", rid, null);
    final json = await client.receive(id);
    _refreshModelsFromJson(json["result"] as Map<String, dynamic>);
  }

  void _refreshModelsFromJson(Map<String, dynamic> data) {
    final freshData = <String, Map<String, dynamic>>{};
    for (final item in data["collections"][rid] as Iterable) {
      final modelRid = item["rid"] as String;
      freshData[modelRid] = data["models"][modelRid] as Map<String, dynamic>;
    }
    for (final model in models) {
      final fresh = freshData[model.rid];
      if (fresh != null) model.updateFromJson(fresh);
    }
  }

  /// Unsubscribe from this collection and close the event streams
  /// Also closes the event stream of each model within this collection.
  Future<void> destroy() async {
    client.removeCollection(this);
    await client.send("unsubscribe", rid, null);

    await addEventsController.close();
    await removeEventsController.close();

    await addListener.cancel();
    await removeListener.cancel();

    for (var model in models) {
      await model.destroy();
    }

    models.clear();
  }
}
