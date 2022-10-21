//
//  GetDataController.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 18.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import SwiftUI
import CoreData
import Foundation

enum GetDataStatusCodes {
    case timeout
    case invalidCrc
    case done
}

class GetDataController {
    
    private let gemocardSDK: GemocardSDK
    private let healthKitAvailible: Bool
    
    private let throwAlert: (_ errorInfo: ErrorInfo, _ feedbackType: UINotificationFeedbackGenerator.FeedbackType?) -> Void
    private let progressUpdate: (_ progress: Float) -> Void
    
    private let persistenceController = PersistenceController.shared
    
    /// Delay between requests in seconds
    private let delay: Double
    
    private var ecgMeasurementsCount = 0
    private var currentEcgMeasurement: UInt8 = 0
    private var arterialPressureMeasurementsCount = 0
    private var currentArterialPressureMeasurement: UInt16 = 0
    
    private var completion: ((_ status: GetDataStatusCodes) -> Void)!
    
    private var maxDateWhileFetching: Date? = UserDefaults.lastSyncedDateKey
    
    private var syncedArterialPresuures = [UInt16]()
    
    init(gemocardSDK: GemocardSDK, healthKitAvailible: Bool, throwAlert: @escaping (_: ErrorInfo, _: UINotificationFeedbackGenerator.FeedbackType?) -> Void, progressUpdate: @escaping (_: Float) -> Void, delay: Double) {
        self.gemocardSDK = gemocardSDK
        self.healthKitAvailible = healthKitAvailible
        self.throwAlert = throwAlert
        self.progressUpdate = progressUpdate
        self.delay = delay
    }
    
    private func onRequestFail(_ failureCode: FailureCodes) {
        switch failureCode {
        case .timeout:
            completion(.timeout)
        case .invalidCrc:
            completion(.invalidCrc)
        }
    }
    
    private func finishMeasurementFetch() {
        self.progressUpdate(1)
        if let maxDateWhileFetching = maxDateWhileFetching {
            UserDefaults.lastSyncedDateKey = maxDateWhileFetching
        }
        self.completion(.done)
    }
    
