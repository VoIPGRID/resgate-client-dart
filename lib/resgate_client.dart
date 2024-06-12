import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

class ResClient {
  /// The ID of the message and the response are the same, that's how we
  /// can figure out which response corresponds to which sent message.
  int _currentId = 1;

  late WebSocketChannel _channel;

  /// We need a broadcast stream to able to add multiple listeners.
  late Stream _stream;

  ResClient(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _stream = _channel.stream.asBroadcastStream();
  }

  /// Send a message through the websocket and wait for a response.
  Future<Map> _send(Map json) async {
    final completer = Completer<Map>();
    final id = _currentId++;

    late StreamSubscription sub;

    // Before sending the message, set up a listener that completes this
    // function when a response has been received with the same ID.
    sub = _stream.listen((message) {
      final res = jsonDecode(message);

      if (res["id"] == id) {
        completer.complete(res);
        sub.cancel();
      }
    });

    // Make sure the connection has been established before sending the message.
    await _channel.ready;

    // Add the ID to the object before sending it, we need this to idenfity
    // the response that corresponds with this message.
    json["id"] = id;

    _channel.sink.add(jsonEncode(json));

    return completer.future;
  }

  /// Subscribe to a subject, returns the collection or model in the response.
  Future<Map> subscribe(String subject) async {
    return await _send({
      "method": "subscribe.$subject",
    });
  }

  /// Send the authentication so it can be stored on this connection.
  Future<Map> authenticate() async {
    return await _send({
      "method": "auth.usertoken.login",
      "params": {
        "token": "a-random-api-token",
      }
    });
  }

  /// Requests the RES protocol version of the Resgate server.
  Future<Map> version() async {
    return await _send({
      "method": "version",
      "params": {"protocol": "1.2.1"}
    });
  }
}
