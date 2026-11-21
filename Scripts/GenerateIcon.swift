#!/usr/bin/env swift
//
// Generates Support/AppIcon.png (1024x1024) without external assets.
// Run with: swift Scripts/GenerateIcon.swift
//

import CoreGraphics
import Foundation
import ImageIO

let size = 1024
let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "Support/AppIcon.png"

guard let ctx = CGContext(
    data: nil,
    width: size,
    height: size,
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Could not create the bitmap context")
}

// Draw in top-left coordinates.
ctx.translateBy(x: 0, y: CGFloat(size))
ctx.scaleBy(x: 1, y: -1)
ctx.setShouldAntialias(true)
ctx.setAllowsAntialiasing(true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r, green: g, blue: b, alpha: a)
}

let cyan = color(0.22, 0.91, 1.00)
let teal = color(0.00, 0.70, 0.64)
let darkTeal = color(0.01, 0.20, 0.22, 0.55)
let whiteCyan = color(0.88, 1.00, 1.00)

func roundedPath(_ rect: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

func fill(_ path: CGPath, _ color: CGColor) {
    ctx.addPath(path)
    ctx.setFillColor(color)
    ctx.fillPath()
}

func stroke(_ path: CGPath, _ color: CGColor, _ width: CGFloat) {
    ctx.addPath(path)
    ctx.setStrokeColor(color)
    ctx.setLineWidth(width)
    ctx.setLineCap(.round)
    ctx.setLineJoin(.round)
    ctx.strokePath()
}

func gradientFill(
    _ path: CGPath,
    colors: [CGColor],
    start: CGPoint,
    end: CGPoint
) {
    ctx.saveGState()
    ctx.addPath(path)
    ctx.clip()
    if let gradient = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: colors as CFArray,
        locations: nil
    ) {
        ctx.drawLinearGradient(gradient, start: start, end: end, options: [])
    }
    ctx.restoreGState()
}

// MARK: - Rounded background

let margin: CGFloat = 64
let backgroundRect = CGRect(
    x: margin,
    y: margin,
    width: CGFloat(size) - margin * 2,
    height: CGFloat(size) - margin * 2
)
let backgroundPath = roundedPath(backgroundRect, 190)

ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: 18),
    blur: 36,
    color: color(0, 0, 0, 0.55)
)
fill(backgroundPath, color(0.03, 0.04, 0.05))
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(backgroundPath)
ctx.clip()

gradientFill(
    backgroundPath,
    colors: [color(0.10, 0.12, 0.15), color(0.015, 0.020, 0.030)],
    start: CGPoint(x: 512, y: 64),
    end: CGPoint(x: 512, y: 960)
)

if let glow = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [
        color(0.10, 0.85, 0.95, 0.30),
        color(0.10, 0.85, 0.95, 0.00),
    ] as CFArray,
    locations: [0, 1]
) {
    ctx.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: 512, y: 470),
        startRadius: 0,
        endCenter: CGPoint(x: 512, y: 470),
        endRadius: 430,
        options: []
    )
}

// MARK: - GPU chip and traces

let chipOuter = roundedPath(CGRect(x: 312, y: 312, width: 400, height: 400), 82)
stroke(chipOuter, color(0.22, 0.91, 1.00, 0.16), 6)

let chipInner = roundedPath(CGRect(x: 352, y: 352, width: 320, height: 320), 58)
stroke(chipInner, color(0.22, 0.91, 1.00, 0.10), 3)

let fanRing = CGPath(
    ellipseIn: CGRect(x: 392, y: 392, width: 240, height: 240),
    transform: nil
)
stroke(fanRing, color(0.22, 0.91, 1.00, 0.12), 4)

let traces: [[CGPoint]] = [
    [CGPoint(x: 312, y: 512), CGPoint(x: 238, y: 512), CGPoint(x: 204, y: 478)],
    [CGPoint(x: 712, y: 512), CGPoint(x: 786, y: 512), CGPoint(x: 820, y: 478)],
    [CGPoint(x: 512, y: 312), CGPoint(x: 512, y: 238), CGPoint(x: 478, y: 204)],
    [CGPoint(x: 512, y: 712), CGPoint(x: 512, y: 786), CGPoint(x: 546, y: 820)],
    [CGPoint(x: 312, y: 312), CGPoint(x: 252, y: 252), CGPoint(x: 220, y: 252)],
    [CGPoint(x: 712, y: 312), CGPoint(x: 772, y: 252), CGPoint(x: 804, y: 252)],
    [CGPoint(x: 312, y: 712), CGPoint(x: 252, y: 772), CGPoint(x: 220, y: 772)],
    [CGPoint(x: 712, y: 712), CGPoint(x: 772, y: 772), CGPoint(x: 804, y: 772)],
]