    private func getNextMeasurentHeader() {
        currentEcgMeasurement += 1
        if currentEcgMeasurement < ecgMeasurementsCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                self.gemocardSDK.getEcgMeasurementHeader(measurementNumber: self.currentEcgMeasurement, completion: self.processMeasurementHeaderResult, оnFailure: self.onRequestFail)
            }
        } else {
            if arterialPressureMeasurementsCount == 0 {
                finishMeasurementFetch()
            } else {
                if !syncedArterialPresuures.contains(currentArterialPressureMeasurement) {
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                        self.gemocardSDK.getMeasurementArterialPressure(measurementNumber: self.currentArterialPressureMeasurement, completion: self.processArterialPressureMeasurement, оnFailure: self.onRequestFail)
                    }
                } else {
                    getNextArterialPressureMeasurement()
                }
            }
        }
    }
    
    private func getNextArterialPressureMeasurement() {
        currentArterialPressureMeasurement += 1
        if currentArterialPressureMeasurement < arterialPressureMeasurementsCount {
            if !syncedArterialPresuures.contains(currentArterialPressureMeasurement) {
                DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                    self.gemocardSDK.getMeasurementArterialPressure(measurementNumber: self.currentArterialPressureMeasurement, completion: self.processArterialPressureMeasurement, оnFailure: self.onRequestFail)
                }
            } else {
                getNextArterialPressureMeasurement()
            }
        } else {
            finishMeasurementFetch()
        }
    }
    
    private func checkIfEcgMeasurementIsNewInDB(_ measurementHeaderResult: MeasurementHeaderResult) -> Bool {
        let context = persistenceController.container.viewContext
        let fetchRequest = Measurement.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "headerHash == %ld", measurementHeaderResult.customHashValue, #keyPath(Measurement.headerHash))
        
        guard let objects = try? context.fetch(fetchRequest) else {
            print("Core Data failed to fetch hash")
//            guard let error = error as? Error else {
//                print("Core Data failed to fetch hash")
//                return false
//            }
//            print("Core Data failed to fetch: \(error.localizedDescription)")
            // TODO: add sentry
            // SentrySDK.capture(error: error)
            return false
        }
        
        return objects.isEmpty
    }
    
    private func checkIfEcgMeasurementIsNewByDate(_ date: Date) -> Bool {
        guard let savedDate = UserDefaults.lastSyncedDateKey else { return true }
        print("Saved date: \(savedDate), measurement header result date: \(date), is new: \(savedDate < date)")
        return savedDate < date
    }
    
    private func processMaxDateWhileFetching(_ measurementResult: MeasurementResult) {
        if let maxDateWhileFetching = self.maxDateWhileFetching {
            if maxDateWhileFetching < measurementResult.date {
                self.maxDateWhileFetching = measurementResult.date
            }
        } else {
            self.maxDateWhileFetching = measurementResult.date
        }
    }
    
    private func saveEcgOrArterialMeasurement(_ measurementResult: MeasurementResult, _ measurementHeaderResult: MeasurementHeaderResult?, _ ECGdata: [UInt32]?, _ ECGStatusData: [UInt8]?) {
        let context = self.persistenceController.container.viewContext
        self.persistenceController.createMeasurementFromStruct(measurement: measurementResult, measurementHeader: measurementHeaderResult, ecgData: ECGdata, ecgStatusData: ECGStatusData, context: context)
        
        if self.healthKitAvailible {
            HealthKitController.saveRecord(
                heartRate: Double(measurementResult.heartRate),
                bloodPressureSystolic: Double(measurementResult.bloodPressureSystolic),
                bloodPressureDiastolic: Double(measurementResult.bloodPressureDiastolic),
                date: measurementResult.date)
        }
        
        print("Saved ecg/pressure measurement \(self.currentEcgMeasurement): \(measurementResult), \(String(describing: measurementHeaderResult)), with ecg count: \(String(describing: ECGdata?.count))")
    }
    
    private func saveEcgMeasurement(_ measurementHeaderResult: MeasurementHeaderResult, _ ECGdata: [UInt32]?, _ ECGStatusData: [UInt8]?) {
        
        let context = self.persistenceController.container.viewContext
        self.persistenceController.createMeasurementFromStruct(measurement: nil, measurementHeader: measurementHeaderResult, ecgData: ECGdata, ecgStatusData: ECGStatusData, context: context)
        
        print("Saved ecg measurement \(self.currentEcgMeasurement): \(measurementHeaderResult), with ecg count: \(String(describing: ECGdata?.count))")
    }
    
    private func processArterialPressureMeasurement(_ measurementResult: MeasurementResult) {
        print("Got Arterial pressure measurement \(self.currentArterialPressureMeasurement)")
        
        if checkIfEcgMeasurementIsNewByDate(measurementResult.date) {
            
            processMaxDateWhileFetching(measurementResult)
            if measurementResult.changeSeriesEndFlag != .seriesCanceled {
                saveEcgOrArterialMeasurement(measurementResult, nil, nil, nil)
            } else {
                print("Not saved canceled  meaurement (\(self.currentArterialPressureMeasurement)), \(measurementResult)")
                
            }
            getNextArterialPressureMeasurement()
            
        } else {
            print("Skipping already synchronized object (\(self.currentArterialPressureMeasurement))")
            getNextArterialPressureMeasurement()
        }
    }
    
    private func processMeasurementHeaderResult(_ measurementHeaderResult: MeasurementHeaderResult) {
        print("Got ECG measurement header (\(self.currentEcgMeasurement)): \(measurementHeaderResult)")
        
        let progress = 0.1 + ((Float(self.currentEcgMeasurement + 1) - 0.5) / Float(self.ecgMeasurementsCount + 1)) * 0.9
        progressUpdate(progress)
        
        if checkIfEcgMeasurementIsNewByDate(measurementHeaderResult.date) && checkIfEcgMeasurementIsNewInDB(measurementHeaderResult) {
            
            DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                self.gemocardSDK.getECG(ECGnumber: self.currentEcgMeasurement, completion: { ECGdata, ECGStatusData in
                    
                    let progress = 0.1 + (Float(self.currentEcgMeasurement + 1) / Float(self.ecgMeasurementsCount + 1)) * 0.9
                    self.progressUpdate(progress)
                    
                    if measurementHeaderResult.deviceOperatingMode == .arterialPressureAndElectrocardiogram {
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                            self.gemocardSDK.getMeasurementArterialPressure(measurementNumber: UInt16(self.currentEcgMeasurement), completion: { measurementResult in
                                
                                self.syncedArterialPresuures.append(UInt16(self.currentEcgMeasurement))
                                if measurementResult.changeSeriesEndFlag != .seriesCanceled {
                                    
                                    self.processMaxDateWhileFetching(measurementResult)
                                    self.saveEcgOrArterialMeasurement(measurementResult, measurementHeaderResult, ECGdata, ECGStatusData)
                                    self.getNextMeasurentHeader()
                                    
                                } else {
                                    print("Not saved canceled  meaurement (\(self.currentEcgMeasurement)), \(measurementResult), \(measurementHeaderResult)")
                                    self.getNextMeasurentHeader()
                                }
                                
                            }, оnFailure: self.onRequestFail)
                        }
                    } else if measurementHeaderResult.measChan == .LR {
                        self.saveEcgMeasurement(measurementHeaderResult, ECGdata, ECGStatusData)
                        self.getNextMeasurentHeader()
                    } else {
                        print("Skipping ECG measurement with unsupported meas chan: \(measurementHeaderResult.measChan) object (\(self.currentEcgMeasurement))")
                    }
                    
                }, оnFailure: self.onRequestFail)
            }
            
        } else {
            print("Skipping already synchronized object (\(self.currentArterialPressureMeasurement))")
            getNextMeasurentHeader()
        }
    }
    
    public func getData(completion: @escaping (_ status: GetDataStatusCodes) -> Void) {
        self.completion = completion
        progressUpdate(0.05)
        
        currentEcgMeasurement = 0
        currentArterialPressureMeasurement = 0
        
        self.syncedArterialPresuures = []
        
        gemocardSDK.getNumberOfMeasurementsArterialPressure(completion: { arterialPressureMeasurementsCount in
            self.gemocardSDK.getNumberOfMeasurements(completion:  { ecgMeasurementsCount in
                
                self.arterialPressureMeasurementsCount = arterialPressureMeasurementsCount
                self.ecgMeasurementsCount = ecgMeasurementsCount
                
                self.progressUpdate(0.1)
                
                print("Arterial Pressure measurements count: \(arterialPressureMeasurementsCount), ECG Measurements count: \(ecgMeasurementsCount)")
                
                if ecgMeasurementsCount == 0 {
                    if arterialPressureMeasurementsCount == 0 {
                        self.finishMeasurementFetch()
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                            self.gemocardSDK.getMeasurementArterialPressure(measurementNumber: self.currentArterialPressureMeasurement, completion: self.processArterialPressureMeasurement, оnFailure: self.onRequestFail)
                        }
                    }
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + self.delay) {
                        self.gemocardSDK.getEcgMeasurementHeader(measurementNumber: self.currentEcgMeasurement, completion: self.processMeasurementHeaderResult, оnFailure: self.onRequestFail)
                    }
                }
                
            }, оnFailure: self.onRequestFail)
        }, оnFailure: self.onRequestFail)
    }
}
