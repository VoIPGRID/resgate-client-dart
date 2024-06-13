import 'dart:async';
import 'dart:convert';

import 'package:resgate_client/data.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ResClient {
  /// The ID of the message and the response are the same, that's how we
  /// can figure out which response corresponds to which sent message.
  int _currentId = 1;

  late WebSocketChannel _channel;

  /// We need a broadcast stream to able to add multiple listeners,
  /// one per message sent.
  late Stream _stream;

  ResClient(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _stream = _channel.stream.asBroadcastStream();
  }

  /// Send a message through the websocket and return the response as JSON.
  Future<Map> _send(Map json) async {
    final completer = Completer<Map>();
    final id = _currentId++;

    late StreamSubscription sub;

    // Before sending the message, set up a listener that completes this
    // function when a response has been received with the same ID.
    // TODO timeout, expect a response within a few seconds.
    sub = _stream.listen((message) {
      final Map json = jsonDecode(message);

      // We're only interested in the response of the message we are sending.
      if (json["id"] != id) return;

      // We have the response that belongs to this message, unsubscribe from
      // the event stream.
      sub.cancel();

      // Oh noes we got an error.
      if (json.containsKey('error')) {
        final code = json["error"]["code"];
        final message = json["error"]["message"];

        completer.completeError(ResError(code, message));
        return;
      }

      completer.complete(json);
    });

    // Make sure the connection has been established before sending the message.
    await _channel.ready;

    // Add the ID to the object before sending it, we need this to idenfity
    // the response that corresponds with this message.
    json["id"] = id;

    _channel.sink.add(jsonEncode(json));

    return completer.future;
  }

  /// Subscribe to a collection.
  Future<ResResult<CollectionResult<T>>> getCollection<T>(
      String subject, T Function(Map) modelFromJson) async {
    final json = await _send({
      "method": "subscribe.$subject",
    });

    return ResResult.fromJson(json, (json) {
      return CollectionResult.fromJson(json, modelFromJson);
    });
  }

  /// Send the authentication so it can be stored on this connection.
  Future<ResResult<AuthenticateResult>> authenticate(
      String subject, Map params) async {
    final json = await _send({
      "method": "auth.$subject",
      "params": params,
    });

    return ResResult.fromJson(json, (json) {
      return AuthenticateResult.fromJson(json);
    });
  }

  /// Requests the RES protocol version of the Resgate server.
  Future<ResResult<VersionResult>> version() async {
    final json = await _send({
      "method": "version",
      "params": {"protocol": "1.2.1"}
    });

    return ResResult.fromJson(json, (json) {
      return VersionResult.fromJson(json);
    });
  }
}