for trace in traces {
    let path = CGMutablePath()
    path.move(to: trace[0])
    for point in trace.dropFirst() {
        path.addLine(to: point)
    }
    stroke(path, color(0.22, 0.91, 1.00, 0.22), 4)

    for point in trace.dropFirst() {
        let dot = CGPath(
            ellipseIn: CGRect(x: point.x - 8, y: point.y - 8, width: 16, height: 16),
            transform: nil
        )
        fill(dot, color(0.22, 0.91, 1.00, 0.28))
    }
}

// MARK: - Moth wings

func polygon(_ points: [CGPoint]) -> CGPath {
    let path = CGMutablePath()
    path.move(to: points[0])
    for point in points.dropFirst() {
        path.addLine(to: point)
    }
    path.closeSubpath()
    return path
}

let leftUpper = polygon([
    CGPoint(x: 502, y: 402),
    CGPoint(x: 392, y: 318),
    CGPoint(x: 292, y: 330),
    CGPoint(x: 250, y: 430),
    CGPoint(x: 330, y: 520),
    CGPoint(x: 470, y: 505),
])

let rightUpper = polygon([
    CGPoint(x: 522, y: 402),
    CGPoint(x: 632, y: 318),
    CGPoint(x: 732, y: 330),
    CGPoint(x: 774, y: 430),
    CGPoint(x: 694, y: 520),
    CGPoint(x: 554, y: 505),
])

let leftLower = polygon([
    CGPoint(x: 500, y: 520),
    CGPoint(x: 380, y: 560),
    CGPoint(x: 300, y: 650),
    CGPoint(x: 330, y: 720),
    CGPoint(x: 440, y: 680),
    CGPoint(x: 500, y: 600),
])

let rightLower = polygon([
    CGPoint(x: 524, y: 520),
    CGPoint(x: 644, y: 560),
    CGPoint(x: 724, y: 650),
    CGPoint(x: 694, y: 720),
    CGPoint(x: 584, y: 680),
    CGPoint(x: 524, y: 600),
])

let wings = [leftUpper, rightUpper, leftLower, rightLower]

for wing in wings {
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 40, color: color(0.22, 0.91, 1.00, 0.35))
    fill(wing, cyan)
    ctx.restoreGState()
}

for wing in wings {
    gradientFill(
        wing,
        colors: [cyan, teal],
        start: CGPoint(x: 250, y: 300),
        end: CGPoint(x: 780, y: 740)
    )
    stroke(wing, color(0.60, 0.98, 1.00, 0.85), 4)
}

// Inner wing panels add depth without adding small details that vanish at 16 px.
let leftUpperInner = polygon([
    CGPoint(x: 470, y: 430),
    CGPoint(x: 392, y: 366),
    CGPoint(x: 322, y: 374),
    CGPoint(x: 292, y: 430),
    CGPoint(x: 348, y: 488),
    CGPoint(x: 458, y: 480),
])

let rightUpperInner = polygon([
    CGPoint(x: 554, y: 430),
    CGPoint(x: 632, y: 366),
    CGPoint(x: 702, y: 374),
    CGPoint(x: 732, y: 430),
    CGPoint(x: 676, y: 488),
    CGPoint(x: 566, y: 480),
])

let leftLowerInner = polygon([
    CGPoint(x: 470, y: 552),
    CGPoint(x: 404, y: 588),
    CGPoint(x: 360, y: 648),
    CGPoint(x: 388, y: 690),
    CGPoint(x: 446, y: 660),
    CGPoint(x: 480, y: 604),
])

let rightLowerInner = polygon([
    CGPoint(x: 554, y: 552),
    CGPoint(x: 620, y: 588),
    CGPoint(x: 664, y: 648),
    CGPoint(x: 636, y: 690),
    CGPoint(x: 578, y: 660),
    CGPoint(x: 544, y: 604),
])

