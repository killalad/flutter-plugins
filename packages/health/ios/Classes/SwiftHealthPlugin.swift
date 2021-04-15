import Flutter
import UIKit
import HealthKit

extension Date {
    static func mondayAt12AM() -> Date {
        return Calendar(identifier: .iso8601).date(from: Calendar(identifier: .iso8601).dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
    }
}

public class SwiftHealthPlugin: NSObject, FlutterPlugin {
    
    let healthStore = HKHealthStore()
    var quantityTypes: [String: HKQuantityTypeIdentifier] = [:]
    var categoryTypes: [String: HKCategoryTypeIdentifier] = [:]
    var ecgSympoms = Set<HKCategoryTypeIdentifier>()
    var discreteList = [HKQuantityTypeIdentifier]()
    var unitDict: [String: HKUnit] = [:]
    
    // Health Data Type Keys
    let ACTIVE_ENERGY_BURNED = "ACTIVE_ENERGY_BURNED"
    let BASAL_ENERGY_BURNED = "BASAL_ENERGY_BURNED"
    let BLOOD_GLUCOSE = "BLOOD_GLUCOSE"
    let BLOOD_OXYGEN = "BLOOD_OXYGEN"
    let BLOOD_PRESSURE_DIASTOLIC = "BLOOD_PRESSURE_DIASTOLIC"
    let BLOOD_PRESSURE_SYSTOLIC = "BLOOD_PRESSURE_SYSTOLIC"
    let BODY_FAT_PERCENTAGE = "BODY_FAT_PERCENTAGE"
    let BODY_MASS_INDEX = "BODY_MASS_INDEX"
    let BODY_TEMPERATURE = "BODY_TEMPERATURE"
    let ELECTRODERMAL_ACTIVITY = "ELECTRODERMAL_ACTIVITY"
    let EXERCISE_TIME = "EXERCISE_TIME"
    let HEART_RATE = "HEART_RATE"
    let HEART_RATE_VARIABILITY_SDNN = "HEART_RATE_VARIABILITY_SDNN"
    let HEIGHT = "HEIGHT"
    let HIGH_HEART_RATE_EVENT = "HIGH_HEART_RATE_EVENT"
    let IRREGULAR_HEART_RATE_EVENT = "IRREGULAR_HEART_RATE_EVENT"
    let LOW_HEART_RATE_EVENT = "LOW_HEART_RATE_EVENT"
    let RESTING_HEART_RATE = "RESTING_HEART_RATE"
    let STEPS = "STEPS"
    let WAIST_CIRCUMFERENCE = "WAIST_CIRCUMFERENCE"
    let WALKING_HEART_RATE = "WALKING_HEART_RATE"
    let WEIGHT = "WEIGHT"
    let DISTANCE_WALKING_RUNNING = "DISTANCE_WALKING_RUNNING"
    let FLIGHTS_CLIMBED = "FLIGHTS_CLIMBED"
    let WATER = "WATER"
    let MINDFULNESS = "MINDFULNESS"
    let SLEEP_IN_BED = "SLEEP_IN_BED"
    let SLEEP_ASLEEP = "SLEEP_ASLEEP"
    let SLEEP_AWAKE = "SLEEP_AWAKE"
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "flutter_health", binaryMessenger: registrar.messenger())
        let instance = SwiftHealthPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Set up all data types
        initializeTypes()
        
        /// Handle checkIfHealthDataAvailable
        if (call.method.elementsEqual("checkIfHealthDataAvailable")){
            checkIfHealthDataAvailable(call: call, result: result)
        }
        
        /// Handle requestAuthorization
        else if (call.method.elementsEqual("requestAuthorization")){
            requestAuthorization(call: call, result: result)
        }
        
        /// Handle getData
        else if (call.method.elementsEqual("getData")){
            getData(call: call, result: result)
        }
        
        /// Handle getECG
        else if (call.method.elementsEqual("getECG")){
            getECG(call: call, result: result)
        }
        
