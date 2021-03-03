part of health;

/// Main class for the Plugin
class ECGFactory {
  static const MethodChannel _channel = const MethodChannel('flutter_health');

  static PlatformType _platformType =
      Platform.isAndroid ? PlatformType.ANDROID : PlatformType.IOS;

  /// Check if a given data type is available on the platform
  bool _isDataTypeAvailable(HealthDataType dataType) =>
      _platformType == PlatformType.ANDROID
          ? _dataTypeKeysAndroid.contains(dataType)
          : _dataTypeKeysIOS.contains(dataType);

  /// Request access to GoogleFit/Apple HealthKit
  Future<bool> requestAuthorization(List<HealthDataType> types) async {
    /// If BMI is requested, then also ask for weight and height
    if (types.contains(HealthDataType.BODY_MASS_INDEX)) {
      types.add(HealthDataType.WEIGHT);
      types.add(HealthDataType.HEIGHT);
      types = types.toSet().toList();
    }

    List<String> keys = types.map((e) => _enumToString(e)).toList();
    final bool isAuthorized =
        await _channel.invokeMethod('requestAuthorization', {'types': keys});
    return isAuthorized;
  }

  /// Get ECG
  Future<List<ECG>> getECG(DateTime startDate, DateTime endDate) async {
    /// If not implemented on platform, throw an exception
    if (!_isDataTypeAvailable(HealthDataType.ECG)) {
      throw _HealthException(
          HealthDataType.ECG, "Not available on platform $_platformType");
    }
    print('requesting auth');
    bool granted = await requestAuthorization([HealthDataType.ECG]);
    if (!granted) {
      String api =
          _platformType == PlatformType.ANDROID ? "Google Fit" : "Apple Health";
      throw _HealthException(
          [HealthDataType.ECG], "Permission was not granted for $api");
    }

    try {
      List fetchedDataPoints = await _channel.invokeMethod('getECG', {
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch
      });
      return fetchedDataPoints.map((e) => ECG.fromMap(e)).toList();
    } catch (error) {
      throw _HealthException([HealthDataType.ECG], "error occoured $error");
    }
  }

  /// Get ECG
  Future<List<double>> getECGData(DateTime startDate, DateTime endDate) async {
    /// If not implemented on platform, throw an exception
    if (!_isDataTypeAvailable(HealthDataType.ECG)) {
      throw _HealthException(
          HealthDataType.ECG, "Not available on platform $_platformType");
    }
    print('requesting auth');
    bool granted = await requestAuthorization([HealthDataType.ECG]);
    if (!granted) {
      String api =
          _platformType == PlatformType.ANDROID ? "Google Fit" : "Apple Health";
      throw _HealthException(
          [HealthDataType.ECG], "Permission was not granted for $api");
    }

    try {
      List values = await _channel.invokeMethod('getECGData', {
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch
      });
      return values.map((e) => double.parse(e.toString())).toList();
    } catch (error) {
      throw _HealthException([HealthDataType.ECG], "error occoured $error");
    }
  }
}
