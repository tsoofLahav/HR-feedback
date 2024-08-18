import 'dart:math';

class PPGAlgorithm {
  List<double> smoothSignal(List<double> signal) {
    // Implement a simple moving average filter for smoothing
    int windowSize = 5;
    List<double> smoothedSignal = [];
    for (int i = 0; i < signal.length - windowSize + 1; i++) {
      double sum = 0;
      for (int j = 0; j < windowSize; j++) {
        sum += signal[i + j];
      }
      smoothedSignal.add(sum / windowSize);
    }
    return smoothedSignal;
  }

  List<int> detectPeaks(List<double> signal, double threshold) {
    // Implement a simple peak detection algorithm with threshold
    List<int> peaks = [];
    for (int i = 1; i < signal.length - 1; i++) {
      if (signal[i] > signal[i - 1] && signal[i] > signal[i + 1] && signal[i] > threshold) {
        peaks.add(i);
      }
    }
    return peaks;
  }

  double calculateHeartRate(List<int> peaks, double samplingRate) {
    // Calculate heart rate from peaks
    if (peaks.length < 2) return 0.0;
    List<double> intervals = [];
    for (int i = 1; i < peaks.length; i++) {
      intervals.add((peaks[i] - peaks[i - 1]) / samplingRate);
    }
    double averageInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    return 60.0 / averageInterval; // Convert to beats per minute
  }
}
