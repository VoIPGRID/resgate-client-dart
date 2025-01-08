# Resgate client for Dart

## Features

- authentication
- subscribe to a collection
  - models within the collection are indirectly subscribed so they will also receive updates
- react on collection add/remove events
- react on model change events

## Development

- install Dart SDK from [dart.dev](https://dart.dev/get-dart)
- install dependencies with `dart pub get`

## Running tests

- (re)generate mocks with `dart run build_runner build`
- run tests with `dart test`

## Example

- see the [bin file](bin/resgate_client.dart) for now
- install dependencies with `dart pub get`
- run with `dart run bin/resgate_client.dart` from the root project folder

## To do

- timeout for sent messages, otherwise one might wait forever for a response that may never come
- reconnect
  - re-authenticate on reconnect
- stay-alive messages (otherwise the mobile phone might kill the websocket after an amount of time?)
- proper typing (a lot of stuff is `dynamic`)
- caching (prevent double subscriptions)
- tests
