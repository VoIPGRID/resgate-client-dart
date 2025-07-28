import 'dart:async';
import 'dart:convert';

import 'collection.dart';
import 'exceptions.dart';
import 'model.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class ResClient {
  late WebSocketChannel channel;

  /// We need a broadcast stream here as we want a temporary listener per
  /// message sent. As we can send message in an async manner we might have more
  /// than one listener at a time.
  late Stream<dynamic> stream;

  /// The ID of the message and the response are the same, that's how we can
  /// figure out which response corresponds to which sent message.
  int currentId = 1;

  /// Connect to the given Resgate server.
  void connect(String url) {
    channel = WebSocketChannel.connect(Uri.parse(url));
    stream = channel.stream.asBroadcastStream();
  }

  /// Subscribe to a collection.
  /// The collection will automatically listen for changes to the collection (add and remove).
  /// Additionally, the collection will listen for changes to each model in the collection.
  Future<ResCollection<T>> getCollection<T extends ResModel>(
    String rid,
    T Function() modelFactory,
  ) async {
    var id = await send("subscribe", rid, null);
    var json = await receive(id);
    var collection = ResCollection(
      client: this,
      rid: rid,
      modelFactory: modelFactory,
    );
    collection.addModelsFromJson(json["result"] as Map<String, dynamic>);
    collection.listen();
    return collection;
  }

  /// Send the credentials so it can be stored on this connection.
  Future<Map<String, dynamic>> authenticate(
    String rid,
    Map<String, dynamic> params,
  ) async {
    var id = await send("auth", rid, params);
    final response = await receive(id);
    await _version();
    return response;
  }

  /// Requests the RES protocol version of the Resgate server.
  Future<Map<String, dynamic>> _version() async {
    var id = await send("version", null, {"protocol": "1.2.1"});
    return await receive(id);
  }

  /// Publish a Resgate message on the websocket channel.
  Future<int> send(
    String type,
    String? rid,
    Map<String, dynamic>? params,
  ) async {
    var id = currentId++;

    Map<String, dynamic> msg = {
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
  Future<Map<String, dynamic>> receive(int id) {
    var completer = Completer<Map<String, dynamic>>();

    // Create a one-shot subscription to the stream to receive the response.
    late StreamSubscription<dynamic> sub;

    sub = stream.listen((msg) {
      Map<String, dynamic> json =
          jsonDecode(msg as String) as Map<String, dynamic>;

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
  StreamSubscription<dynamic> listen(
    void Function(Map<String, dynamic>) handler, {
    bool Function(Map<String, dynamic>)? filter,
  }) {
    return stream.listen((msg) {
      Map<String, dynamic> json =
          jsonDecode(msg as String) as Map<String, dynamic>;

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
  Future<void> destroy() async {
    await channel.sink.close(status.normalClosure);
  }
}
