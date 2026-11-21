import Foundation

/// One thing about the driver's setup that is right, wrong, or worth knowing.
public struct SettingsFinding: Codable, Equatable, Identifiable, Sendable {
    public enum Severity: String, Codable, Equatable, Sendable, CaseIterable {
        case ok
        case info
        case warning
        case critical

        public var label: String {
            switch self {
            case .ok: return "OK"
            case .info: return "Info"
            case .warning: return "Warning"
            case .critical: return "Critical"
            }
        }
    }

    public var id: String
    public var severity: Severity
    public var title: String
    public var detail: String

    public init(id: String, severity: Severity, title: String, detail: String) {
        self.id = id
        self.severity = severity
        self.title = title
        self.detail = detail
    }
}

/// The result of auditing the driver's setup against the NullMoth
/// documentation. Nothing here is written anywhere: the report only says what
/// the running system looks like and what it should look like.
public struct DriverSettingsReport: Codable, Equatable, Sendable {
    public var bootArgs: String
    public var csrActiveConfig: String?
    public var csrSatisfied: Bool?
    public var secureBootModel: String?
    public var whateverGreenLoaded: Bool
    public var kextsLoaded: Int
    public var kextsTotal: Int
    public var findings: [SettingsFinding]
    public var suggestedBootArgs: String

    public init(
        bootArgs: String = "",
        csrActiveConfig: String? = nil,
        csrSatisfied: Bool? = nil,
        secureBootModel: String? = nil,
        whateverGreenLoaded: Bool = false,
        kextsLoaded: Int = 0,
        kextsTotal: Int = 0,
        findings: [SettingsFinding] = [],
        suggestedBootArgs: String = ""
    ) {
        self.bootArgs = bootArgs
        self.csrActiveConfig = csrActiveConfig
        self.csrSatisfied = csrSatisfied
        self.secureBootModel = secureBootModel
        self.whateverGreenLoaded = whateverGreenLoaded
        self.kextsLoaded = kextsLoaded
        self.kextsTotal = kextsTotal
        self.findings = findings
        self.suggestedBootArgs = suggestedBootArgs
    }

    public var hasProblems: Bool {
        findings.contains { $0.severity == .warning || $0.severity == .critical }
    }
}

/// Audits boot arguments and SIP configuration against the requirements in the
/// NullMoth driver documentation.
///
/// The rules mirror <https://github.com/nullmoth/nvidia-macos-driver>:
/// the framebuffer and accelerator switches, four display heads, the AMFI
/// bypass, the IPC option, the forbidden legacy switches, `gfxrst=4` when
/// WhateverGreen is loaded, and a `csr-active-config` that contains `0x0A43`.
public enum DriverSettingsAudit {
    public struct BootArgumentRule: Sendable {
        public let key: String
        /// Arguments that satisfy the rule. For `anyOf` rules one of them is
        /// enough.
        public let tokens: [String]
        /// Arguments that are added to the suggestion when the rule is missing.
        public let recommended: [String]
        public let anyOf: Bool
        public let title: String
        public let detail: String
        public let severity: SettingsFinding.Severity
    }

    public static let required: [BootArgumentRule] = [
        BootArgumentRule(
            key: "nvfb",
            tokens: ["nvfb=1"],
            recommended: ["nvfb=1"],
            anyOf: false,
            title: "Framebuffer (nvfb=1)",
            detail: "The display driver only starts with nvfb=1.",
            severity: .warning
        ),
        BootArgumentRule(
            key: "nvaccel",
            tokens: ["nvaccel=1"],
            recommended: ["nvaccel=1"],
            anyOf: false,
            title: "Accelerator (nvaccel=1)",
            detail: "The Metal accelerator stays off until nvaccel=1 is present.",
            severity: .warning
        ),
        BootArgumentRule(
            key: "nvfbheads",
            tokens: ["nvfbheads=4"],
            recommended: ["nvfbheads=4"],
            anyOf: false,
            title: "Display heads (nvfbheads=4)",
            detail: "The driver is documented with four display heads.",
            severity: .warning
        ),
        BootArgumentRule(
            key: "nvkmsnosmooth",
            tokens: ["-nvkmsnosmooth"],
            recommended: ["-nvkmsnosmooth"],
            anyOf: false,
            title: "No smoothing (-nvkmsnosmooth)",
            detail: "The documented boot arguments include -nvkmsnosmooth.",
            severity: .warning
        ),
        BootArgumentRule(
            key: "amfi",
            tokens: ["amfi_get_out_of_my_way=0x1", "amfi=0x80", "-amfipassbeta"],
            recommended: ["amfi_get_out_of_my_way=0x1", "amfi=0x80"],
            anyOf: true,
            title: "AMFI bypass",
            detail: "WindowServer needs one of amfi_get_out_of_my_way=0x1, amfi=0x80 or -amfipassbeta to load the driver bundle.",
            severity: .warning
        ),
        BootArgumentRule(
            key: "ipc",
            tokens: ["ipc_control_port_options=0"],
            recommended: ["ipc_control_port_options=0"],
            anyOf: false,
            title: "IPC options (ipc_control_port_options=0)",
            detail: "The documented boot arguments include ipc_control_port_options=0.",
            severity: .warning
        ),
    ]

