//
//  FileBookmarkingStage.swift
//  Grain
//
//  Created by Patrick Smith on 24/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import XCTest
@testable import Grain


private let defaultResourceKeys = Array<String>()

private func createBookmarkDataForFileURL(fileURL: NSURL) throws -> NSData {
	if fileURL.startAccessingSecurityScopedResource() {
		defer {
			fileURL.stopAccessingSecurityScopedResource()
		}
	}
	
	return try fileURL.bookmarkDataWithOptions(.WithSecurityScope, includingResourceValuesForKeys: defaultResourceKeys, relativeToURL:nil)
}


enum FileBookmarkingStage: StageProtocol {
	typealias Result = (fileURL: NSURL, bookmarkData: NSData, wasStale: Bool)
	
	/// Initial stages
	case fileURL(fileURL: NSURL)
	case bookmark(bookmarkData: NSData)
	/// Completed stages
	case resolved(Result)
}

extension FileBookmarkingStage {
	/// The task for each stage
	func next() -> Deferred<FileBookmarkingStage> {
		switch self {
		case let .fileURL(fileURL):
			return Deferred{
				.resolved((
					fileURL: fileURL,
					bookmarkData: try createBookmarkDataForFileURL(fileURL),
					wasStale: false
				))
			}
		case let .bookmark(bookmarkData):
			return Deferred{
				var stale: ObjCBool = false
				// Resolve the bookmark data.
				let fileURL = try NSURL(byResolvingBookmarkData: bookmarkData, options: .WithSecurityScope, relativeToURL: nil, bookmarkDataIsStale: &stale)
				
				var bookmarkData = bookmarkData
				if stale {
					bookmarkData = try createBookmarkDataForFileURL(fileURL)
				}

				return .resolved((
					fileURL: fileURL,
					bookmarkData: bookmarkData,
					wasStale: Bool(stale)
				))
			}
		case .resolved: completedStage(self)
		}
	}
	
	var result: Result? {
		guard case let .resolved(result) = self else { return nil }
		return result
	}
}


class FileBookmarkingTests: XCTestCase {
	var bundle: NSBundle { return NSBundle(forClass: self.dynamicType) }
	
	func testFileAccess() {
		guard let fileURL = bundle.URLForResource("example", withExtension: "json") else {
			return
		}
		
		let expectation = expectationWithDescription("File accessed")
		
		let accessDeferred = FileStartAccessingStage.start(fileURL: fileURL) * GCDService.utility
		
		let bookmarkDeferred = accessDeferred.flatMap{ useResult -> Deferred<FileBookmarkingStage.Result> in
			let (fileURL, stopAccessing) = try useResult()
			return FileBookmarkingStage.fileURL(fileURL: fileURL) * GCDService.background
		}
		
		(bookmarkDeferred + GCDService.mainQueue).perform { useResult in
			do {
				let result = try useResult()
				XCTAssertEqual(result.fileURL, fileURL)
				XCTAssert(result.bookmarkData.length > 0)
				XCTAssertEqual(result.wasStale, false)
			}
			catch {
				XCTFail("Error \(error)")
			}
			
			expectation.fulfill()
		}
		
		waitForExpectationsWithTimeout(3, handler: nil)
	}
}