        /// Handle getECGData
        else if (call.method.elementsEqual("getECGData")){
            getECGData(call: call, result: result)
        }
    }
    
    func checkIfHealthDataAvailable(call: FlutterMethodCall, result: @escaping FlutterResult) {
        result(HKHealthStore.isHealthDataAvailable())
    }
    
    func requestAuthorization(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary
        let types = (arguments?["types"] as? Array) ?? []
        
        var typesToRequest = Set<HKSampleType>()
        
        for key in types {
            let keyString = "\(key)"
            if (keyString == "ECG") {
                if #available(iOS 14.0, *) {
                    typesToRequest.insert(HKObjectType.electrocardiogramType())
                    for ecgSymptom in ecgSympoms {
                        typesToRequest.insert(HKSampleType.categoryType(forIdentifier:ecgSymptom)!)
                    }
                }
            }
            else if(quantityTypes[keyString] != nil) {
                typesToRequest.insert(HKObjectType.quantityType(forIdentifier: quantityTypes[keyString]!)!)
            }
            else if (categoryTypes[keyString] != nil) {
                typesToRequest.insert(HKObjectType.categoryType(forIdentifier: categoryTypes[keyString]!)!)
            }
        }
        if(typesToRequest.isEmpty) {
            result(FlutterError(code: "FlutterHealth", message: "No types to request", details: nil))
            return
        }
        if #available(iOS 11.0, *) {
            healthStore.requestAuthorization(toShare: nil, read: typesToRequest) { (success, error) in
                result(success)
            }
        }
        else {
            result(false)// Handle the error here.
        }
    }
    
    func getECG(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 14.0, *) {
            let arguments = call.arguments as? NSDictionary
            let startDate = (arguments?["startDate"] as? NSNumber) ?? 0
            let endDate = (arguments?["endDate"] as? NSNumber) ?? 0
            
            let dateFrom = Date(timeIntervalSince1970: startDate.doubleValue / 1000)
            let dateTo = Date(timeIntervalSince1970: endDate.doubleValue / 1000)
            let predicate = HKQuery.predicateForSamples(withStart: dateFrom, end: dateTo, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            
            let ecgQuery = HKSampleQuery(sampleType: HKObjectType.electrocardiogramType(),
                                         predicate: predicate,
                                         limit: HKObjectQueryNoLimit,
                                         sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                if let error = error {
                    result(FlutterError(code: "FlutterHealth", message: "An error occurred", details: error))
                    return
                }
                
                guard let ecgSamples = samples as? [HKElectrocardiogram] else {
                    result(FlutterError(code: "FlutterHealth", message: "unable to convert samples to HKElectrocardiogram", details: error))
                    return
                }
                let heartRateUnit: HKUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                var returnDict = [NSDictionary]()
                var i = 0
                for ecgSample in ecgSamples {
                    // print(ecgSample)
                    // if(ecgSample.symptomsStatus.rawValue == 2) {
                        
                    //     var symptomsForCurrentEcg = Set<String>()
                    //     var j = 0
                    //     for symptom in self.ecgSympoms {
                    //         let symptomQuery = HKSampleQuery(sampleType: HKSampleType.categoryType(forIdentifier:symptom)!, predicate: HKQuery.predicateForObjectsAssociated(electrocardiogram: ecgSample), limit: 1, sortDescriptors: nil) { (query, samples,error) in
                    //             j += 1
                    //             if(samples?.first != nil) {
                    //                 symptomsForCurrentEcg.insert("\(samples!.first!.sampleType)")
                    //             }
                    //             if(j == self.ecgSympoms.count) {
                    //                 i += 1
                    //                 returnDict.append( [
                    //                     "average": ecgSample.averageHeartRate?.doubleValue(for: heartRateUnit) ?? 0.0,
                    //                     "samplingFrequency": ecgSample.samplingFrequency?.doubleValue(for: HKUnit.hertz()) ?? 0.0,
                    //                     "classification": ecgSample.classification.rawValue,
                    //                     "date_from": Int(ecgSample.startDate.timeIntervalSince1970 * 1000),
                    //                     "date_to": Int(ecgSample.endDate.timeIntervalSince1970 * 1000),
                    //                     "symptoms": symptomsForCurrentEcg.joined(separator: ",")
                    //                 ])
                    //                 if(i == ecgSamples.count){
                    //                     result(returnDict)
                    //                     return
                    //                 }
                    //             }
                    //         }
                    //         self.healthStore.execute(symptomQuery)
                    //     }
                    // }
                    // else {
                        i += 1
                        returnDict.append( [
                            "average": ecgSample.averageHeartRate?.doubleValue(for: heartRateUnit) ?? 0.0,
                            "samplingFrequency": ecgSample.samplingFrequency?.doubleValue(for: HKUnit.hertz()) ?? 0.0,
                            "classification": ecgSample.classification.rawValue,
                            "date_from": Int(ecgSample.startDate.timeIntervalSince1970 * 1000),
                            "date_to": Int(ecgSample.endDate.timeIntervalSince1970 * 1000),
                            "symptoms": ""
                        ])
                        if(i == ecgSamples.count){
                            result(returnDict)
                            return
                        }
                    // }
                }
            }
            healthStore.execute(ecgQuery)
            return
        }
        else {
            result(FlutterError(code: "FlutterHealth", message: "unsupported ios",details: "update to iOS 14"))
            return
        }
    }
    
    func getECGData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        if #available(iOS 14.0, *) {
            let arguments = call.arguments as? NSDictionary
            let startDate = (arguments?["startDate"] as? NSNumber) ?? 0
            let endDate = (arguments?["endDate"] as? NSNumber) ?? 0
            
            let dateFrom = Date(timeIntervalSince1970: startDate.doubleValue / 1000)
            let dateTo = Date(timeIntervalSince1970: endDate.doubleValue / 1000)
            let predicate = HKQuery.predicateForSamples(withStart: dateFrom, end: dateTo, options: .strictStartDate)
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
            
            let ecgQuery = HKSampleQuery(sampleType: HKObjectType.electrocardiogramType(),
                                         predicate: predicate,
                                         limit: 1,
                                         sortDescriptors: [sortDescriptor]) { (query, samples, error) in
                if let error = error {
                    result(FlutterError(code: "FlutterHealth", message: "An error occurred", details: error))
                    return
                }
                
                guard let ecgSamples = samples as? [HKElectrocardiogram] else {
                    result(FlutterError(code: "FlutterHealth", message: "unable to convert samples to HKElectrocardiogram", details: error))
                    return
                }
                
                if(ecgSamples.first == nil) {
                    result(FlutterError(code: "FlutterHealth", message: "no record found", details: nil))
                    return
                }
                
                var data = [Double]()
                let voltageQuery = HKElectrocardiogramQuery(ecgSamples.first!) { (query, res) in
                    switch(res) {
                    
                    case .measurement(let measurement):
                        if let voltageQuantity = measurement.quantity(for: .appleWatchSimilarToLeadI) {
                            data.append(voltageQuantity.doubleValue(for: HKUnit.voltUnit(with: .micro)))
                        }
                    case .done:
                        //done
                        result(data)
                        return
                        
                    case .error(let error):
                        result(FlutterError(code: "FlutterHealth", message: "error occoured during get voltage data", details: error))
                        return
                    default:
                        result(FlutterError(code: "FlutterHealth", message: "unsupported operation", details: nil))
                        return
                    }
                }
                self.healthStore.execute(voltageQuery)
            }
            healthStore.execute(ecgQuery)
            return
        }
        else {
            result(FlutterError(code: "FlutterHealth", message: "unsupported ios",details: "update to iOS 14"))
            return
        }
    }
    
    func getData(call: FlutterMethodCall, result: @escaping FlutterResult) {
        let arguments = call.arguments as? NSDictionary
        let dataTypeKey = (arguments?["dataTypeKey"] as? String) ?? "DEFAULT"
        let startDate = (arguments?["startDate"] as? NSNumber) ?? 0
        let endDate = (arguments?["endDate"] as? NSNumber) ?? 0
        
        let dateFrom = Date(timeIntervalSince1970: startDate.doubleValue / 1000)
        let dateTo = Date(timeIntervalSince1970: endDate.doubleValue / 1000)
        
        let anchorDate = Date.mondayAt12AM()
        let interval =  DateComponents(hour: 1)
        
        let predicate = HKQuery.predicateForSamples(withStart: dateFrom, end: dateTo, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: true)
        
        if(quantityTypes[dataTypeKey] != nil && !discreteList.contains(quantityTypes[dataTypeKey]!)){
            let query = HKStatisticsCollectionQuery(quantityType: HKObjectType.quantityType(forIdentifier: quantityTypes[dataTypeKey]!)!, quantitySamplePredicate: predicate, options: .cumulativeSum, anchorDate: anchorDate, intervalComponents: interval)
            query.initialResultsHandler = { query, statisticsCollection, error in
                if statisticsCollection != nil {
                    result(statisticsCollection!.statistics().map { sample -> NSDictionary in
                        let unit = self.unitLookUp(key: dataTypeKey)
                        return [
                            "value": sample.sumQuantity()?.doubleValue(for: unit) ?? Int(0),
                            "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                            "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                        ]
                    })
                }
                else {
                    result(FlutterError(code: "FlutterHealth", message: "statisticsCollection is nil", details: error))
                }
            }
            healthStore.execute(query)
        } else if (quantityTypes[dataTypeKey] != nil ) {
            let query = HKSampleQuery(sampleType: HKObjectType.quantityType(forIdentifier: quantityTypes[dataTypeKey]!)!, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) {
                x, samplesOrNil, error in
                guard let samples = samplesOrNil as? [HKQuantitySample] else {
                    result(FlutterError(code: "FlutterHealth", message: "Results are null", details: error))
                    return
                }
                result(samples.map { sample -> NSDictionary in
                    let unit = self.unitLookUp(key: dataTypeKey)
                    
                    return [
                        "uuid": "\(sample.uuid)",
                        "value": sample.quantity.doubleValue(for: unit),
                        "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                        "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                    ]
                })
                return
            }
            healthStore.execute(query)
            return
        } else if (categoryTypes[dataTypeKey] != nil) {
            let query = HKSampleQuery(sampleType: HKObjectType.categoryType(forIdentifier: categoryTypes[dataTypeKey]!)!, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) {
                x, samplesOrNil, error in
                
                guard let samplesCategory = samplesOrNil as? [HKCategorySample] else {
                    result(FlutterError(code: "FlutterHealth", message: "Results are null", details: error))
                    return
                }
                result(samplesCategory.map { sample -> NSDictionary in
                    return [
                        "uuid": "\(sample.uuid)",
                        "value": sample.value,
                        "date_from": Int(sample.startDate.timeIntervalSince1970 * 1000),
                        "date_to": Int(sample.endDate.timeIntervalSince1970 * 1000),
                    ]
                })
                return
            }
            healthStore.execute(query)
            return
        }
        else {
            result(FlutterError(code: "FlutterHealth", message: "Unsupported type", details: ""))
            return
        }
    }
    
    func unitLookUp(key: String) -> HKUnit {
        guard let unit = unitDict[key] else {
            return HKUnit.count()
        }
        return unit
    }
    
    
    func initializeTypes() {
        unitDict[ACTIVE_ENERGY_BURNED] = HKUnit.kilocalorie()
        unitDict[BASAL_ENERGY_BURNED] = HKUnit.kilocalorie()
        unitDict[BLOOD_GLUCOSE] = HKUnit.init(from: "mg/dl")
        unitDict[BLOOD_OXYGEN] = HKUnit.percent()
        unitDict[BLOOD_PRESSURE_DIASTOLIC] = HKUnit.millimeterOfMercury()
        unitDict[BLOOD_PRESSURE_SYSTOLIC] = HKUnit.millimeterOfMercury()
        unitDict[BODY_FAT_PERCENTAGE] = HKUnit.percent()
        unitDict[BODY_MASS_INDEX] = HKUnit.init(from: "")
        unitDict[BODY_TEMPERATURE] = HKUnit.degreeCelsius()
        unitDict[ELECTRODERMAL_ACTIVITY] = HKUnit.siemen()
        unitDict[EXERCISE_TIME] = HKUnit.minute()
        unitDict[HEART_RATE] = HKUnit.init(from: "count/min")
        unitDict[HEART_RATE_VARIABILITY_SDNN] = HKUnit.secondUnit(with: .milli)
        unitDict[HEIGHT] = HKUnit.meter()
        unitDict[RESTING_HEART_RATE] = HKUnit.init(from: "count/min")
        unitDict[STEPS] = HKUnit.count()
        unitDict[WAIST_CIRCUMFERENCE] = HKUnit.meter()
        unitDict[WALKING_HEART_RATE] = HKUnit.init(from: "count/min")
        unitDict[WEIGHT] = HKUnit.gramUnit(with: .kilo)
        unitDict[DISTANCE_WALKING_RUNNING] = HKUnit.meter()
        unitDict[FLIGHTS_CLIMBED] = HKUnit.count()
        unitDict[WATER] = HKUnit.liter()
        unitDict[MINDFULNESS] = HKUnit.init(from: "")
        unitDict[SLEEP_IN_BED] = HKUnit.init(from: "")
        unitDict[SLEEP_ASLEEP] = HKUnit.init(from: "")
        unitDict[SLEEP_AWAKE] = HKUnit.init(from: "")
        
        // Set up iOS 11 specific types (ordinary health data types)
        if #available(iOS 11.0, *) {
            discreteList = [
                HKQuantityTypeIdentifier.bodyMassIndex,
                HKQuantityTypeIdentifier.bodyFatPercentage,
                HKQuantityTypeIdentifier.height,
                HKQuantityTypeIdentifier.bodyMass,
                HKQuantityTypeIdentifier.leanBodyMass,
                HKQuantityTypeIdentifier.waistCircumference,
                HKQuantityTypeIdentifier.vo2Max,
                HKQuantityTypeIdentifier.heartRate,
                HKQuantityTypeIdentifier.bodyTemperature,
                HKQuantityTypeIdentifier.basalBodyTemperature,
                HKQuantityTypeIdentifier.bloodPressureSystolic,
                HKQuantityTypeIdentifier.bloodPressureDiastolic,
                HKQuantityTypeIdentifier.respiratoryRate,
                HKQuantityTypeIdentifier.restingHeartRate,
                HKQuantityTypeIdentifier.walkingHeartRateAverage,
                HKQuantityTypeIdentifier.heartRateVariabilitySDNN,
                HKQuantityTypeIdentifier.oxygenSaturation,
                HKQuantityTypeIdentifier.peripheralPerfusionIndex,
                HKQuantityTypeIdentifier.bloodGlucose,
                HKQuantityTypeIdentifier.electrodermalActivity,
                HKQuantityTypeIdentifier.bloodAlcoholContent,
                HKQuantityTypeIdentifier.forcedVitalCapacity,
                HKQuantityTypeIdentifier.forcedExpiratoryVolume1,
                HKQuantityTypeIdentifier.peakExpiratoryFlowRate,
                HKQuantityTypeIdentifier.electrodermalActivity,
            ]
            
            quantityTypes[ACTIVE_ENERGY_BURNED] = .activeEnergyBurned
            quantityTypes[BASAL_ENERGY_BURNED] = .basalEnergyBurned
            quantityTypes[BLOOD_GLUCOSE] = .bloodGlucose
            quantityTypes[BLOOD_OXYGEN] = .oxygenSaturation
            quantityTypes[BLOOD_PRESSURE_DIASTOLIC] = .bloodPressureDiastolic
            quantityTypes[BLOOD_PRESSURE_SYSTOLIC] = .bloodPressureSystolic
            quantityTypes[BODY_FAT_PERCENTAGE] = .bodyFatPercentage
            quantityTypes[BODY_MASS_INDEX] = .bodyMassIndex
            quantityTypes[BODY_TEMPERATURE] = .bodyTemperature
            quantityTypes[ELECTRODERMAL_ACTIVITY] = .electrodermalActivity
            quantityTypes[EXERCISE_TIME] = .appleExerciseTime
            quantityTypes[HEART_RATE] = .heartRate
            quantityTypes[HEART_RATE_VARIABILITY_SDNN] = .heartRateVariabilitySDNN
            quantityTypes[HEIGHT] = .height
            quantityTypes[RESTING_HEART_RATE] = .restingHeartRate
            quantityTypes[STEPS] = .stepCount
            quantityTypes[WAIST_CIRCUMFERENCE] = .waistCircumference
            quantityTypes[WALKING_HEART_RATE] = .walkingHeartRateAverage
            quantityTypes[WEIGHT] = .bodyMass
            quantityTypes[DISTANCE_WALKING_RUNNING] = .distanceWalkingRunning
            quantityTypes[FLIGHTS_CLIMBED] = .flightsClimbed
            quantityTypes[WATER] = .dietaryWater
            categoryTypes[MINDFULNESS] = .mindfulSession
            categoryTypes[SLEEP_IN_BED] = .sleepAnalysis
            categoryTypes[SLEEP_ASLEEP] = .sleepAnalysis
            categoryTypes[SLEEP_AWAKE] = .sleepAnalysis
        }
        // Set up heart rate data types specific to the apple watch, requires iOS 12
        if #available(iOS 12.2, *){
            categoryTypes[HIGH_HEART_RATE_EVENT] = .highHeartRateEvent
            categoryTypes[LOW_HEART_RATE_EVENT] = .lowHeartRateEvent
            categoryTypes[IRREGULAR_HEART_RATE_EVENT] = .irregularHeartRhythmEvent
        }
        if #available(iOS 14.0, *) {
            ecgSympoms = [
                HKCategoryTypeIdentifier.rapidPoundingOrFlutteringHeartbeat,
                HKCategoryTypeIdentifier.skippedHeartbeat,
                HKCategoryTypeIdentifier.fatigue,
                HKCategoryTypeIdentifier.shortnessOfBreath,
                HKCategoryTypeIdentifier.chestTightnessOrPain,
                HKCategoryTypeIdentifier.fainting,
                HKCategoryTypeIdentifier.dizziness,
            ]
        }
    }
}




