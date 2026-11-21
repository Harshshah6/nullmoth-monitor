import Foundation
import IOKit

public enum SMCProbe {
    private static let kernelIndex: UInt32 = 2
    private static let commandReadKeyInfo: UInt8 = 9
    private static let commandReadBytes: UInt8 = 5
    private static let structureSize = 80
    private static let resultOffset = 37
    private static let keyInfoDataSizeOffset = 28
    private static let keyInfoDataTypeOffset = 32
    private static let data8Offset = 39
    private static let bytesOffset = 44

    public static func fans() -> [FanInfo] {
        guard let connection = openSMC() else {
            return []
        }
        defer { IOServiceClose(connection) }

        do {
            let countReading = try readKey("FNum", connection: connection)
            let count = Int(countReading.value)
            guard count > 0 else {
                return []
            }

            return try (0..<count).map { index in
                let reading = try readKey("F\(index)Ac", connection: connection)
                return FanInfo(index: index, rpm: reading.value)
            }
        } catch {
            return []
        }
    }

    private static func openSMC() -> io_connect_t? {
        guard let service = IOKitProbe.firstService(named: "AppleSMC") else {
            return nil
        }
        defer { IOObjectRelease(service) }

        var connection: io_connect_t = 0
        let result = IOServiceOpen(service, mach_task_self_, 0, &connection)
        return result == KERN_SUCCESS ? connection : nil
    }

    private static func readKey(
        _ key: String,
        connection: io_connect_t
    ) throws -> (value: Double, type: String) {
        let keyValue = fourCCValue(key)

        var infoInput = [UInt8](repeating: 0, count: structureSize)
        writeUInt32(keyValue, to: &infoInput, at: 0)
        infoInput[data8Offset] = commandReadKeyInfo
        let infoOutput = try call(connection, input: &infoInput)
        guard infoOutput[resultOffset] == 0 else {
            throw SMCError.smc(infoOutput[resultOffset])
        }

        let dataSize = readUInt32(infoOutput, at: keyInfoDataSizeOffset)
        let dataType = readUInt32(infoOutput, at: keyInfoDataTypeOffset)
        let type = fourCCString(dataType)

        var readInput = [UInt8](repeating: 0, count: structureSize)
        writeUInt32(keyValue, to: &readInput, at: 0)
        writeUInt32(dataSize, to: &readInput, at: keyInfoDataSizeOffset)
        readInput[data8Offset] = commandReadBytes
        let readOutput = try call(connection, input: &readInput)
        guard readOutput[resultOffset] == 0 else {
            throw SMCError.smc(readOutput[resultOffset])
        }

        let end = bytesOffset + Int(dataSize)
        guard end <= readOutput.count else {
            throw SMCError.unsupportedType(type)
        }

        let bytes = Array(readOutput[bytesOffset..<end])
        return (try decode(type: type, bytes: bytes), type)
    }

    private static func call(
        _ connection: io_connect_t,
        input: inout [UInt8]
    ) throws -> [UInt8] {
        var output = [UInt8](repeating: 0, count: structureSize)
        var outputSize = structureSize

        let result = input.withUnsafeBytes { inputBytes in
            output.withUnsafeMutableBytes { outputBytes in
                IOConnectCallStructMethod(
                    connection,
                    kernelIndex,
                    inputBytes.baseAddress,
                    structureSize,
                    outputBytes.baseAddress,
                    &outputSize
                )
            }
        }

        guard result == KERN_SUCCESS else {
            throw SMCError.ioKit(result)
        }
        return output
    }

    private static func decode(type: String, bytes: [UInt8]) throws -> Double {
        switch type {
        case "flt ":
            guard bytes.count >= 4 else { throw SMCError.unsupportedType(type) }
            return Double(Float(bitPattern: readUInt32(bytes, at: 0)))
        case "fpe2":
            guard bytes.count >= 2 else { throw SMCError.unsupportedType(type) }
            return Double(readUInt16BigEndian(bytes, at: 0)) / 4.0
        case "ui8 ":
            guard let first = bytes.first else { throw SMCError.unsupportedType(type) }
            return Double(first)
        case "ui16":
            guard bytes.count >= 2 else { throw SMCError.unsupportedType(type) }
            return Double(readUInt16BigEndian(bytes, at: 0))
        default:
            throw SMCError.unsupportedType(type)
        }
    }

    private static func fourCCValue(_ value: String) -> UInt32 {
        value.utf8.reduce(0) { ($0 << 8) | UInt32($1) }
    }

    private static func fourCCString(_ value: UInt32) -> String {
        let bigEndian = value.bigEndian
        let bytes = withUnsafeBytes(of: bigEndian) { Array($0) }
        return String(bytes: bytes, encoding: .ascii) ?? ""
    }

    private static func writeUInt32(_ value: UInt32, to buffer: inout [UInt8], at offset: Int) {
        buffer[offset] = UInt8(value & 0xff)
        buffer[offset + 1] = UInt8((value >> 8) & 0xff)
        buffer[offset + 2] = UInt8((value >> 16) & 0xff)
        buffer[offset + 3] = UInt8((value >> 24) & 0xff)
    }

    private static func readUInt32(_ buffer: [UInt8], at offset: Int) -> UInt32 {
        UInt32(buffer[offset])
            | (UInt32(buffer[offset + 1]) << 8)
            | (UInt32(buffer[offset + 2]) << 16)
            | (UInt32(buffer[offset + 3]) << 24)
    }

    private static func readUInt16BigEndian(_ buffer: [UInt8], at offset: Int) -> UInt16 {
        (UInt16(buffer[offset]) << 8) | UInt16(buffer[offset + 1])
    }

    private enum SMCError: Error {
        case ioKit(kern_return_t)
        case smc(UInt8)
        case unsupportedType(String)
    }
}
