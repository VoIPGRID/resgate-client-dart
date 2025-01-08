import 'dart:convert';

import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:resgate_client/client.dart';
import 'package:resgate_client/model.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

@GenerateNiceMocks([MockSpec<WebSocketChannel>(), MockSpec<WebSocketSink>()])
import 'client_test.mocks.dart';

class TestModel extends ResModel {
  @override
  void updateFromJson(Map json) {}
}

void main() {
  late WebSocketChannel mockChannel;
  late WebSocketSink mockSink;
  late ResClient client;

  setUp(() {
    mockChannel = MockWebSocketChannel();
    mockSink = MockWebSocketSink();

    when(mockChannel.sink).thenReturn(mockSink);

    client = ResClient();
    client.channel =
        mockChannel; // Now it's not needed to call client.connect() in the tests.
  });
}
