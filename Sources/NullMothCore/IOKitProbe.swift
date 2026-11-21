import Foundation
import IOKit

enum IOKitProbe {
    static func properties(ofServiceNamed name: String) -> [String: Any] {
        guard let service = firstService(named: name) else { return [:] }
        defer { IOObjectRelease(service) }
        return properties(of: service)
    }

    static func firstService(named name: String) -> io_service_t? {
        guard let matching = IOServiceMatching(name) else { return nil }
        var iterator: io_iterator_t = 0
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iterator)
        guard result == KERN_SUCCESS else { return nil }
        defer { IOObjectRelease(iterator) }
        let service = IOIteratorNext(iterator)
        return service == 0 ? nil : service
    }

    static func properties(of service: io_service_t) -> [String: Any] {
        var unmanaged: Unmanaged<CFMutableDictionary>?
        let result = IORegistryEntryCreateCFProperties(
            service,
            &unmanaged,
            kCFAllocatorDefault,
            0
        )
        guard result == KERN_SUCCESS,
              let dictionary = unmanaged?.takeRetainedValue() as? [String: Any]
        else {
            return [:]
        }
        return dictionary
    }

    static func number(_ dictionary: [String: Any], _ key: String) -> Double? {
        if let number = dictionary[key] as? NSNumber {
            return number.doubleValue
        }
        if let string = dictionary[key] as? String {
            return Double(string)
        }
        return nil
    }

    static func uint64(_ dictionary: [String: Any], _ key: String) -> UInt64? {
        if let number = dictionary[key] as? NSNumber {
            return number.uint64Value
        }
        if let string = dictionary[key] as? String {
            return UInt64(string)
        }
        return nil
    }

    static func string(_ dictionary: [String: Any], _ key: String) -> String? {
        dictionary[key] as? String
    }
}
