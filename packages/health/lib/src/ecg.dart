part of health;

/// A [HealthDataPoint] object corresponds to a data point captures from GoogleFit or Apple HealthKit
class ECG extends Equatable {
  final double average;
  final double samplingFrequency;
  final int classification;
  final DateTime dateFrom;
  final DateTime dateTo;
  final List<String> symptoms;

  ECG(this.average, this.samplingFrequency, this.classification, this.dateFrom,
      this.dateTo, this.symptoms);

  get props => [average, classification, dateFrom, dateTo];

  static ECG fromMap(Map map) => ECG(
      map['average'],
      map['samplingFrequency'],
      map['classification'],
      DateTime.fromMillisecondsSinceEpoch(map['date_from']),
      DateTime.fromMillisecondsSinceEpoch(map['date_to']),
      map['symptoms'] == '' ? [] : (map['symptoms'] as String).split(','));
}
