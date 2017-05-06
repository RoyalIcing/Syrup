//
//	FileAccessingStage.swift
//	Grain
//
//	Created by Patrick Smith on 24/03/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import XCTest
@testable import Grain


struct FileAccessProgression : Progression {
	let fileURL: URL
	private var startAccess: Bool
	private var done: Bool
	
	init(fileURL: URL) {
		self.fileURL = fileURL
		startAccess = true
		done = false
	}
	
	enum ErrorKind : Error {
		case cannotAccess(fileURL: URL)
	}
	
	mutating func updateOrDeferNext() throws -> Deferred<FileAccessProgression>? {
		if startAccess {
			let accessSucceeded = fileURL.startAccessingSecurityScopedResource()
			if !accessSucceeded {
				throw ErrorKind.cannotAccess(fileURL: fileURL)
			}
		}
		else {
			fileURL.stopAccessingSecurityScopedResource()
		}
		
		done = true
		
		// Mutated, so no need to return future
		return nil
	}
	
	typealias Result = FileAccessProgression
	var result: FileAccessProgression? {
		guard done else { return nil }
		
		var copy = self
		if startAccess {
			copy.startAccess = false
			copy.done = false
		}
		return copy
	}
}


class FileAccessingTests : XCTestCase {
	var bundle: Bundle { return Bundle(for: type(of: self)) }
	
	func testFileAccess() {
		guard let fileURL = bundle.url(forResource: "example", withExtension: "json") else {
			return
		}
		
		let expectation = self.expectation(description: "File accessed")
		
		FileAccessProgression(fileURL: fileURL) / .utility >>= { useResult in
			do {
				let result = try useResult()
				XCTAssertEqual(result.fileURL, fileURL)
				
				result / .utility >>= { _ in
					expectation.fulfill()
				}
			}
			catch {
				XCTFail("Error \(error)")
			}
		}
		
		waitForExpectations(timeout: 3, handler: nil)
	}
}


