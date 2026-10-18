import 'package:av_pointage/core/utils/live_counter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  var monotonic = Duration.zero;

  setUp(() {
    monotonic = const Duration(hours: 1);
    LiveClock.debugSource = () => monotonic;
  });
  tearDown(() => LiveClock.debugSource = null);

  test('should_advance_one_second_per_second_when_running', () {
    final counter = LiveCounter(
      const Duration(hours: 5),
      running: true,
      anchor: LiveAnchor.now(),
    );

    expect(counter.value, const Duration(hours: 5));
    monotonic += const Duration(seconds: 1, milliseconds: 600);
    expect(counter.value, const Duration(hours: 5, seconds: 1));
    monotonic += const Duration(minutes: 10);
    expect(counter.value, const Duration(hours: 5, minutes: 10, seconds: 1));
  });

  test('should_stay_frozen_when_not_running', () {
    final counter = LiveCounter(
      const Duration(minutes: 42),
      anchor: LiveAnchor.now(),
    );

    monotonic += const Duration(hours: 2);

    expect(counter.value, const Duration(minutes: 42));
  });

  test('should_ignore_elapsed_time_when_anchor_frozen', () {
    const counter = LiveCounter(Duration(minutes: 3), running: true);

    monotonic += const Duration(hours: 2);

    expect(counter.value, const Duration(minutes: 3));
  });

  test('should_never_go_backwards_when_monotonic_source_is_reset', () {
    final counter = LiveCounter(
      const Duration(minutes: 3),
      running: true,
      anchor: LiveAnchor.now(),
    );

    monotonic = Duration.zero;

    expect(counter.value, const Duration(minutes: 3));
  });

  test('should_run_ticker_only_while_listened', () {
    final ticker = LiveTicker.instance;
    void listener() {}

    expect(ticker.isRunning, isFalse);
    ticker.addListener(listener);
    expect(ticker.isRunning, isTrue);
    ticker.removeListener(listener);
    expect(ticker.isRunning, isFalse);
  });
}