for panel in [leftUpperInner, rightUpperInner, leftLowerInner, rightLowerInner] {
    fill(panel, darkTeal)
    stroke(panel, color(0.22, 0.91, 1.00, 0.30), 2)
}

let veins: [(CGPoint, CGPoint)] = [
    (CGPoint(x: 500, y: 430), CGPoint(x: 330, y: 350)),
    (CGPoint(x: 500, y: 470), CGPoint(x: 285, y: 430)),
    (CGPoint(x: 500, y: 495), CGPoint(x: 335, y: 505)),
    (CGPoint(x: 524, y: 430), CGPoint(x: 694, y: 350)),
    (CGPoint(x: 524, y: 470), CGPoint(x: 739, y: 430)),
    (CGPoint(x: 524, y: 495), CGPoint(x: 689, y: 505)),
    (CGPoint(x: 500, y: 545), CGPoint(x: 345, y: 635)),
    (CGPoint(x: 500, y: 580), CGPoint(x: 365, y: 695)),
    (CGPoint(x: 524, y: 545), CGPoint(x: 679, y: 635)),
    (CGPoint(x: 524, y: 580), CGPoint(x: 659, y: 695)),
]

for (start, end) in veins {
    let path = CGMutablePath()
    path.move(to: start)
    path.addLine(to: end)
    stroke(path, color(0.75, 1.00, 1.00, 0.22), 3)
}

// MARK: - Body and antennae

let body = roundedPath(CGRect(x: 496, y: 372, width: 32, height: 226), 16)
gradientFill(
    body,
    colors: [whiteCyan, cyan, teal],
    start: CGPoint(x: 512, y: 372),
    end: CGPoint(x: 512, y: 598)
)
stroke(body, color(0.75, 1.00, 1.00, 0.55), 2)

let head = CGPath(
    ellipseIn: CGRect(x: 487, y: 335, width: 50, height: 50),
    transform: nil
)
gradientFill(
    head,
    colors: [whiteCyan, cyan],
    start: CGPoint(x: 512, y: 335),
    end: CGPoint(x: 512, y: 385)
)
stroke(head, color(0.75, 1.00, 1.00, 0.55), 2)

for y in [430.0, 480.0, 530.0] {
    let segment = CGMutablePath()
    segment.move(to: CGPoint(x: 502, y: y))
    segment.addLine(to: CGPoint(x: 522, y: y))
    stroke(segment, color(0.00, 0.22, 0.24, 0.55), 2)
}

let leftAntenna = CGMutablePath()
leftAntenna.move(to: CGPoint(x: 500, y: 344))
leftAntenna.addCurve(
    to: CGPoint(x: 420, y: 252),
    control1: CGPoint(x: 478, y: 310),
    control2: CGPoint(x: 446, y: 276)
)
stroke(leftAntenna, color(0.60, 0.98, 1.00, 0.85), 7)

let rightAntenna = CGMutablePath()
rightAntenna.move(to: CGPoint(x: 524, y: 344))
rightAntenna.addCurve(
    to: CGPoint(x: 604, y: 252),
    control1: CGPoint(x: 546, y: 310),
    control2: CGPoint(x: 578, y: 276)
)
stroke(rightAntenna, color(0.60, 0.98, 1.00, 0.85), 7)

for tip in [CGPoint(x: 420, y: 252), CGPoint(x: 604, y: 252)] {
    let dot = CGPath(
        ellipseIn: CGRect(x: tip.x - 7, y: tip.y - 7, width: 14, height: 14),
        transform: nil
    )
    fill(dot, color(0.75, 1.00, 1.00, 0.90))
}

// Subtle inner border on the rounded square.
stroke(backgroundPath, color(1, 1, 1, 0.08), 3)

ctx.restoreGState()

// MARK: - Write PNG

guard let image = ctx.makeImage() else {
    fatalError("Could not render the icon image")
}

let url = URL(fileURLWithPath: outputPath)
try? FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
)

guard let destination = CGImageDestinationCreateWithURL(
    url as CFURL,
    "public.png" as CFString,
    1,
    nil
) else {
    fatalError("Could not create the PNG destination at \(outputPath)")
}

CGImageDestinationAddImage(destination, image, nil)

guard CGImageDestinationFinalize(destination) else {
    fatalError("Could not write \(outputPath)")
}

print("Wrote \(outputPath) (\(size)x\(size))")
