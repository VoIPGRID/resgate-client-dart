import 'dart:async';
import 'dart:convert';

import 'package:resgate_client/collection.dart';
import 'package:resgate_client/exceptions.dart';
import 'package:resgate_client/model.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ResClient {
  late WebSocketChannel _channel;

  /// We need a broadcast here as we want a temporary listener per message
  /// sent. As we can send message in an async manner we might have more
  /// than one listener at a time.
  late Stream _stream;

  /// The ID of the message and the response are the same, that's how we
  /// can figure out which response corresponds to which sent message.
  int _currentId = 1;

  ResClient(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _stream = _channel.stream.asBroadcastStream();
  }

  /// Wait for a response that has the given id.
  Future<Map> _getResponse(int id) {
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
    Function(Map)? filter,
  }) {
    return _stream.listen((message) {
      final Map json = jsonDecode(message);

      if (filter != null && filter(json)) {
        handler(json);
      } else {
        handler(json);
      }
    });
  }

  /// Subscribe to a collection.
  Future<ResCollection<T>> getCollection<T extends ResModel>(
      String rid, T Function(Map) modelFromJson) async {
    final id = await _sendMessage("subscribe", rid, null);
    final json = await _getResponse(id);
    return ResCollection(
      client: this,
      rid: rid,
      data: json["result"],
      modelFromJson: modelFromJson,
    );
  }

  /// Send the credentials so it can be stored on this connection.
  Future<Map> authenticate(String rid, Map params) async {
    final id = await _sendMessage("auth", rid, params);
    return await _getResponse(id);
  }

  /// Requests the RES protocol version of the Resgate server.
  Future<Map> version() async {
    final id = await _sendMessage("version", null, {"protocol": "1.2.1"});
    return await _getResponse(id);
  }

  /// Publish a Resgate message on the websocket stream.
  Future<int> _sendMessage(String type, String? rid, Map? params) async {
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

    // Wait for the websocket to be fully connected to able to send messages.
    await _channel.ready;

    _channel.sink.add(jsonEncode(message));

    return id;
  }
}
