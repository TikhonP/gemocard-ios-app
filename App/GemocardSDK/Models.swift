//
//  Model.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 07.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

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

struct ExchangeMode: OptionSet {
    let rawValue: UInt8
    
    static let ECG1   = Self(rawValue: 1 << 0)
    static let ECG2  = Self(rawValue: 1 << 1)
    static let ECG4  = Self(rawValue: 1 << 2)
    static let pressureWaveforms = Self(rawValue: 1 << 3)
    
    /// Unsupported now
    static let photoplethysmogram = Self(rawValue: 1 << 4)
}

enum SampleRate: UInt8 {
    case sr417_5 = 0x04 // 417,5 Гц
    case sr500 = 0x05   // 500 Гц
    case sr1000 = 0x10  // 1000 Гц
    case unknown = 0x00
}

struct MeasurementResult {
    let deviceOperatingMode: DeviceOperatingMode
    let measChan: MeasChan
    
    let maxMeasurementLength: Int
    
    let sampleRate: SampleRate
    
    let arterialPressureWavefromNumber: Int
    let userNumber: Int
    
    /// Указатель на начало кардиограммы в памяти. Нужно для контроля перезаписи устаревших сигналов.
    /// При перекрывающихся адресах, актуальной кардиограммой считается та, у которой N меньше.
    let pointerToBeginningOfCardiogramInMemory: Int
    
    let year: Int
    let month: Int
    let day: Int
    let hour: Int
    let minute: Int
    let second: Int
}
