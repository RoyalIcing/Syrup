//
//	FileAccessingStage.swift
//	Grain
//
//	Created by Patrick Smith on 24/03/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import XCTest
@testable import Grain


indirect enum FileAccessStage : StageProtocol {
	typealias Result = (fileURL: URL, hasAccess: Bool, stopper: FileAccessStage?)
	
	/// Initial stages
	case start(fileURL: URL, forgiving: Bool)
	case stop(fileURL: URL)
	
	case complete(Result)
	
	enum ErrorKind : Error {
		case cannotAccess(fileURL: URL)
	}
}

extension FileAccessStage {
	/// The task for each stage
	mutating func updateOrReturnNext() throws -> Deferred<FileAccessStage>? {
		switch self {
		case let .start(fileURL, forgiving):
			let accessSucceeded = fileURL.startAccessingSecurityScopedResource()
			
			if !accessSucceeded && !forgiving {
				throw ErrorKind.cannotAccess(fileURL: fileURL)
			}
			
			self = .complete((
				fileURL: fileURL,
				hasAccess: accessSucceeded,
				stopper: accessSucceeded ? .stop(fileURL: fileURL) : nil
			))
		case let .stop(fileURL):
			fileURL.stopAccessingSecurityScopedResource()
			
			self = .complete((
				fileURL: fileURL,
				hasAccess: false,
				stopper: nil
			))
		default:
			break
		}
		return nil
	}
	
	var result: Result? {
		guard case let .complete(result) = self else { return nil }
		return result
	}
}


class FileAccessingTests : XCTestCase {
	var bundle: Bundle { return Bundle(for: type(of: self)) }
	
	func testFileAccess() {
		guard let fileURL = bundle.url(forResource: "example", withExtension: "json") else {
			return
		}
		
		let expectation = self.expectation(description: "File accessed")
		
		FileAccessStage.start(fileURL: fileURL, forgiving: true) / .utility >>= { useResult in
			do {
				let result = try useResult()
				XCTAssertEqual(result.fileURL, fileURL)
				
				XCTAssertNotNil(result.stopper)
				
				result.stopper! / .utility >>= { _ in
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


