import 'dart:async';
import 'dart:convert';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:resgate_client/client.dart';
import 'package:resgate_client/model.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'utils.dart';

@GenerateNiceMocks([
  MockSpec<WebSocketChannel>(),
  MockSpec<WebSocketSink>(),
  MockSpec<Stream>(),
  MockSpec<StreamController>(),
  MockSpec<StreamSubscription>(),
])
import 'model_test.mocks.dart';

class TestModel extends ResModel {
  int counter = 0;

  @override
  void updateFromJson(Map json) {
    if (json.containsKey("counter")) {
      counter = json["counter"];
    }
  }
}

void main() {
  late WebSocketChannel mockChannel;
  late WebSocketSink mockSink;
  late Stream mockStream;
  late StreamController<Map<String, dynamic>> mockChangeEventsController;
  late StreamSubscription mockChangeListener;
  late ResClient client;
  late TestModel model;

  setUp(() {
    mockChannel = MockWebSocketChannel();
    mockSink = MockWebSocketSink();
    mockStream = MockStream();
    mockChangeEventsController = MockStreamController();
    mockChangeListener = MockStreamSubscription();

    when(mockChannel.sink).thenReturn(mockSink);

    client = ResClient();
    client.channel = mockChannel;
    client.stream = mockStream;

    model = TestModel();
    model.client = client;
    model.rid = "example.model.1";
    model.changeEventsController = mockChangeEventsController;
    model.changeListener = mockChangeListener;
  });

  test('ResModel.listen() updates its values and broadcasts an event',
      () async {
    Map<String, dynamic> expectedUpdatedValues = {
      "counter": 9000,
    };

    Map<String, dynamic> changeEventMessage = {
      "id": 1,
      "event": "example.model.1.change",
      "data": {"values": expectedUpdatedValues}
    };

    mockListenToStream(mockStream, () async* {
      yield jsonEncode(changeEventMessage);
    });

    model.listen();
    await model.changeListener.asFuture();

    verify(mockChangeEventsController.add(expectedUpdatedValues)).called(1);

    expect(model.counter, equals(9000));
  });

  test('ResModel.destroy() closes streams and removes listeners', () async {
    await model.destroy();

    verify(mockChangeEventsController.close()).called(1);
    verify(mockChangeListener.cancel()).called(1);
  });
}
