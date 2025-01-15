class ResException implements Exception {
  Map<String, dynamic> data;

  ResException(this.data);

  dynamic get id {
    return data["id"];
  }

  dynamic get message {
    return data["error"]["message"];
  }

  dynamic get code {
    return data["error"]["code"];
  }

  @override
  String toString() {
    return "Resgate error for websocket message with id: $id -> $message ($code)";
  }
}
