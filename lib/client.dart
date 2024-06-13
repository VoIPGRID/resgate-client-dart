import 'dart:async';
import 'dart:convert';

import 'package:resgate_client/data.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ResClient {
  late WebSocketChannel _channel;

  /// We need a broadcast stream to able to add multiple listeners,
  /// one per message sent.
  late Stream _stream;

  /// The ID of the message and the response are the same, that's how we
  /// can figure out which response corresponds to which sent message.
  int _currentId = 1;

  /// Store the responses we get from Resgate in memory.
  final Map<String, dynamic> _cache = {};

  /// Keep track which subscriptions are active.
  final List<String> _subscriptions = [];

  ResClient(String url) {
    _channel = WebSocketChannel.connect(Uri.parse(url));
    _stream = _channel.stream.asBroadcastStream();
  }

  /// Send a message and expect a response.
  Future<Map> send(String type, String? rid, Map? params) async {
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
        completer.completeError(ResException(json["error"]));
        return;
      }

      completer.complete(json);
    });

    await _sendMessage(type, rid, id, params);

    return completer.future;
  }

  /// Subscribe to the specified event and listen for messages.
  Future<StreamSubscription> on(
      String event, String rid, Function(Map) onMessage) async {
    final id = _currentId++;

    final sub = _stream.listen((message) {
      final Map json = jsonDecode(message);

      if (json["event"] == '$rid.$event') {
        onMessage(json);
      }
    });

    await _sendMessage("subscribe", rid, id, null);

    return sub;
  }

  /// Subscribe to a collection.
  Future<ResCollection<T>> getCollection<T extends ResModel>(
      String rid, T Function(Map) modelFromJson) async {
    if (_cache.containsKey(rid)) {
      return _cache[rid] as ResCollection<T>;
    }

    final json = await send("subscribe", rid, null);

    final collection = ResCollection(
      client: this,
      rid: rid,
      data: json["result"],
      modelFromJson: modelFromJson,
    );

    _cache[rid] = collection;

    return collection;
  }

  /// Send the authentication so it can be stored on this connection.
  Future<Map> authenticate(String rid, Map params) async {
    return await send("auth", rid, params);
  }

  /// Requests the RES protocol version of the Resgate server.
  Future<Map> version() async {
    return await send("version", null, {"protocol": "1.2.1"});
  }

  /// Publish a Resgate message on the websocket stream.
  _sendMessage(String type, String? rid, int? id, Map? params) async {
    if (type == "subscribe" && rid != null) {
      // Don't subscribe again to prevent double data in the data stream.
      if (_subscriptions.contains(rid)) {
        return;
      }

      _subscriptions.add(rid);
    }

    // Wait for the websocket to be fully connected to able to send messages.
    await _channel.ready;

    final Map message = {};

    if (rid != null) {
      message["method"] = "$type.$rid";
    } else {
      message["method"] = type;
    }

    if (params != null) {
      message["params"] = params;
    }

    if (id != null) {
      message["id"] = id;
    }

    _channel.sink.add(jsonEncode(message));
  }
}
