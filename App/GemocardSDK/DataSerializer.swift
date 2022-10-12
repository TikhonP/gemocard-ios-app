//
//  DataSerializer.swift
//  Medsenger Gemocard
//
//  Created by Tikhon Petrishchev on 05.10.2022.
//  Copyright © 2022 OOO Telepat. All rights reserved.
//

import Foundation

/// All data in bytes to send to Gemocard
class DataSerializer {
    
    // MARK: - Data Serializer utils
    
    /// Convert two bytes to single unsigned int
    /// - Parameters:
    ///   - msb: first byte
    ///   - lsb: second byte
    /// - Returns: single number
    class func twoBytesToInt(MSBs: UInt8, LSBs: UInt8) -> UInt16 {
        return (UInt16(MSBs) << 8) | UInt16(LSBs)
    }
    
    /// Convert UInt to two UInt8 bytes
    /// - Parameter number: Number to convert
    /// - Returns: Two bytes: (msb, lsb)
    class func intToTwoBytes(_ number: UInt16) -> (MSBs: UInt8, LSBs: UInt8) {
        let LSBs = UInt8(number & 0b11111111)
        let MSBs = UInt8(number >> 8)
        return (MSBs, LSBs)
    }
    
    /// CRC-8 Maxim/Dallas Algorithm
    /// - Parameter byteArray: input byte array
    /// - Returns: int8 hash
    class func crc(_ byteArray: [UInt8]) -> UInt8 {
        var crc: UInt8 = byteArray[0]
        for var byte in byteArray.prefix(byteArray.count - 1) {
            for _ in 0...7 {
                if (((byte ^ crc) & 0x01) != 0) {
                    crc = ((crc ^ 0x18) >> 1) | 0x80
                } else {
                    crc >>= 1
                }
                byte >>= 1
            }
        }
        return crc
    }
    
    /// Modify last elemt of byte array with computed CRC and return Data object
    /// - Parameter byteArray: input byte array
    /// - Returns: Data object
    class func addCrc(_ byteArray: [UInt8]) -> Data {
        var byteArray = byteArray
        byteArray[byteArray.count - 1] = DataSerializer.crc(byteArray)
        return Data(byteArray)
    }
    
    // MARK: - Команды ГемоДин
    
