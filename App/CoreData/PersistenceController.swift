//
//  PersistenceController.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 10.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import CoreData

class PersistenceController: ObservableObject {
    static let shared = PersistenceController()
    
    let container: NSPersistentContainer
    
    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "Gemocard")
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error {
                print("Core Data failed to load: \(error.localizedDescription)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
    
    func save(context: NSManagedObjectContext) {
        do {
            try context.save()
        } catch {
            print("Core Data failed to save model: \(error.localizedDescription)")
        }
    }
    
    func createMeasurementFromStruct(measurement: MeasurementResult?, measurementHeader: MeasurementHeaderResult?, ecgData: [UInt32]?, ecgStatusData: [UInt8]?, context: NSManagedObjectContext) {
        let measurementModel = Measurement(context: context)
        
        measurementModel.id = UUID()
        
        if let measurement = measurement {
            measurementModel.date = measurement.date
            measurementModel.measMode = measurement.measMode
            measurementModel.period = measurement.period
            measurementModel.originallyPlannedNumberOfRevisionsInSeries = measurement.originallyPlannedNumberOfRevisionsInSeries
            measurementModel.numberOfSuccessfulMeasurment = measurement.numberOfSuccessfulMeasurment
            measurementModel.changeSeriesEndFlag = Int16(measurement.changeSeriesEndFlag.rawValue)
            measurementModel.idSeriesOfMeasurement = measurement.idSeriesOfMeasurement
            measurementModel.userId = measurement.userId
            measurementModel.bloodPressureSystolic = measurement.bloodPressureSystolic
            measurementModel.bloodPressureDiastolic = measurement.bloodPressureDiastolic
            measurementModel.heartRate = measurement.heartRate
            measurementModel.arrhythmiaStatus = Int16(measurement.arrhythmiaStatus.rawValue)
            measurementModel.rhythmDisturbances = measurement.rhythmDisturbances
            measurementModel.headerHash = Int64(measurement.date.timeIntervalSince1970)
        } else {
            measurementModel.measMode = false
            measurementModel.period = 0
            measurementModel.originallyPlannedNumberOfRevisionsInSeries = 0
            measurementModel.numberOfSuccessfulMeasurment = 0
            measurementModel.changeSeriesEndFlag = Int16(ChangeSeriesEndFlag.unknown.rawValue)
            measurementModel.idSeriesOfMeasurement = 0
            measurementModel.bloodPressureSystolic = 0
            measurementModel.bloodPressureDiastolic = 0
            measurementModel.heartRate = 0
            measurementModel.arrhythmiaStatus = Int16(ArrhythmiaStatus.unknown.rawValue)
            measurementModel.rhythmDisturbances = 0
        }
        
        measurementModel.ecgData = ecgData
        measurementModel.ecgStatusData = ecgStatusData
        
        if let measurementHeader = measurementHeader {
            measurementModel.deviceOperatingMode = Int16(measurementHeader.deviceOperatingMode.rawValue)
            measurementModel.measChan = Int16(measurementHeader.measChan.rawValue)
            measurementModel.maxMeasurementLength = measurementHeader.maxMeasurementLength
            measurementModel.sampleRate = Int16(measurementHeader.sampleRate.rawValue)
            measurementModel.arterialPressureWavefromNumber = measurementHeader.arterialPressureWavefromNumber
            measurementModel.userId = measurementHeader.userId
            measurementModel.pointerToBeginningOfCardiogramInMemory = measurementHeader.pointerToBeginningOfCardiogramInMemory
            measurementModel.headerHash = Int64(measurementHeader.customHashValue)
                                                
            if measurement == nil {
                measurementModel.date = measurementHeader.date
            }
        } else {
            measurementModel.deviceOperatingMode = Int16(DeviceOperatingMode.arterialPressure.rawValue)
        }
        
//        print("Saving core data: \(measurementModel)\n measurement: \(String(describing: measurement)), measurementHeader: \(String(describing: measurementHeader)), ecgCount: \(String(describing: ecgData?.count))")
        save(context: context)
    }
}
