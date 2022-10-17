//
//  Model.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 07.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

// MARK: - Measurement Header Model

/// Режим работы прибора
enum DeviceOperatingMode: UInt8 {
    case arterialPressure = 0xF0
    case Electrocardiogram = 0x0F
    case arterialPressureAndElectrocardiogram = 0xFF
    case unknown = 0x00
}

/// Active ECG channels
enum MeasChan: UInt8 {
    case LR = 0x01
    case LR_FR = 0x03
    case LR_FR_C1 = 0x07
    case LR_FR_C1_C2_C3_C4_C5_C6 = 0xFF
    case unknown = 0x00
}

enum SampleRate: UInt8 {
    case sr417_5 = 0x04 // 417,5 Гц
    case sr500 = 0x05   // 500 Гц
    case sr1000 = 0x10  // 1000 Гц
    case unknown = 0x00
}

struct MeasurementHeaderResult {
    let deviceOperatingMode: DeviceOperatingMode
    let measChan: MeasChan
    
    let maxMeasurementLength: Int16
    
    let sampleRate: SampleRate
    
    let arterialPressureWavefromNumber: Int16
    let userId: Int16
    
    /// Указатель на начало кардиограммы в памяти. Нужно для контроля перезаписи устаревших сигналов.
    /// При перекрывающихся адресах, актуальной кардиограммой считается та, у которой N меньше.
    let pointerToBeginningOfCardiogramInMemory: Int32
    
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
    let second: Int
    
    static func deserialize(bytes: [UInt8]) -> MeasurementHeaderResult {
        let measurementResult = MeasurementHeaderResult(
            deviceOperatingMode: DeviceOperatingMode(rawValue: bytes[2]) ?? .unknown,
            measChan: MeasChan(rawValue: bytes[3]) ?? .unknown,
            maxMeasurementLength: Int16(bytes[4]),
            sampleRate: SampleRate(rawValue: bytes[5]) ?? .unknown,
            arterialPressureWavefromNumber: Int16(bytes[6]),
            userId: Int16(bytes[7]),
            pointerToBeginningOfCardiogramInMemory: Int32(DataSerializer.twoBytesToInt(MSBs: bytes[8], LSBs: bytes[9])),
            year: Int(bytes[10]) + 2000, month: Int(bytes[11]), day: Int(bytes[12]), hour: Int(bytes[13]), minute: Int(bytes[14]), second: Int(bytes[15]))
        return measurementResult
    }
    
    var date: Date {
        let calendar = Calendar(identifier: .gregorian)
        let dateComponents = DateComponents(timeZone: TimeZone.current, year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        return calendar.date(from: dateComponents)!
    }
    
    var customHashValue: Int {
        return Int(date.timeIntervalSince1970)
    }
}

// MARK: - Measurement Model

/// Флаг завершения серии изм
enum ChangeSeriesEndFlag: UInt8 {
    
    /// не является ЗЗС
    case notZZC = 0x00
    
    /// серия отменена
    case seriesCanceled = 0xCA
    
    /// серия завершена успешно
    case seriesSuccess = 0x5F
    
    case unknown = 0x01
}

enum ArrhythmiaStatus: UInt8 {
    
    /// нарушений ритма нет
    case noRhythmDisturbances = 0x00
    
    /// однократное нарушение ритма
    case singleRhythmDisorder = 0x01
    
    /// многократные нарушения ритма
    case repeatedRhythmDisturbances = 0x02
    
    /// продолжительная аритмия
    case prolongedArrhythmia = 0x03
    
    case unknown = 0x04
}

struct MeasurementResult {
    
    /// MeasMode: 1 – серия, 0 – обычное измерение
    let measMode: Bool
    
    /// Period: период измерений в [¼ мин], от 6 до 40, по умолчанию 8
    let period: Int16
    
    /// изначально запланированное число изм. в серии
    let originallyPlannedNumberOfRevisionsInSeries: Int16
    
    /// номер успешного изм. в серии (число успешных изм. в серии для ЗЗС)
    let numberOfSuccessfulMeasurment: Int16
    
    let changeSeriesEndFlag: ChangeSeriesEndFlag
    
    /// ID серии измерений
    let idSeriesOfMeasurement: Int16
    
    /// номер пользователя
    let userId: Int16
    
    let systolicBloodPressure: Int32
    let diastolicBloodPressure: Int32
    let pulse: Int16
    
    let arrhythmiaStatus: ArrhythmiaStatus
    
    /// Число/процент нарушений ритма:
    /// - если статус аритмии "однократное нарушение ритма" или "многократные нарушения ритма", то число нарушений ритма
    /// - если статус аритмии "продолжительная аритмия", то процент нарушений ритма
    let rhythmDisturbances: Int16
    
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
    let second: Int
    
    static func deserialize(bytes: [UInt8]) -> MeasurementResult {
        let measurementResult = MeasurementResult(
            measMode: ((bytes[2] >> 7) != 0),
            period: Int16(bytes[2] & 0x0F),
            originallyPlannedNumberOfRevisionsInSeries: Int16(bytes[3]),
            numberOfSuccessfulMeasurment: Int16(bytes[4]),
            changeSeriesEndFlag: ChangeSeriesEndFlag(rawValue: bytes[6]) ?? .unknown,
            idSeriesOfMeasurement: Int16(bytes[7]),
            userId: Int16(bytes[8]),
            systolicBloodPressure: Int32(DataSerializer.twoBytesToInt(MSBs: bytes[9], LSBs: bytes[10])),
            diastolicBloodPressure: Int32(DataSerializer.twoBytesToInt(MSBs: bytes[11], LSBs: bytes[12])),
            pulse: Int16(bytes[13]),
            arrhythmiaStatus: ArrhythmiaStatus(rawValue: bytes[14]) ?? .unknown,
            rhythmDisturbances: Int16(bytes[15]),
            year: Int(bytes[16]) + 2000, month: Int(bytes[17]), day: Int(bytes[18]), hour: Int(bytes[19]), minute: Int(bytes[20]), second: Int(bytes[21]))
        return measurementResult
    }
    
    var date: Date {
        let calendar = Calendar(identifier: .gregorian)
        let dateComponents = DateComponents(timeZone: TimeZone.current, year: year, month: month, day: day, hour: hour, minute: minute, second: second)
        return calendar.date(from: dateComponents)!
    }
}

// MARK: - ECG Data Models

struct BrokenElectrodesAndPacemaker: OptionSet {
    let rawValue: UInt8
    
    static let brokenR = Self(rawValue: 1 << 0)
    static let brokenF = Self(rawValue: 1 << 1)
    static let brokenC1 = Self(rawValue: 1 << 2)
    static let brokenL = Self(rawValue: 1 << 3)
    static let pacemakerDetection = Self(rawValue: 1 << 4)
}

// MARK: - Get Gemocard Data Models

/// статус прибора
enum DeviceStatus: UInt8 {
    /// ожидание (готов к работе)
    case readyWaiting = 0x00
    
    /// измерение
    case measurement = 0x01
    
    /// тестовый режим
    case testMode = 0x02
    
    /// ожидание серии (готов к работе в режиме серии измерений)
    case readyWaitingSeries = 0x03
    
    /// измерение в режиме серии
    case seriesMeasurement = 0x04
    
    /// ожидание последующего измерения в серии
    case waitingNextSeriesMeasurement = 0x05
    
    case unknown
}
