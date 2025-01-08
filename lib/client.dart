import 'dart:async';
import 'dart:convert';

import 'package:resgate_client/collection.dart';
import 'package:resgate_client/exceptions.dart';
import 'package:resgate_client/model.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class ResClient {
  late WebSocketChannel channel;

  /// We need a broadcast stream here as we want a temporary listener per
  /// message sent. As we can send message in an async manner we might have more
  /// than one listener at a time.
  late Stream stream;

  /// The ID of the message and the response are the same, that's how we can
  /// figure out which response corresponds to which sent message.
  int currentId = 1;

  /// Connect to the given Resgate server.
  connect(String url) {
    channel = WebSocketChannel.connect(Uri.parse(url));
    stream = channel.stream.asBroadcastStream();
  }

  /// Subscribe to a collection.
  /// The collection will automatically listen for changes to the collection (add and remove).
  /// Additionally, the collection will listen for changes to each model in the collection.
  Future<ResCollection<T>> getCollection<T extends ResModel>(
      String rid, T Function() modelFactory) async {
    var id = await send("subscribe", rid, null);
    var json = await receive(id);
    return ResCollection(
      client: this,
      rid: rid,
      data: json["result"],
      modelFactory: modelFactory,
    );
  }

  /// Send the credentials so it can be stored on this connection.
  Future<Map> authenticate(String rid, Map params) async {
    var id = await send("auth", rid, params);
    return await receive(id);
  }

  /// Requests the RES protocol version of the Resgate server.
  Future<Map> version() async {
    var id = await send("version", null, {"protocol": "1.2.1"});
    return await receive(id);
  }

  /// Publish a Resgate message on the websocket channel.
  Future<int> send(String type, String? rid, Map? params) async {
    var id = currentId++;

    Map msg = {
      "id": id,
    };

    if (rid != null) {
      msg["method"] = "$type.$rid";
    } else {
      msg["method"] = type;
    }

    if (params != null) {
      msg["params"] = params;
    }

    await channel.ready;

    channel.sink.add(jsonEncode(msg));

    return id;
  }

  /// Wait for a response that has the given id, which matches with the sent message.
  Future<Map> receive(int id) {
    var completer = Completer<Map>();

    // Create a one-shot subscription to the stream to receive the response.
    late StreamSubscription sub;

    sub = stream.listen((msg) {
      Map json = jsonDecode(msg);

      if (json["id"] == id) {
        // Cancel the subscription as we only want to receive this one specific message.
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
    return stream.listen((msg) {
      Map json = jsonDecode(msg);

      if (filter != null) {
        if (filter(json)) {
          handler(json);
        }
      } else {
        handler(json);
      }
    });
  }

  /// Close the websocket connection.
  void destroy() {
    channel.sink.close(status.goingAway);
  }
}
