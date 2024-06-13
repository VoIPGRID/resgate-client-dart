import 'package:resgate_client/client.dart';
import 'package:resgate_client/model.dart';

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
    model.listen();
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
      model.stop();
    }
  }
}
