//
//  CorrectnessTests.swift
//  acextract
//
//  Created by Bartosz Janda on 19.06.2016.
//  Copyright © 2016 Bartosz Janda. All rights reserved.
//

import XCTest

// Check correctness by printing verbose information
class CorrectnessTests: XCTestCase {
    // MARK: Properties
    let printOperation = PrintInformationOperation(verbose: .VeryVeryVerbose)

    // MARK: Test correctness
    func testIOSCorrectness() {
        printOperation.read(catalog: assetsContainer.iOS)
    }

    func testIPadCorrectness() {
        printOperation.read(catalog: assetsContainer.iPad)
    }

    func testIPhoneCorrectness() {
        printOperation.read(catalog: assetsContainer.iPhone)
    }

    func testMacCorrectness() {
        printOperation.read(catalog: assetsContainer.macOS)
    }

    func testTVCorrectness() {
        printOperation.read(catalog: assetsContainer.tvOS)
    }

    func testWatchCorrectness() {
        printOperation.read(catalog: assetsContainer.watchOS)
    }

    func testPrintInformationName() {
        PrintInformationOperation(verbose: .Name).read(catalog: assetsContainer.iOS)
    }

    func testPrintInformationVerbose() {
        PrintInformationOperation(verbose: .Verbose).read(catalog: assetsContainer.iOS)
    }

    func testPrintInformationVeryVerbose() {
        PrintInformationOperation(verbose: .VeryVerbose).read(catalog: assetsContainer.iOS)
    }
}
