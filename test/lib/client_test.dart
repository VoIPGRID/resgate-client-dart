import 'dart:async';
import 'dart:convert';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:resgate_client/client.dart';
import 'package:resgate_client/exceptions.dart';
import 'package:resgate_client/model.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'utils.dart';

@GenerateNiceMocks([
  MockSpec<WebSocketChannel>(),
  MockSpec<WebSocketSink>(),
  MockSpec<Stream>(),
  MockSpec<ResModel>()
])
import 'client_test.mocks.dart';

void main() {
  late WebSocketChannel mockChannel;
  late WebSocketSink mockSink;
  late Stream mockStream;
  late ResClient client;

  setUp(() {
    mockChannel = MockWebSocketChannel();
    mockSink = MockWebSocketSink();
    mockStream = MockStream();

    when(mockChannel.sink).thenReturn(mockSink);

    client = ResClient();
    client.channel = mockChannel;
    client.stream = mockStream;
  });

  test('ResClient.currentId is bumped for each message sent', () async {
    expect(client.currentId, equals(1));
    var firstMessageId = await client.send("method", "rid", null);
    expect(firstMessageId, equals(1));

    expect(client.currentId, equals(2));
    var secondMessageId = await client.send("method", "rid", null);
    expect(secondMessageId, equals(2));
  });

  test(
      'ResClient.send() sends the message over the websocket as json encoded data',
      () async {
    Map expectedMessage = {
      "id": 1,
      "method": "method.rid",
    };

    await client.send("method", "rid", null);

    verify(mockChannel.ready).called(1);
    verify(mockSink.add(jsonEncode(expectedMessage))).called(1);
  });

  test(
      'ResClient.send() sends the message over the websocket as json encoded data (with optional params)',
      () async {
    Map expectedMessage = {
      "id": 1,
      "method": "method.rid",
      "params": {"key": "value"},
    };

    await client.send("method", "rid", {"key": "value"});

    verify(mockChannel.ready).called(1);
    verify(mockSink.add(jsonEncode(expectedMessage))).called(1);
  });

  test(
      'ResClient.getCollection() parses the Resgate message into a ResCollection',
      () async {
    Map message = {
      "id": 1,
      "rid": "example.collection.1",
      "result": {
        "collections": {
          "example.collection.1": [
            {"rid": "example.model.1"}
          ]
        },
        "models": {"example.model.1": {}}
      }
    };

    mockListenToStream(mockStream, () async* {
      yield jsonEncode(message);
    });

    modelFactory() => MockResModel();

    var collection =
        await client.getCollection("example.collection.1", modelFactory);

    expect(collection.client, equals(client));
    expect(collection.rid, equals("example.collection.1"));
    expect(collection.modelFactory, equals(modelFactory));
    expect(collection.models.length, equals(1));
  });

  test(
      'ResClient.receive() resolves when the message with the given id is received',
      () async {
    Map firstMessage = {
      "id": 1,
    };

    Map expectedSecondMessage = {
      "id": 2,
      "result": {
        "data": {
          "rid": "example.collection.1",
          "models": {
            "example.model.1": {"key": "value"}
          }
        }
      },
    };

    Map thirdMessage = {
      "id": 3,
    };

    mockListenToStream(mockStream, () async* {
      yield jsonEncode(firstMessage);
      yield jsonEncode(expectedSecondMessage);
      yield jsonEncode(thirdMessage);
    });

    var future = client.receive(2).then((message) {
      expect(message, equals(expectedSecondMessage));
    });

    expect(future, completes);
  });

  test(
      'ResClient.receive() throws an exception for an error message is received from the Resgate server',
      () async {
    Map errorMessage = {
      "id": 1,
      "error": {
        "message": "error message",
        "code": 404,
      }
    };

    mockListenToStream(mockStream, () async* {
      yield jsonEncode(errorMessage);
    });

    var future = client.receive(1).catchError((error) {
      expect(error, isA<ResException>());
      expect(
          error.toString(),
          equals(
              "Resgate error for websocket message with id: 1 -> error message (404)"));
      return {};
    });

    expect(future, completes);
  });

  test(
      'ResClient.listen() executes the handler for each message that matches the filter',
      () async {
    Map addEventMessage = {
      "id": 1,
      "event": "add",
    };

    Map changeEventMessage = {
      "id": 2,
      "event": "change",
    };

    Map removeEventMessage = {
      "id": 3,
      "event": "remove",
    };

    mockListenToStream(mockStream, () async* {
      yield jsonEncode(addEventMessage);
      yield jsonEncode(changeEventMessage);
      yield jsonEncode(removeEventMessage);
    });

    var sub = client.listen((msg) {
      expect(msg, isNot(equals(addEventMessage)));
      expect(msg, isNot(equals(removeEventMessage)));
      expect(msg, equals(changeEventMessage));
    }, filter: (msg) => msg["event"] == "change");

    expect(sub.asFuture(), completes);
  });

  test('ResClient.destroy() stops the websocket connection', () {
    client.destroy();
    verify(mockSink.close(status.goingAway)).called(1);
  });
}
