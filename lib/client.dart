import 'dart:async';
import 'dart:convert';

import 'package:resgate_client/collection.dart';
import 'package:resgate_client/exceptions.dart';
import 'package:resgate_client/model.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ResClient {
  late final WebSocketChannel _channel;

  /// We need a broadcast stream here as we want a temporary listener per
  /// message sent. As we can send message in an async manner we might have more
  /// than one listener at a time.
  late final Stream _stream;

  /// The ID of the message and the response are the same, that's how we can
  /// figure out which response corresponds to which sent message.
  int _currentId = 1;

  ResClient(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _stream = _channel.stream.asBroadcastStream();
  }

  /// Subscribe to a collection.
  Future<ResCollection<T>> getCollection<T extends ResModel>(
      String rid, T Function() modelFactory) async {
    final id = await send("subscribe", rid, null);
    final json = await receive(id);
    return ResCollection(
      client: this,
      rid: rid,
      data: json["result"],
      modelFactory: modelFactory,
    );
  }

  /// Send the credentials so it can be stored on this connection.
  Future<Map> authenticate(String rid, Map params) async {
    final id = await send("auth", rid, params);
    return await receive(id);
  }

  /// Requests the RES protocol version of the Resgate server.
  Future<Map> version() async {
    final id = await send("version", null, {"protocol": "1.2.1"});
    return await receive(id);
  }

  /// Publish a Resgate message on the websocket stream.
  Future<int> send(String type, String? rid, Map? params) async {
    final id = _currentId++;

    final Map message = {
      "id": id,
    };

    if (rid != null) {
      message["method"] = "$type.$rid";
    } else {
      message["method"] = type;
    }

    if (params != null) {
      message["params"] = params;
    }

    await _channel.ready;

    _channel.sink.add(jsonEncode(message));

    return id;
  }

  /// Wait for a response that has the given id.
  Future<Map> receive(int id) {
    final completer = Completer<Map>();

    late StreamSubscription sub;

    sub = _stream.listen((message) {
      final Map json = jsonDecode(message);

      if (json["id"] == id) {
        sub.cancel();

        if (json.containsKey("error")) {
          completer.completeError(ResException(json));
        } else {
          completer.complete(json);
        }
      }
    });

    return completer.future;
  }

  /// Listen in on the stream, executing the handler for each message.
  /// Optionally filtering the messages that the handler is executed on.
  StreamSubscription listen(
    Function(Map) handler, {
    bool Function(Map)? filter,
  }) {
    return _stream.listen((message) {
      final Map json = jsonDecode(message);

      if (filter != null) {
        if (filter(json)) {
          handler(json);
        }
      } else {
        handler(json);
      }
    });
  }
}
