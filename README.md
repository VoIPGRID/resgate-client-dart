# Resgate client for Dart

## Features

- authentication
- subscribe to a collection
  - models within the collection are indirectly subscribed so they will also receive updates
- react on collection add/remove events
- react on model change events

## Example

- see the [bin file](bin/resgate_client.dart) for now
- run with `dart run` from the root project folder

## Todo

- timeout for sent messages, otherwise one might wait forever for a response that may never come
- reconnect
  - re-authenticate on reconnect
- stay-alive messages (otherwise the mobile phone might kill the websocket after an amount of time?)
- proper typing (a lot of stuff is `dynamic`)
- caching (prevent double subscriptions)
- tests
