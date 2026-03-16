## 1.0.5

- Fix silent connection drops: unanswered pings now trigger reconnection.
- Client automatically re-authenticates after reconnecting.
- Client automatically re-subscribes all active collections after reconnecting, updating existing model objects in-place.

## 1.0.4

- Add keepalive pinging to prevent idle connections from being silently dropped.
- Add exponential backoff reconnection strategy.

## 1.0.3

- Bump version following auto-version merge.

## 1.0.2

- Automatically send the RES protocol version to Resgate before authenticating.

## 1.0.1

- Fix `Invalid argument: 1001` error when closing the WebSocket connection.
- Require Dart SDK `^3.5.0`.

## 1.0.0

- Initial version.
