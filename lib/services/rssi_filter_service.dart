class RssiFilterService {
  final int maxSamples;

  final Map<String, List<int>> _samples = {};

  RssiFilterService({
    this.maxSamples = 5,
  });

  double addSample(String beaconId, int rssi) {
    final samples = _samples.putIfAbsent(
      beaconId,
      () => [],
    );

    samples.add(rssi);

    if (samples.length > maxSamples) {
      samples.removeAt(0);
    }

    final sum = samples.reduce(
      (value, element) => value + element,
    );

    return sum / samples.length;
  }

  List<int> getSamples(String beaconId) {
    return List.unmodifiable(
      _samples[beaconId] ?? [],
    );
  }

  void clear(String beaconId) {
    _samples.remove(beaconId);
  }

  void clearAll() {
    _samples.clear();
  }
}