    public static let forbidden: [BootArgumentRule] = [
        BootArgumentRule(
            key: "nv_disable",
            tokens: ["nv_disable=1"],
            recommended: [],
            anyOf: false,
            title: "Remove nv_disable=1",
            detail: "nv_disable=1 hides the NVIDIA card from macOS.",
            severity: .critical
        ),
        BootArgumentRule(
            key: "wegnoegpu",
            tokens: ["-wegnoegpu"],
            recommended: [],
            anyOf: false,
            title: "Remove -wegnoegpu",
            detail: "-wegnoegpu hides the NVIDIA card from macOS.",
            severity: .critical
        ),
    ]

    public static let conditional: [BootArgumentRule] = [
        BootArgumentRule(
            key: "gfxrst",
            tokens: ["gfxrst=4"],
            recommended: ["gfxrst=4"],
            anyOf: false,
            title: "WhateverGreen needs gfxrst=4",
            detail: "WhateverGreen is loaded. Without gfxrst=4 its boot screen copy can read freed memory and the Mac can panic.",
            severity: .warning
        ),
    ]

    /// Troubleshooting switches the driver documents. They are never required.
    public static let troubleshooting: [BootArgumentRule] = [
        BootArgumentRule(
            key: "nvrmnoflip",
            tokens: ["-nvrmnoflip"],
            recommended: [],
            anyOf: false,
            title: "Tearing workaround (-nvrmnoflip)",
            detail: "Keeps the composited frame on the copy path. Try it when the desktop flashes or tears while the cursor moves.",
            severity: .info
        ),
        BootArgumentRule(
            key: "nvrmnopm",
            tokens: ["-nvrmnopm"],
            recommended: [],
            anyOf: false,
            title: "Sleep workaround (-nvrmnopm)",
            detail: "Turns off system sleep support for NVRM. Use it when the Mac sleeps and comes back without the GPU.",
            severity: .info
        ),
    ]

    /// The SIP bits the driver is tested with.
    public static let requiredCSRBits: UInt32 = 0x0A43

