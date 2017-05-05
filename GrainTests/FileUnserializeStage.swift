//
//	GrainTests.swift
//	GrainTests
//
//	Created by Patrick Smith on 17/03/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import XCTest
@testable import Grain


enum FileUnserializeProgression : StageProtocol {
	typealias Result = (text: String, number: Double, arrayOfText: [String])
	
	/// Initial stages
	case open(fileURL: URL)
	/// Intermediate stages
	case read(access: FileAccessStage)
	case unserializeJSON(data: Data)
	case parseJSON(object: Any)
	/// Completed stages
	case success(Result)
	
	// Any errors thrown by the stages
	enum Error : Swift.Error {
		case cannotAccess
		case invalidJSON
		case missingInformation
	}
}

extension FileUnserializeProgression {
	/// The task for each stage
	mutating func updateOrReturnNext() throws -> Deferred<FileUnserializeProgression>? {
		switch self {
		case let .open(fileURL):
			self = .read(
				access: .start(fileURL: fileURL, forgiving: false)
			)
		case let .read(access):
			return access.transform(
				next: FileUnserializeProgression.read,
				result: { (result) -> Deferred<FileUnserializeProgression> in
					let next = Deferred<FileUnserializeProgression>{
						if result.hasAccess {
							return .unserializeJSON(
								data: try Data(contentsOf: result.fileURL, options: .mappedIfSafe)
							)
						}
						else {
							throw Error.cannotAccess
						}
					}
					
					return next + result.stopper!.deferred().ignoringResult()
				}
			)
		case let .unserializeJSON(data):
			self = .parseJSON(
				object: try JSONSerialization.jsonObject(with: data, options: [])
			)
		case let .parseJSON(object):
			guard let dictionary = object as? [String: AnyObject] else {
				throw Error.invalidJSON
			}
			
			guard let
				text = dictionary["text"] as? String,
				let number = dictionary["number"] as? Double,
				let arrayOfText = dictionary["arrayOfText"] as? [String]
				else { throw Error.missingInformation }
			
			self = .success(
				text: text,
				number: number,
				arrayOfText: arrayOfText
			)
		case .success:
			break
		}
		return nil
	}
	
	// The associated value if this is a completion case
	var result: Result? {
		guard case let .success(result) = self else { return nil }
		return result
	}
}


class GrainTests : XCTestCase {
	override func setUp() {
		super.setUp()
		// Put setup code here. This method is called before the invocation of each test method in the class.
	}
	
	override func tearDown() {
		// Put teardown code here. This method is called after the invocation of each test method in the class.
		super.tearDown()
	}
	
	var bundle: Bundle { return Bundle(for: type(of: self)) }
	
	func testFileOpen() {
		print("BUNDLE \(bundle.bundleURL)")
		
		guard let fileURL = bundle.url(forResource: "example", withExtension: "json") else {
			XCTFail("Could not find file `example.json`")
			return
		}
		
		let expectation = self.expectation(description: "FileUnserializeStage executed")
		
		FileUnserializeProgression.open(fileURL: fileURL).deferred().perform{ useResult in
			do {
				let (text, number, arrayOfText) = try useResult()
				XCTAssertEqual(text, "abc")
				XCTAssertEqual(number, 5)
				XCTAssertEqual(arrayOfText.count, 2)
				XCTAssertEqual(arrayOfText[1], "ghi")
			}
			catch {
				XCTFail("Error \(error)")
			}
			
			expectation.fulfill()
		}
		
		waitForExpectations(timeout: 3, handler: nil)
	}
}
