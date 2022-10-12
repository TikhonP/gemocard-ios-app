//
//  HealthKitController.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 12.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation
import HealthKit


class HealthKitController {
    private enum HealthkitSetupError: Error {
        case notAvailableOnDevice
        case dataTypeNotAvailable
    }
    
    class func authorizeHealthKit(completion: @escaping (Bool, Error?) -> Swift.Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, HealthkitSetupError.notAvailableOnDevice)
            return
        }
        
        guard let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
              let bloodPressureSystolic = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
              let bloodPressureDiastolic = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
            completion(false, HealthkitSetupError.dataTypeNotAvailable)
            return
        }
        
        let healthKitTypesToWrite: Set<HKSampleType> = [heartRate,
                                                        bloodPressureSystolic,
                                                        bloodPressureDiastolic]
        
        HKHealthStore().requestAuthorization(toShare: healthKitTypesToWrite, read: []) { (success, error) in
            completion(success, error)
        }
    }
    
    class func saveRecord(heartRate: Double, bloodPressureSystolic: Double, bloodPressureDiastolic: Double, date: Date) {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
                  let bloodPressureSystolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureSystolic),
                  let bloodPressureDiastolicType = HKObjectType.quantityType(forIdentifier: .bloodPressureDiastolic) else {
                      print("Body Mass Index Type is no longer available in HealthKit")
                      return
                  }
        
        let bloodPressureSystolicQuantity = HKQuantity(unit: HKUnit.millimeterOfMercury(), doubleValue: bloodPressureSystolic)
        let bloodPressureSystolicSample = HKQuantitySample(type: bloodPressureSystolicType, quantity: bloodPressureSystolicQuantity, start: date, end: date)
        
        let bloodPressureDiastolicQuantity = HKQuantity(unit: HKUnit.millimeterOfMercury(), doubleValue: bloodPressureDiastolic)
        let bloodPressureDiastolicSample = HKQuantitySample(type: bloodPressureDiastolicType, quantity: bloodPressureDiastolicQuantity, start: date, end: date)
        
        let heartRateQuantity = HKQuantity(unit: HKUnit.count().unitDivided(by: HKUnit.minute()), doubleValue: heartRate)
        let heartRateSample = HKQuantitySample(type: heartRateType, quantity: heartRateQuantity, start: date, end: date)
        
        var samples = [HKQuantitySample]()
        samples.append(bloodPressureSystolicSample)
        samples.append(bloodPressureDiastolicSample)
        samples.append(heartRateSample)
        
        HKHealthStore().save(samples) { (success, error) in
            if let error = error {
                print("Error Saving health kit: \(error.localizedDescription)")
            } else {
                print("Successfully saved Health Kit")
            }
        }
    }
}
