//
//  AcextractTests.swift
//  AcextractTests
//
//  Created by Bartosz Janda on 12.06.2016.
//  Copyright © 2016 Bartosz Janda. All rights reserved.
//

import XCTest

class FakeOperation: Operation {
    var executed = false

    func read(catalog: AssetsCatalog) throws {
        executed = true
    }
}

class AssetsCatalogTests: XCTestCase {

    // MARK: Tests
    /**
     Success
     */
    func testCreateAssetsCatalog01() {
        do {
            _ = try AssetsCatalog(path: Asset.assets.path)
        } catch {
            XCTFail("Cannot create AssetsCatalog object")
        }
    }

    /**
     File not found.
     */
    func testCreateAssetsCatalog02() {
        do {
            _ = try AssetsCatalog(path: "Fake path")
            XCTFail("AssetsCatalog should not be created")
        } catch AssetsCatalogError.FileDoesntExists {

        } catch {
            XCTFail("Unknown exception \(error)")
        }
    }

    /**
     Incorrect file.
     */
    func testCreateAssetsCatalog03() {
        guard let path = Asset.bundle.pathForResource("data/fake_assets", ofType: nil) else {
            XCTFail("Cannot find fake asset")
            return
        }

        do {
            _ = try AssetsCatalog(path: path)
            XCTFail("AssetsCatalog should not be created")
        } catch AssetsCatalogError.CannotOpenAssetsCatalog {

        } catch {
            XCTFail("Unknown exception \(error)")
        }
    }

    /**
     Test one operation.
     */
    func testOperation01() {
        do {
            let operation = FakeOperation()
            try assetsContainer.iOS.performOperation(operation)
            XCTAssertTrue(operation.executed)
        } catch {
            XCTFail("Unknown exception \(error)")
        }
    }

    /**
     Test two operations.
     */
    func testOperation02() {
        do {
            let operation1 = FakeOperation()
            let operation2 = FakeOperation()
            try assetsContainer.iOS.performOperations([operation1, operation2])
            XCTAssertTrue(operation1.executed)
            XCTAssertTrue(operation2.executed)
        } catch {
            XCTFail("Unknown exception \(error)")
        }
    }

    func testAllImageNamesContainsNestedPaths() {
        // Test with iOS assets catalog
        let catalog = assetsContainer.iOS

        // Get all image names
        let allNames = catalog.catalog.allImageNames()

        // Print all names to see the structure
        print("All image names from iOS catalog:")
        for name in allNames {
            print("  \(name)")
        }

        // Check if any names contain path separators (indicating nested structure)
        let namesWithPaths = allNames.filter { $0.contains("/") }

        print("Names with path separators:")
        for name in namesWithPaths {
            print("  \(name)")
        }

        // Verify that we have some nested paths
        XCTAssertGreaterThan(namesWithPaths.count, 0, "Should have some nested image paths")

        // Check specific nested paths that we know exist
        let expectedNestedPaths = [
            "devices/mix/d_iphone_ipad_mac",
            "devices/mix/d_iphone_ipad_mac_watch"
        ]

        for expectedPath in expectedNestedPaths {
            XCTAssertTrue(allNames.contains(expectedPath), "Should contain nested path: \(expectedPath)")
        }
    }

    func testImageSetWithNestedPath() {
        let catalog = assetsContainer.iOS

        // Test getting an image set with a nested path
        let nestedImageSet = catalog.imageSet(withName: "devices/mix/d_iphone_ipad_mac")

        XCTAssertEqual(nestedImageSet.name, "devices/mix/d_iphone_ipad_mac")
        XCTAssertGreaterThan(nestedImageSet.namedImages.count, 0, "Should have images in nested image set")

        // Print the images in this nested set
        print("Images in nested set 'devices/mix/d_iphone_ipad_mac':")
        for image in nestedImageSet.namedImages {
            print("  \(image.acImageName)")
        }
    }
}