    /// Запрос статуса прибора
    /// - Returns: serialized Data object
    class func deviceStatusQuery() -> Data {
        let bytes: [UInt8] = [0xAA, 0x03, 0x01, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Ответ на запрос статуса прибора
    /// - Parameter bytes: byte array
    /// - Returns: current device status mode and  current cuff oreasure
    class func deviceStatusDeserializer(bytes: [UInt8]) -> (deviceStatus: DeviceStatus, deviceOperatingMode: DeviceOperatingMode, cuffPressure: UInt16) {
        let deviceStatusCode = bytes[2] & 0x0F
        let deviceStatus: DeviceStatus = DeviceStatus(rawValue: deviceStatusCode) ?? .unknown
        var deviceOperatingMode: DeviceOperatingMode = .unknown
        if ((bytes[2] & 0x80) != 0) && ((bytes[2] & 0x40) != 0) {
            deviceOperatingMode = .arterialPressureAndElectrocardiogram
        } else if ((bytes[2] & 0x80) != 0) {
            deviceOperatingMode = .arterialPressure
        } else if ((bytes[2] & 0x40) != 0) {
            deviceOperatingMode = .Electrocardiogram
        }
        let cuffPressure = DataSerializer.twoBytesToInt(MSBs: bytes[3], LSBs: bytes[4])
        return (deviceStatus, deviceOperatingMode, cuffPressure)
    }
    
    /// Отмена измерения
    /// - Returns: serialized Data object
    class func cancelMeasurement() -> Data {
        let bytes: [UInt8] = [0xAA, 0x03, 0x04, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Установить время
    /// - Returns: serialized Data object
    class func setTime() -> Data {
        let date = Date()
        let calendar = Calendar.current
//        calendar.timeZone = TimeZone(identifier: "UTC")!
        let bytes: [UInt8] = [
            0xAA, 0x06, 0x0C,
            UInt8(calendar.component(.hour, from: date)),
            UInt8(calendar.component(.minute, from: date)),
            UInt8(calendar.component(.second, from: date)),
            0
        ]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Установить дату
    /// - Returns: serialized Data object
    class func setDate() -> Data {
        let date = Date()
        let calendar = Calendar.current
        
        let bytes: [UInt8] = [
            0xAA, 0x06, 0x0D,
            UInt8(calendar.component(.day, from: date)),
            UInt8(calendar.component(.month, from: date)),
            UInt8(calendar.component(.year, from: date) % 100),
            0
        ]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Запрос даты и времени из прибора
    /// - Returns: serialized Data object
    class func requestDateAndTimeFromDevice() -> Data {
        let bytes: [UInt8] = [0xAA, 0x03, 0x0F, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Ответ на запрос даты и времени из прибора
    /// - Parameter bytes: byte array
    /// - Returns: optional datetime
    class func dateAndTimeFromDeviceDeserializer(bytes: [UInt8]) -> Date? {
        let dateComponents = DateComponents(timeZone: TimeZone(identifier: "UTC"),
            year: Int(bytes[7]) + 2000, month: Int(bytes[6]), day: Int(bytes[5]),
            hour: Int(bytes[4]), minute: Int(bytes[3]), second: Int(bytes[2])
        )
        let userCalendar = Calendar(identifier: .gregorian)
        return userCalendar.date(from: dateComponents)
    }
    
    /// Стереть память прибора
    /// - Returns: serialized Data object
    class func eraseMemory() -> Data {
        let bytes: [UInt8] = [0xAA, 0x03, 0x11, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Получить версию ПО прибора
    /// - Returns: serialized Data object
    class func getFirmwareVersion() -> Data {
        let bytes: [UInt8] = [0xAA, 0x03, 0x12, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Получить серийный номер прибора
    /// - Returns: serialized Data object
    class func getSerialNumber() -> Data {
        let bytes: [UInt8] = [0xAA, 0x03, 0x13, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Начать измерение на пользователя N
    /// - Parameter user: номер пользователя – N
    /// - Returns: serialized Data object
    class func startMeasurementForUser(user: UInt8) -> Data {
        let bytes: [UInt8] = [0xAA, 0x04, 0x19, user, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Запрос результатов N предыдущего измерения
    /// - Parameter numberOfPreviousMeasurement: номер измерения
    /// - Returns: serialized Data object
    class func getResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: UInt16) -> Data {
        let results = DataSerializer.intToTwoBytes(numberOfPreviousMeasurement)
        let bytes: [UInt8] = [0xAA, 0x05, 0x26, results.MSBs, results.LSBs, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Ответ на запрос результатов N предыдущего измерения
    /// - Parameter bytes: byte array
    /// - Returns: Mesurement result instance
    class func resultsNumberOfPreviousMeasurementDeserializer(bytes: [UInt8]) -> MeasurementResult {
        return MeasurementResult.deserialize(bytes: bytes)
    }
    
    // MARK: - Команды ГемоКард
    
    /// Запуск обмена в комбинированном  режиме
    /// - Parameters:
    ///   - ECG1: флаг запроса отведения ЭКГ I
    ///   - ECG2: флаг запроса отведения ЭКГ II
    ///   - ECG4: флаг запроса отведения ЭКГ V1
    ///   - pressureWaveforms: флаг запроса осциллограммы давления
    /// - Returns: serialized Data object
    class func startingExchange(
        ECG1: Bool = false,
        ECG2: Bool = false,
        ECG4: Bool = false,
        pressureWaveforms: Bool = false
        //        photoplethysmogram: Bool = false  // Unsupported now
    ) -> Data {
        var exchangeMode: ExchangeMode = []
        if ECG1 { exchangeMode.insert(.ECG1) }
        if ECG2 { exchangeMode.insert(.ECG2) }
        if ECG4 { exchangeMode.insert(.ECG4) }
        if pressureWaveforms { exchangeMode.insert(.pressureWaveforms) }
        
        let bytes: [UInt8] = [0xAA, 0x04, 0x40, exchangeMode.rawValue, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Установить  режим работы прибора
    /// - Parameter deviceOperatingMode: режим работы прибора
    /// - Returns: serialized Data object
    class func setOperatingModeOfDevice(deviceOperatingMode: DeviceOperatingMode) -> Data {
        let bytes: [UInt8] = [0xAA, 0x04, 0x61, deviceOperatingMode.rawValue, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Установить режим снятия ЭКГ
    /// - Parameters:
    ///   - measChan: флаг активных каналов снятия ЭКГ
    ///   - maxRecordingLength: максимальная длительность измерения:
    ///    - для (MeasChan == 0x01) доступны значения от 8 до 20 с шагом 2 (от 2 до 5 мин аналогично команде №19 ГемоДин);
    ///    - для (MeasChan == 0x03) доступно только 2 минуты, этот параметр игнорируется;
    ///    - для (MeasChan == 0x07) доступно только 2 минуты, этот параметр игнорируется;
    ///    - для (MeasChan == 0xFF) доступно только 10 секунд, этот параметр игнорируется.
    /// - Returns: serialized Data object
    class func setECGrecordingMode(measChan: MeasChan, maxRecordingLength: UInt8 = 3) -> Data {
        let bytes: [UInt8] = [0xAA, 0x05, 0x62, measChan.rawValue, maxRecordingLength, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Запрос режима снятия ЭКГ
    /// - Returns: serialized Data object
    class func ECGrecordingModeRequest() -> Data {
        let bytes: [UInt8] = [0xAA, 0x03, 0x63, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Запрос количества измерений в памяти устройства
    /// - Returns: serialized Data object
    class func getNumberOfMeasurementsInDeviceMemory() -> Data {
        let bytes: [UInt8] = [0xAA, 0x03, 0x65, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Ответ на запрос количества измерений в памяти устройства
    /// - Parameter bytes: byte array
    /// - Returns: number of measuremnnts in memory
    class func numberOfMeasurementsInDeviceMemoryDeserializer(bytes: [UInt8]) -> UInt8 {
        return bytes[2]
    }
    
    /// Запрос результатов N предыдущего измерения
    /// - Parameter numberOfPreviousMeasurement: номер измерения
    /// - Returns: serialized Data object
    class func getHeaderResultsNumberOfPreviousMeasurement(numberOfPreviousMeasurement: UInt8) -> Data {
        let bytes: [UInt8] = [0xAA, 0x04, 0x66, numberOfPreviousMeasurement, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Ответ на запрос результатов N предыдущего измерения
    /// - Parameter bytes: byte array
    /// - Returns: measurement results struct
    class func resultsHeaderNumberOfPreviousMeasurementDeserializer(bytes: [UInt8]) -> MeasurementHeaderResult {
        return MeasurementHeaderResult.deserialize(bytes: bytes)
    }
    
    /// Команда считывает заголовок и весь ЭКГ-сигнал
    /// - Parameter numberOfPreviousECG: Number of ECG
    /// - Returns: serialized Data object
    class func getResultsNumberOfPreviousECG(numberOfPreviousECG: UInt8) -> Data {
        let bytes: [UInt8] = [0xAA, 0x04, 0x67, numberOfPreviousECG, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Команда считывает заголовок и ЭКГ-сигнал
    ///
    /// Команда позволяет считать:
    /// - при указании номера пакета 0 -весь ЭКГ-сигнал с заголовком;
    /// - при указании номера пакета 65535 — заголовок ЭКГ-сигнала;
    /// - при указании номера пакета от 1 до 65534 — пакет или несколько пакетов (устанавливается командой 0x68, при включении прибора значение равно «1», т. е. один пакет) ЭКГ-сигнала по 98 байт, завершающий пакет может иметь размерность менее 98 байт. Если будет запрашиваться пакеты, превышающие размерность ЭКГ-сигнала, то прибор ничего возвращать не будет.
    /// - Parameters:
    ///   - numberOfPreviousECG: Number of ECG
    ///   - packetNumber: Packet number
    /// - Returns: serialized Data object
    class func getResultsNumberOfPreviousECG(numberOfPreviousECG: UInt8, packetNumber: UInt16) -> Data {
        let packetNumberBytes = DataSerializer.intToTwoBytes(packetNumber)
        let bytes: [UInt8] = [0xAA, 0x06, 0x67, numberOfPreviousECG, packetNumberBytes.MSBs, packetNumberBytes.LSBs, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Команда устанавливает кол-во передаваемых пакетов в ответ на 6-ти байтную команду 0х67 в которой указан номер пакет от 1 до 65534.
    /// - Parameter packetsCount: Кол-во передаваемых байт можно установить от 0 до 255. Если установить значение 0, то в ответ на команду 0х67 прибор будет передавать пакеты от указанного в команде 0х67 до конца ЭКГ-сигнала.
    /// - Returns: serialized Data object
    class func setNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG(packetsCount: UInt8) -> Data {
        let bytes: [UInt8] = [0xAA, 0x04, 0x68, packetsCount, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Команда возвращает установленное значение кол-ва передаваемых пакетов в ответ на 6-ти байтную команду 0х67 в которой указан номер пакет от 1 до 65534.
    /// - Returns: serialized Data object
    class func requestForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECG() -> Data {
        let bytes: [UInt8] = [0xAA, 0x03, 0x69, 0]
        return DataSerializer.addCrc(bytes)
    }
    
    /// Ответ на команду, которая возвращает установленное значение кол-ва передаваемых пакетов в ответ на 6-ти байтную команду
    /// - Parameter bytes: byte array
    /// - Returns: packet count
    class func responseForSetNumberOfPacketsOf98bytesInResponseWhenRequestingNofPreviousECGDeserializer(bytes: [UInt8]) -> UInt8 {
        return bytes[2]
    }
}
