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
	typealias Result = (fileURL: NSURL, hasAccess: Bool, stopper: FileAccessStage?)
	
	/// Initial stages
	case start(fileURL: NSURL, forgiving: Bool)
	case stop(fileURL: NSURL)
	
	case complete(Result)
	
	enum Error : ErrorType {
		case cannotAccess(fileURL: NSURL)
	}
}

extension FileAccessStage {
	/// The task for each stage
	func next() -> Deferred<FileAccessStage> {
		switch self {
		case let .start(fileURL, forgiving):
			return Deferred{
				let accessSucceeded = fileURL.startAccessingSecurityScopedResource()
				
				if !accessSucceeded && !forgiving {
					throw Error.cannotAccess(fileURL: fileURL)
				}
				
				return FileAccessStage.complete((
					fileURL: fileURL,
					hasAccess: accessSucceeded,
					stopper: accessSucceeded ? FileAccessStage.stop(
						fileURL: fileURL
					) : nil
				))
			}
		case let .stop(fileURL):
			return Deferred{
				fileURL.stopAccessingSecurityScopedResource()
				
				return FileAccessStage.complete((
					fileURL: fileURL,
					hasAccess: false,
					stopper: nil
				))
			}
		case .complete:
			completedStage(self)
		}
	}
	
	var result: Result? {
		guard case let .complete(result) = self else { return nil }
		return result
	}
}


class FileAccessingTests : XCTestCase {
	var bundle: NSBundle { return NSBundle(forClass: self.dynamicType) }
	
	func testFileAccess() {
		guard let fileURL = bundle.URLForResource("example", withExtension: "json") else {
			return
		}
		
		let expectation = expectationWithDescription("File accessed")
		
		FileAccessStage.start(fileURL: fileURL, forgiving: true).execute { useResult in
			do {
				let result = try useResult()
				XCTAssertEqual(result.fileURL, fileURL)
				
				XCTAssertNotNil(result.stopper)
				
				result.stopper!.execute{ _ in
					expectation.fulfill()
				}
			}
			catch {
				XCTFail("Error \(error)")
			}
		}
		
		waitForExpectationsWithTimeout(3, handler: nil)
	}
}


