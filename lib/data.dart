class ResError implements Exception {
  String code;
  String message;

  ResError(this.code, this.message);

  @override
  String toString() {
    return "Resgate error: $message ($code)";
  }
}

class ResResult<T> {
  int id;
  T result;

  ResResult({
    required this.id,
    required this.result,
  });

  factory ResResult.fromJson(Map json, T Function(Map) resultFromJson) {
    return ResResult(
      id: json["id"],
      result: resultFromJson(json["result"]),
    );
  }
}

/// Resource ID (a reference to a collection or model).
class Rid {
  String rid;

  Rid(this.rid);

  factory Rid.fromJson(Map json) {
    return Rid(json["rid"]);
  }
}

class CollectionResult<T> {
  Map<String, T> models;
  Map<String, List<Rid>> collections;

  CollectionResult({
    required this.models,
    required this.collections,
  });

  factory CollectionResult.fromJson(
      Map json, T Function(Map json) modelFromJson) {
    // Process models.
    Map<String, T> parsedModels = {};

    json['models'].forEach((key, value) {
      parsedModels[key] = modelFromJson(value);
    });

    // Process collections.
    Map<String, List<Rid>> parsedCollections = {};

    json['collections'].forEach((key, value) {
      List<Rid> rids =
          (value as List<dynamic>).map((item) => Rid.fromJson(item)).toList();
      parsedCollections[key] = rids;
    });

    return CollectionResult(
      models: parsedModels,
      collections: parsedCollections,
    );
  }
}

class AuthenticateResult {
  dynamic payload;

  AuthenticateResult(this.payload);

  factory AuthenticateResult.fromJson(Map json) {
    return AuthenticateResult(json["payload"]);
  }
}

class VersionResult {
  String protocol;

  VersionResult(this.protocol);

  factory VersionResult.fromJson(Map json) {
    return VersionResult(json["protocol"]);
  }
}
