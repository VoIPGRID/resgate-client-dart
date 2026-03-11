import 'dart:math';

/// Configuration for the reconnection backoff algorithm.
class RetryPattern {
  const RetryPattern({
    required this.initialDelay,

    /// The amount to back off, every time a new retry is made, the next delay
    /// will be incremented by this amount as a percentage of the previous
    /// retry delay.
    ///
    /// So the first retry will be [initialDelay], the second retry will be
    /// first retry * [backOff], the third retry will be second retry *
    /// [backOff].
    this.backOff = 1.25,

    /// The maximum amount of times before we no longer back off any further
    /// and just continue using the last value for future retries.
    this.maxBackOff = 10,

    /// Applies "jitter" which is a random value that is added to each delay
    /// that can be used to off-set requests between multiple clients.
    this.jitter = false,

    /// The maximum bounds of this jitter, so setting it to a value of [30]
    /// will increment the delay anywhere between 0 and 30%.
    ///
    /// If [jitter] is false, this has no effect.
    this.jitterMaxPercent = 30,
  });

  final Duration initialDelay;
  final double backOff;
  final int maxBackOff;
  final bool jitter;
  final int jitterMaxPercent;
}

/// Calculates reconnection delays using exponential backoff with optional
/// jitter.
///
/// Call [delayFor] to get the delay for the current attempt, then [increment]
/// to advance to the next attempt. Call [reset] when a connection is
/// successfully established.
class ReconnectionStrategy {
  ReconnectionStrategy(this.params) {
    _createSchedule();
  }

  static ReconnectionStrategy get defaultStrategy => ReconnectionStrategy(
        const RetryPattern(
          initialDelay: Duration(seconds: 10),
          jitter: true,
        ),
      );

  int attempts = 0;
  late final List<Duration> schedule;

  final RetryPattern params;

  void increment({int amount = 1}) => attempts += amount;

  void reset() => attempts = 0;

  Duration delayFor() =>
      attempts < schedule.length ? schedule[attempts] : schedule.last;

  void _createSchedule() {
    schedule = List.generate(params.maxBackOff, (attempt) {
      final initial = params.initialDelay;
      var seconds = initial.inSeconds.toDouble();

      for (var i = 1; i <= attempt; i++) {
        seconds = seconds * params.backOff;
      }

      if (params.jitter) {
        final jitterPercentage =
            Random().nextInt(params.jitterMaxPercent) + 100;
        seconds = seconds * (jitterPercentage / 100);
      }

      return Duration(milliseconds: (seconds * 1000).toInt());
    });
  }
}
