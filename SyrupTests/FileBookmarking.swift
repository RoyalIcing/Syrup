//
//	FileBookmarkingStage.swift
//	Grain
//
//	Created by Patrick Smith on 24/03/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import XCTest
@testable import Syrup


private let defaultResourceKeys = Array<URLResourceKey>()

#if os(OSX)
let bookmarkCreationOptions: NSURL.BookmarkCreationOptions = .withSecurityScope
let bookmarkResolutionOptions: NSURL.BookmarkResolutionOptions = .withSecurityScope
#else
let bookmarkCreationOptions: NSURL.BookmarkCreationOptions = []
let bookmarkResolutionOptions: NSURL.BookmarkResolutionOptions = []
#endif

private func createBookmarkDataForFileURL(_ fileURL: URL) throws -> Data {
	return try (fileURL as NSURL).bookmarkData(options: bookmarkCreationOptions, includingResourceValuesForKeys: defaultResourceKeys, relativeTo:nil)
}


enum FileBookmarkingProgression: Progression {
	typealias Result = (fileURL: URL, bookmarkData: Data, wasStale: Bool)
	
	/// Initial stages
	case fileURL(fileURL: URL)
	case bookmark(bookmarkData: Data)
	/// Completed stages
	case resolved(Result)

	/// Go to each step
	mutating func updateOrDeferNext() throws -> Deferred<FileBookmarkingProgression>? {
		switch self {
		case let .fileURL(fileURL):
			self = .resolved((
				fileURL: fileURL,
				bookmarkData: try createBookmarkDataForFileURL(fileURL),
				wasStale: false
			))
		case let .bookmark(bookmarkData):
			var stale: ObjCBool = false
			// Resolve the bookmark data.
			let fileURL = try (NSURL(resolvingBookmarkData: bookmarkData, options: bookmarkResolutionOptions, relativeTo: nil, bookmarkDataIsStale: &stale) as URL)
			
			var bookmarkData = bookmarkData
			if stale.boolValue {
				bookmarkData = try createBookmarkDataForFileURL(fileURL)
			}

			self = .resolved((
				fileURL: fileURL,
				bookmarkData: bookmarkData,
				wasStale: stale.boolValue
			))
		case .resolved: break
		}
		return nil
	}
	
	var result: Result? {
		guard case let .resolved(result) = self else { return nil }
		return result
	}
}


class FileBookmarkingTests: XCTestCase {
	var bundle: Bundle { return Bundle(for: type(of: self)) }
	
	func testFileAccess() {
		guard let fileURL = bundle.url(forResource: "example", withExtension: "json") else {
			return
		}
		
		let expectation = self.expectation(description: "File accessed")
		
		let accessDeferred = FileAccessProgression(fileURL: fileURL) / .utility
		
		let bookmarkDeferred = accessDeferred >>= { useResult -> Deferred<FileBookmarkingProgression.Result> in
			let stopAccessing = try useResult()
			return (
				FileBookmarkingProgression.fileURL(fileURL: fileURL) / .background
			) & (stopAccessing / .utility).ignoringResult()
		}

//		bookmarkDeferred + .main >>= { useResult in
		bookmarkDeferred >>= .main + { useResult in
			do {
				let result = try useResult()
				XCTAssertEqual(result.fileURL, fileURL)
				XCTAssert(result.bookmarkData.count > 0)
				XCTAssertEqual(result.wasStale, false)
				
				expectation.fulfill()
			}
			catch {
				XCTFail("Error \(error)")
			}
		}
		
		waitForExpectations(timeout: 3, handler: nil)
	}
}

