#!/usr/bin/env swift

import AppKit
import SwiftUI

struct AppIconView: View {
    let size: CGFloat

    private let backgroundColor = Color(red: 0.071, green: 0.235, blue: 0.400)

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(backgroundColor)

            Image(systemName: "sharedwithyou")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: size * 0.54, height: size * 0.54)
        }
        .frame(width: size, height: size)
    }
}

struct MenuBarIconView: View {
    let size: CGFloat

    var body: some View {
        Image(systemName: "sharedwithyou")
            .resizable()
            .scaledToFit()
            .foregroundStyle(.black)
            .frame(width: size, height: size)
            .frame(width: size, height: size)
    }
}

enum IconGenerationError: Error {
    case missingImage(String)
    case failedToEncode(String)
}

@MainActor
func renderPNG<Content: View>(
    view: Content,
    width: Int,
    height: Int,
    outputURL: URL,
    opaque: Bool
) throws {
    let renderer = ImageRenderer(content: view)
    renderer.scale = 1
    renderer.proposedSize = ProposedViewSize(width: CGFloat(width), height: CGFloat(height))
    renderer.isOpaque = opaque

    guard let image = renderer.nsImage else {
        throw IconGenerationError.missingImage(outputURL.lastPathComponent)
    }

    guard
        let tiff = image.tiffRepresentation,
        let bitmap = NSBitmapImageRep(data: tiff),
        let data = bitmap.representation(using: .png, properties: [:])
    else {
        throw IconGenerationError.failedToEncode(outputURL.lastPathComponent)
    }

    try data.write(to: outputURL)
}

try await MainActor.run {
    let fileManager = FileManager.default
    let workingDirectory = URL(fileURLWithPath: fileManager.currentDirectoryPath)

    let appIconSetURL = workingDirectory
        .appending(path: "CodexAccountHub")
        .appending(path: "Assets.xcassets")
        .appending(path: "AppIcon.appiconset")

    let menuBarIconSetURL = workingDirectory
        .appending(path: "CodexAccountHub")
        .appending(path: "Assets.xcassets")
        .appending(path: "MenuBarIcon.imageset")

    let appIconSizes: [(Int, String)] = [
        (16, "appicon-16.png"),
        (32, "appicon-32.png"),
        (64, "appicon-64.png"),
        (128, "appicon-128.png"),
        (256, "appicon-256.png"),
        (512, "appicon-512.png"),
        (1024, "appicon-1024.png"),
    ]

    for (size, filename) in appIconSizes {
        let outputURL = appIconSetURL.appending(path: filename)
        try renderPNG(
            view: AppIconView(size: CGFloat(size)),
            width: size,
            height: size,
            outputURL: outputURL,
            opaque: true
        )
    }

    let menuBarSizes: [(Int, String)] = [
        (18, "menubar-icon.png"),
        (36, "menubar-icon@2x.png"),
    ]

    for (size, filename) in menuBarSizes {
        let outputURL = menuBarIconSetURL.appending(path: filename)
        try renderPNG(
            view: MenuBarIconView(size: CGFloat(size)),
            width: size,
            height: size,
            outputURL: outputURL,
            opaque: false
        )
    }
}
