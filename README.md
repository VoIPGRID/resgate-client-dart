# Resgate client for Dart

## Todo

- timeout for sent messages, otherwise one might wait forever for a response that may never come.
- reconnect
  - re-authenticate on reconnect
- stay-alive messages (otherwise the mobile phone might kill the websocket after an amount of time?)
- tests

## Example

- see the [bin file](bin/resgate_client.dart) for now
- run with `dart run` from the root project folder.
