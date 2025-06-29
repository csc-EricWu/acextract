//
//  Operation.swift
//
//  The MIT License (MIT)
//
//  Copyright (c) 2016 Bartosz Janda
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.

import Foundation

// MARK: - Protocols
protocol Operation {
    func read(catalog: AssetsCatalog) throws -> Void
}

struct CompoundOperation: Operation {
    let operations: [Operation]

    func read(catalog: AssetsCatalog) throws {
        for operation in operations {
            try operation.read(catalog: catalog)
        }
    }
}

// MARK: - Helpers
let escapeSeq = "\u{1b}"
let boldSeq = "[1m"
let resetSeq = "[0m"
let redColorSeq = "[31m"

// MARK: - ExtractOperation
enum ExtractOperationError: Error {
    case OutputPathIsNotDirectory
    case RenditionMissingData
    case CannotSaveImage
    case CannotCreatePDFDocument
}

struct ExtractOperation: Operation {

    // MARK: Properties
    let outputPath: String

    // MARK: Initialization
    init(path: String) {
        outputPath = (path as NSString).expandingTildeInPath
    }

    // MARK: Methods
    func read(catalog: AssetsCatalog) throws {
        // Create output folder if needed
        try checkAndCreateFolder()
        // For every image set and every named image.
        for imageSet in catalog.imageSets {
            for namedImage in imageSet.namedImages {
                // Save image to file with recursive folder structure support
                extractNamedImage(namedImage: namedImage, imageSetName: imageSet.name)
            }
        }
    }

    // MARK: Private methods
    /**
     Checks if output folder exists nad create it if needed.

     - throws: Throws if output path is pointing to file, or it si not possible to create folder.
     */
    private func checkAndCreateFolder() throws {
        // Check if directory exists at given path and it is directory.
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: outputPath, isDirectory: &isDirectory)

        if exists {
            // Path exists, check if it's a directory
            if !isDirectory.boolValue {
                throw ExtractOperationError.OutputPathIsNotDirectory
            }
            // Directory already exists, nothing to do
        } else {
            // Path doesn't exist, create directory
            try FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true, attributes: nil)
        }
    }

    /**
     Extract image to file with recursive folder structure support.

     - parameter namedImage: Named image to save.
     - parameter imageSetName: Name of the image set (may contain path separators).
     */
    private func extractNamedImage(namedImage: CUINamedImage, imageSetName: String) {
        // Create folder structure based on image set name
        let folderPath = createFolderStructure(for: imageSetName)
        // Get the filename without path - extract the last component from acImageName
        let fullImageName = namedImage.acImageName
        let fileName = (fullImageName as NSString).lastPathComponent
        let filePath = (folderPath as NSString).appendingPathComponent(fileName)
        print("Extracting: \(imageSetName)/\(fileName)", terminator: "")
        do {
            try namedImage.acSaveAtPath(filePath: filePath)
            print(" \(escapeSeq+boldSeq)OK\(escapeSeq+resetSeq)")
        } catch {
            print(" \(escapeSeq+boldSeq)\(escapeSeq+redColorSeq)FAILED\(escapeSeq+resetSeq) \(error)")
        }
    }

    /**
     Create folder structure based on image set name.

     - parameter imageSetName: Name of the image set (may contain path separators).
     - returns: Full path to the folder where the image should be saved.
     */
    private func createFolderStructure(for imageSetName: String) -> String {
        // Split the image set name by path separators to create folder structure
        let pathComponents = imageSetName.components(separatedBy: "/")

        if pathComponents.count > 1 {
            // Create nested folder structure
            // For paths like "Shortcuts/SavedMessages/Shortcuts/SavedMessages",
            // we want to create folder "Shortcuts/SavedMessages/Shortcuts/"
            // and save file "SavedMessages@2x.png" in it
            let folderComponents = pathComponents.dropLast() // Remove the last component (filename)
            let folderPath = (outputPath as NSString).appendingPathComponent(folderComponents.joined(separator: "/"))

            // Create the directory structure
            do {
                try FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("DEBUG: Failed to create directory \(folderPath): \(error)")
            }

            return folderPath
        } else {
            // No nested structure, use output path directly
            return outputPath
        }
    }
}

private extension CUINamedImage {
    /**
     Extract given image as PNG or PDF file.

     - parameter filePath: Path where file should be saved.

     - throws: Thorws if there is no image data.
     */
    func acSaveAtPath(filePath: String) throws {
        if self._rendition().pdfDocument() != nil {
            try self.acSavePDF(filePath: filePath)
        } else if self._rendition().unslicedImage() != nil {
            try self.acSaveImage(filePath: filePath)
        } else {
            throw ExtractOperationError.RenditionMissingData
        }
    }

    func acSaveImage(filePath: String) throws {
        let filePathURL = NSURL(fileURLWithPath: filePath)

        // Check if we have image data
        guard let cgImage = self._rendition().unslicedImage()?.takeUnretainedValue() else {
            print("DEBUG: No unsliced image data available for \(filePath)")
            throw ExtractOperationError.CannotSaveImage
        }

        // Check if we can create destination
        guard let cgDestination = CGImageDestinationCreateWithURL(filePathURL, kUTTypePNG, 1, nil) else {
            print("DEBUG: Cannot create image destination for \(filePath)")
            throw ExtractOperationError.CannotSaveImage
        }

        CGImageDestinationAddImage(cgDestination, cgImage, nil)

        if !CGImageDestinationFinalize(cgDestination) {
            print("DEBUG: Cannot finalize image destination for \(filePath)")
            throw ExtractOperationError.CannotSaveImage
        }
    }

    func acSavePDF(filePath: String) throws {
        // Based on:
        // http://stackoverflow.com/questions/3780745/saving-a-pdf-document-to-disk-using-quartz

        guard let cgPDFDocument = self._rendition().pdfDocument()?.takeUnretainedValue() else {
            throw ExtractOperationError.CannotCreatePDFDocument
        }
        // Create the pdf context
        let cgPage = CGPDFDocument.page(cgPDFDocument)
        var cgPageRect = (cgPage as! CGPDFPage).getBoxRect(.mediaBox)
        let mutableData = NSMutableData()

        let cgDataConsumer = CGDataConsumer(data: mutableData)
        let cgPDFContext = CGContext(consumer: cgDataConsumer!, mediaBox: &cgPageRect, nil)
        defer {
            cgPDFContext!.closePDF()
        }

        if cgPDFDocument.numberOfPages > 0 {
            cgPDFContext!.beginPDFPage(nil)
            cgPDFContext!.drawPDFPage(cgPage as! CGPDFPage)
            cgPDFContext!.endPDFPage()
        } else {
            throw ExtractOperationError.CannotCreatePDFDocument
        }

        if !mutableData.write(toFile: filePath, atomically: true) {
            throw ExtractOperationError.CannotCreatePDFDocument
        }
    }
}
