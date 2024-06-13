class ResException implements Exception {
  Map data;

  ResException(this.data);

  get id {
    return data["id"];
  }

  get message {
    return data["error"]["message"];
  }

  get code {
    return data["error"]["code"];
  }

  @override
  String toString() {
    return "Resgate error for message with id: $id -> $message ($code)";
  }
}
