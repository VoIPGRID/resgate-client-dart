import 'package:resgate_client/client.dart';

class ResError implements Exception {
  String code;
  String message;

  ResError(this.code, this.message);

  @override
  String toString() {
    return "Resgate error: $message ($code)";
  }
}

class ResCollection<T> {
  ResClient client;
  String rid;
  Map data;
  T Function(Map) modelFromJson;

  ResCollection({
    required this.client,
    required this.rid,
    required this.data,
    required this.modelFromJson,
  });

  List<T> getModels() {
    return (data["models"] as Map)
        .values
        .map((value) => modelFromJson(value))
        .toList();
  }
}
