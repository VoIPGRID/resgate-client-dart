import 'package:mockito/mockito.dart';

/// Mock the things that are returned by the given stream, source: https://stackoverflow.com/a/74988454
void mockListenToStream<T>(Stream stream, Stream Function() fn) {
  when(stream.listen(
    any,
    onError: anyNamed('onError'),
    onDone: anyNamed('onDone'),
    cancelOnError: anyNamed('cancelOnError'),
  )).thenAnswer((invocation) {
    return fn().listen(invocation.positionalArguments.single);
  });
}
