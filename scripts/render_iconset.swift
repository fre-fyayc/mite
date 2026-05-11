#!/usr/bin/env swift

import Foundation
import AppKit
import SwiftUI

struct HighContrastTimeTrackerIcon: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(0.3),
                        Color.black.opacity(0.8)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(Color.blue, lineWidth: 3)
                )
                .shadow(color: Color.black.opacity(0.5), radius: 12, x: 0, y: 8)

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.5), lineWidth: 6)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: 0.75)
                        .stroke(
                            LinearGradient(colors: [.cyan, .blue], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 70, height: 70)
                        .rotationEffect(.degrees(-90))

                    Circle()
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 50, height: 50)

                    Capsule()
                        .fill(Color.white)
                        .frame(width: 3, height: 20)
                        .offset(y: -10)

                    Capsule()
                        .fill(Color.white)
                        .frame(width: 3, height: 14)
                        .offset(y: -7)
                        .rotationEffect(.degrees(110), anchor: .bottom)

                    Circle()
                        .fill(Color.cyan)
                        .frame(width: 5, height: 5)
                }

                HStack(spacing: 15) {
                    Image(systemName: "backward.fill")
                    Image(systemName: "play.fill")
                        .font(.title3.bold())
                    Image(systemName: "forward.fill")
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(Capsule().stroke(Color.white.opacity(0.4), lineWidth: 1))
                )
            }
        }
        .frame(width: 128, height: 128)
        .padding()
    }
}

func pngData(from image: NSImage) -> Data? {
    guard let tiffData = image.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiffData) else {
        return nil
    }
    return rep.representation(using: .png, properties: [:])
}

@MainActor
func renderIconSet(outputFolder: URL) throws {
    let fm = FileManager.default
    try? fm.removeItem(at: outputFolder)
    try fm.createDirectory(at: outputFolder, withIntermediateDirectories: true)

    let entries: [(name: String, points: CGFloat, scale: CGFloat)] = [
        ("icon_16x16.png", 16, 1),
        ("icon_16x16@2x.png", 16, 2),
        ("icon_32x32.png", 32, 1),
        ("icon_32x32@2x.png", 32, 2),
        ("icon_128x128.png", 128, 1),
        ("icon_128x128@2x.png", 128, 2),
        ("icon_256x256.png", 256, 1),
        ("icon_256x256@2x.png", 256, 2),
        ("icon_512x512.png", 512, 1),
        ("icon_512x512@2x.png", 512, 2)
    ]

    for entry in entries {
        let pixelSize = entry.points * entry.scale
        let rendered = HighContrastTimeTrackerIcon()
            .frame(width: entry.points, height: entry.points)

        let renderer = ImageRenderer(content: rendered)
        renderer.scale = entry.scale
        renderer.proposedSize = ProposedViewSize(width: entry.points, height: entry.points)

        guard let image = renderer.nsImage, let data = pngData(from: image) else {
            throw NSError(domain: "render_iconset", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to render \(entry.name)"
            ])
        }

        let fileURL = outputFolder.appendingPathComponent(entry.name)
        try data.write(to: fileURL, options: .atomic)
        print("Rendered \(entry.name) (\(Int(pixelSize))px)")
    }
}

let args = CommandLine.arguments
guard args.count == 2 else {
    fputs("Usage: render_iconset.swift <output_iconset_folder>\n", stderr)
    exit(1)
}

let outputFolder = URL(fileURLWithPath: args[1], isDirectory: true)
try await renderIconSet(outputFolder: outputFolder)
