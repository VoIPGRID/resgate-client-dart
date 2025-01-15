import 'dart:async';
import 'dart:convert';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:resgate_client/client.dart';
import 'package:resgate_client/collection.dart';
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
  MockSpec<ResModel>(),
])
import 'collection_test.mocks.dart';

void main() {
  late WebSocketChannel mockChannel;
  late WebSocketSink mockSink;
  late Stream mockStream;
  late StreamController<MockResModel> mockAddEventsController;
  late StreamController<MockResModel> mockRemoveEventsController;
  late ResClient client;

  setUp(() {
    mockChannel = MockWebSocketChannel();
    mockSink = MockWebSocketSink();
    mockStream = MockStream();
    mockAddEventsController = MockStreamController();
    mockRemoveEventsController = MockStreamController();

    when(mockChannel.sink).thenReturn(mockSink);

    client = ResClient();
    client.channel = mockChannel;
    client.stream = mockStream;
  });

  test(
      'ResCollection listens to add events and adds the corresponding model to its list and broadcasts an event for it',
      () async {
    Map addEventMessage = {
      "id": 2,
      "event": "example.collection.1.add",
      "data": {
        "idx": 1,
        "value": {"rid": "example.model.2"},
        "models": {"example.model.2": {}}
      }
    };

    mockListenToStream(mockStream, () async* {
      yield jsonEncode(addEventMessage);
    });

    modelFactory() => MockResModel();

    var collection = ResCollection(
      client: client,
      rid: "example.collection.1",
      modelFactory: modelFactory,
    );

    collection.addEventsController = mockAddEventsController;
    collection.addModelsFromJson({
      "collections": {
        "example.collection.1": [
          {"rid": "example.model.1"}
        ]
      },
      "models": {"example.model.1": {}}
    });

    collection.listen();
    await collection.addListener.asFuture();

    verify(mockAddEventsController.add(collection.models[1])).called(1);

    expect(collection.client, equals(client));
    expect(collection.rid, equals("example.collection.1"));
    expect(collection.modelFactory, equals(modelFactory));
    expect(collection.models.length, equals(2));
  });

  test(
      'ResCollection listens to remove events and removes the corresponding model from its list and broadcasts an event for it',
      () async {
    Map removeEventMessage = {
      "id": 2,
      "event": "example.collection.1.remove",
      "data": {"idx": 0}
    };

    mockListenToStream(mockStream, () async* {
      yield jsonEncode(removeEventMessage);
    });

    modelFactory() => MockResModel();

    var collection = ResCollection(
      client: client,
      rid: "example.collection.1",
      modelFactory: modelFactory,
    );

    collection.removeEventsController = mockRemoveEventsController;
    collection.addModelsFromJson({
      "collections": {
        "example.collection.1": [
          {"rid": "example.model.1"}
        ]
      },
      "models": {"example.model.1": {}}
    });

    var model = collection.models[0];

    collection.listen();
    await collection.removeListener.asFuture();

    verify(mockRemoveEventsController.add(model)).called(1);

    expect(collection.client, equals(client));
    expect(collection.rid, equals("example.collection.1"));
    expect(collection.modelFactory, equals(modelFactory));
    expect(collection.models.length, equals(0));
  });

  test(
      'ResCollection.destroy() closes streams and removes event listeners of itself and its models',
      () async {
    modelFactory() => MockResModel();

    var mockAddEventsController = MockStreamController<MockResModel>();
    var mockRemoveEventsController = MockStreamController<MockResModel>();

    var mockAddListener = MockStreamSubscription();
    var mockRemoveListener = MockStreamSubscription();

    var collection = ResCollection(
      client: client,
      rid: "example.collection.1",
      modelFactory: modelFactory,
    );

    collection.addEventsController = mockAddEventsController;
    collection.removeEventsController = mockRemoveEventsController;
    collection.addListener = mockAddListener;
    collection.removeListener = mockRemoveListener;

    collection.models.add(modelFactory());

    await collection.destroy();

    for (var model in collection.models) {
      verify(model.destroy()).called(1);
    }

    expect(collection.models.length, equals(0));

    verify(mockAddEventsController.close()).called(1);
    verify(mockRemoveEventsController.close()).called(1);

    verify(mockAddListener.cancel()).called(1);
    verify(mockRemoveListener.cancel()).called(1);

    Map expectedMessage = {
      "id": 1,
      "method": "unsubscribe.example.collection.1",
    };

    verify(mockChannel.ready).called(1);
    verify(mockSink.add(jsonEncode(expectedMessage))).called(1);
  });
}
