//
//  FileAccessingStage.swift
//  Grain
//
//  Created by Patrick Smith on 24/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import XCTest
@testable import Grain


enum FileStartAccessingStage : StageProtocol {
	typealias Result = (fileURL: NSURL, stopper: FileStopAccessingStage)
	
	/// Initial stages
	case start(fileURL: NSURL)
	
	case started(Result)
}

enum FileStopAccessingStage : StageProtocol {
	typealias Result = NSURL
	
	/// Initial stages
	case stop(fileURL: NSURL, accessSucceeded: Bool)
	
	case stopped(fileURL: NSURL)
}

extension FileStartAccessingStage {
	/// The task for each stage
	func next() -> Deferred<FileStartAccessingStage> {
		switch self {
		case let .start(fileURL):
			return Deferred{
				let accessSucceeded = fileURL.startAccessingSecurityScopedResource()
				
				return .started(
					fileURL: fileURL,
					stopper: FileStopAccessingStage.stop(
						fileURL: fileURL,
						accessSucceeded: accessSucceeded
					)
				)
			}
		case .started:
			completedStage(self)
		}
	}
	
	var result: Result? {
		guard case let .started(result) = self else { return nil }
		return result
	}
}

extension FileStopAccessingStage {
	/// The task for each stage
	func next() -> Deferred<FileStopAccessingStage> {
		switch self {
		case let .stop(fileURL, accessSucceeded):
			return Deferred{
				if accessSucceeded {
					fileURL.stopAccessingSecurityScopedResource()
				}
				
				return .stopped(
					fileURL: fileURL
				)
			}
		case .stopped:
			completedStage(self)
		}
	}
	
	var result: NSURL? {
		guard case let .stopped(fileURL) = self else { return nil }
		return fileURL
	}
}


class FileAccessingTests: XCTestCase {
	var bundle: NSBundle { return NSBundle(forClass: self.dynamicType) }
	
	func testFileAccess() {
		guard let fileURL = bundle.URLForResource("example", withExtension: "json") else {
			return
		}
		
		let expectation = expectationWithDescription("File accessed")
		
		FileStartAccessingStage.start(fileURL: fileURL).execute { useResult in
			do {
				let result = try useResult()
				XCTAssertEqual(result.fileURL, fileURL)
			}
			catch {
				XCTFail("Error \(error)")
			}
			
			expectation.fulfill()
		}
		
		waitForExpectationsWithTimeout(3, handler: nil)
	}
}


