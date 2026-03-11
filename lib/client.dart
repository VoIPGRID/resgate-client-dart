import 'dart:async';
import 'dart:convert';

import 'collection.dart';
import 'exceptions.dart';
import 'model.dart';
import 'reconnection_strategy.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

class ResClient {
  ResClient({ReconnectionStrategy? reconnectionStrategy})
      : _reconnectionStrategy =
            reconnectionStrategy ?? ReconnectionStrategy.defaultStrategy;

  final ReconnectionStrategy _reconnectionStrategy;

  late WebSocketChannel channel;

  /// A [StreamController] provides a stable stream reference that survives
  /// reconnections. Unlike [Stream.asBroadcastStream], this won't cancel the
  /// underlying WebSocket subscription when temporary listeners (e.g.
  /// [receive]) come and go.
  final _streamController = StreamController<dynamic>.broadcast();

  /// Stable broadcast stream of all incoming WebSocket messages.
  /// This reference remains valid across reconnections.
  late Stream<dynamic> stream = _streamController.stream;

  /// The ID of the message and the response are the same, that's how we can
  /// figure out which response corresponds to which sent message.
  int currentId = 1;

  Timer? _pingTimer;
  Timer? _reconnectTimer;
  StreamSubscription<dynamic>? _channelSubscription;

  String? _connectUrl;
  Duration _pingInterval = const Duration(seconds: 30);
  bool _doNotReconnect = false;

  /// Called after a successful reconnection so the consumer can
  /// re-authenticate and re-subscribe to collections.
  Future<void> Function()? onReconnect;

  /// Connect to the given Resgate server.
  ///
  /// [pingInterval] controls how often a keepalive ping is sent to prevent
  /// the connection from being silently dropped by intermediaries.
  void connect(
    String url, {
    Duration pingInterval = const Duration(seconds: 30),
  }) {
    _connectUrl = url;
    _pingInterval = pingInterval;
    _doNotReconnect = false;
    _initializeChannel();
  }

  void _initializeChannel({bool isReconnect = false}) {
    _pingTimer?.cancel();
    _channelSubscription?.cancel();

    channel = WebSocketChannel.connect(Uri.parse(_connectUrl!));

    _channelSubscription = channel.stream.listen(
      (msg) {
        // Any message successfully received is a healthy event — cancel any
        // queued reconnect and reset the backoff strategy.
        _cancelQueuedReconnect(resetAttempts: true);
        _streamController.add(msg);
      },
      onError: (_) => _attemptReconnect(),
      onDone: () => _attemptReconnect(),
      cancelOnError: false,
    );

    _pingTimer = Timer.periodic(_pingInterval, (_) => _ping());

    if (isReconnect) onReconnect?.call();
  }

  void _attemptReconnect() {
    if (_doNotReconnect || _reconnectTimer != null) return;

    final reconnectWaitTime = _reconnectionStrategy.delayFor();
    _reconnectionStrategy.increment();

    _reconnectTimer = Timer(reconnectWaitTime, () {
      _cancelQueuedReconnect();
      _initializeChannel(isReconnect: true);
    });
  }

  void _cancelQueuedReconnect({bool resetAttempts = false}) {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    if (resetAttempts) _reconnectionStrategy.reset();
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

  Future<void> _ping() async {
    try {
      await _version();
    } catch (_) {}
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
    _doNotReconnect = true;
    _cancelQueuedReconnect();
    _pingTimer?.cancel();
    _pingTimer = null;
    await channel.sink.close(status.normalClosure);
    await _channelSubscription?.cancel();
    _channelSubscription = null;
    await _streamController.close();
  }
}