    public static func audit(
        bootArgs: String,
        csrActiveConfig: String? = nil,
        whateverGreenLoaded: Bool = false,
        kextsLoaded: Int = 0,
        kextsTotal: Int = 0
    ) -> DriverSettingsReport {
        let tokens = Set(bootArgs.split(whereSeparator: \.isWhitespace).map(String.init))
        var findings: [SettingsFinding] = []
        var missingTokens: [String] = []

        for rule in required {
            let satisfied = rule.tokens.contains(where: { tokens.contains($0) })

            if satisfied {
                findings.append(
                    SettingsFinding(
                        id: "required.\(rule.key)",
                        severity: .ok,
                        title: rule.title,
                        detail: rule.detail
                    )
                )
            } else {
                missingTokens.append(contentsOf: rule.recommended)
                findings.append(
                    SettingsFinding(
                        id: "required.\(rule.key)",
                        severity: rule.severity,
                        title: rule.title,
                        detail: "Missing. Add \(rule.recommended.joined(separator: " ")) to boot-args."
                    )
                )
            }
        }

        for rule in forbidden {
            let present = rule.tokens.filter { tokens.contains($0) }
            if present.isEmpty {
                findings.append(
                    SettingsFinding(
                        id: "forbidden.\(rule.key)",
                        severity: .ok,
                        title: rule.title,
                        detail: "Not present."
                    )
                )
            } else {
                findings.append(
                    SettingsFinding(
                        id: "forbidden.\(rule.key)",
                        severity: rule.severity,
                        title: rule.title,
                        detail: "Remove \(present.joined(separator: ", ")) from boot-args."
                    )
                )
            }
        }

        for rule in conditional {
            guard whateverGreenLoaded else {
                continue
            }
            let satisfied = rule.tokens.contains(where: { tokens.contains($0) })
            findings.append(
                SettingsFinding(
                    id: "conditional.\(rule.key)",
                    severity: satisfied ? .ok : rule.severity,
                    title: rule.title,
                    detail: satisfied ? "Present." : "Missing. Add \(rule.recommended.joined(separator: " ")) to boot-args."
                )
            )
            if !satisfied {
                missingTokens.append(contentsOf: rule.recommended)
            }
        }

        for rule in troubleshooting {
            let present = rule.tokens.contains(where: { tokens.contains($0) })
            findings.append(
                SettingsFinding(
                    id: "optional.\(rule.key)",
                    severity: .info,
                    title: rule.title,
                    detail: present ? "Present." : rule.detail
                )
            )
        }

        let csrValue = csrActiveConfig.flatMap(parseCSRValue)
        let csrSatisfied = csrValue.map { csrSatisfies($0) }

        if csrValue != nil {
            findings.append(
                SettingsFinding(
                    id: "csr",
                    severity: csrSatisfied == true ? .ok : .critical,
                    title: "SIP configuration (csr-active-config)",
                    detail: csrSatisfied == true
                        ? "The value contains the tested bits \(hex(requiredCSRBits))."
                        : "The value does not contain the tested bits \(hex(requiredCSRBits)). The driver needs csr-active-config \(hex(requiredCSRBits)) in OpenCore."
                )
            )
        } else {
            findings.append(
                SettingsFinding(
                    id: "csr",
                    severity: .info,
                    title: "SIP configuration (csr-active-config)",
                    detail: "The NVRAM value could not be read. The driver needs csr-active-config \(hex(requiredCSRBits)) in OpenCore."
                )
            )
        }

        findings.append(
            SettingsFinding(
                id: "kexts",
                severity: kextsTotal > 0 && kextsLoaded == kextsTotal ? .ok : .warning,
                title: "Driver extensions",
                detail: kextsTotal > 0
                    ? "\(kextsLoaded) of \(kextsTotal) driver extensions are loaded."
                    : "The driver extensions were not found."
            )
        )

        findings.append(
            SettingsFinding(
                id: "secureboot",
                severity: .info,
                title: "SecureBootModel",
                detail: "An OpenCore setting that cannot be read at runtime. Set Misc > Security > SecureBootModel to Disabled."
            )
        )

        let forbiddenTokens = Set(forbidden.flatMap(\.tokens))
        let suggested = suggestedBootArgs(
            current: bootArgs,
            missing: missingTokens,
            forbidden: forbiddenTokens
        )

        return DriverSettingsReport(
            bootArgs: bootArgs,
            csrActiveConfig: csrActiveConfig,
            csrSatisfied: csrSatisfied,
            secureBootModel: nil,
            whateverGreenLoaded: whateverGreenLoaded,
            kextsLoaded: kextsLoaded,
            kextsTotal: kextsTotal,
            findings: findings,
            suggestedBootArgs: suggested
        )
    }

    /// Builds a boot-args string with the forbidden switches removed and the
    /// missing ones added. Every other argument is kept in its original order.
    public static func suggestedBootArgs(
        current: String,
        missing: [String],
        forbidden: Set<String>
    ) -> String {
        var tokens = current.split(whereSeparator: \.isWhitespace).map(String.init)
        tokens.removeAll { forbidden.contains($0) }

        for token in missing where !tokens.contains(token) {
            tokens.append(token)
        }

        return tokens.joined(separator: " ")
    }

    /// Parses the value `nvram -X csr-active-config` prints, for example
    /// `430a0000`, into the 32-bit number the OpenCore setting holds.
    public static func parseCSRValue(_ hex: String) -> UInt32? {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "0x", with: "")
            .replacingOccurrences(of: "0X", with: "")

        guard cleaned.count == 8, cleaned.allSatisfy({ $0.isHexDigit }) else {
            return nil
        }

        var bytes: [UInt8] = []
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let next = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<next], radix: 16) else {
                return nil
            }
            bytes.append(byte)
            index = next
        }

        // The NVRAM value is stored little endian.
        return bytes.enumerated().reduce(UInt32(0)) { partial, element in
            partial | (UInt32(element.element) << (8 * UInt32(element.offset)))
        }
    }

    public static func csrSatisfies(_ value: UInt32, required: UInt32 = requiredCSRBits) -> Bool {
        value & required == required
    }

    public static func hex(_ value: UInt32) -> String {
        "0x" + String(format: "%08X", value)
    }
}
