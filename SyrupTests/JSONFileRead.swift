//
//	JSONFileReadProgression.swift
//	GrainTests
//
//	Created by Patrick Smith on 17/03/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import XCTest
@testable import Syrup


enum JSONFileReadProgression<Result: JSONDecodable> : Progression {
	/// Initial steps
	case open(fileURL: URL)
	/// Intermediate steps
	case read(access: FileAccessProgression)
	case unserializeJSONData(Data)
	case parseJSON(Any)
	/// Completed steps
	case success(Example)

	/// The task for each stage
	mutating func updateOrDeferNext() throws -> Deferred<JSONFileReadProgression>? {
		switch self {
		case let .open(fileURL):
			self = .read(
				access: FileAccessProgression(fileURL: fileURL)
			)
		case let .read(access):
			return compose(access,
				mapNext: JSONFileReadProgression.read,
				flatMapResult: { stopAccessing in
					return Deferred{ JSONFileReadProgression.unserializeJSONData(
						try Data(contentsOf: stopAccessing.fileURL, options: .mappedIfSafe)
					) } & (stopAccessing / .utility).ignoringResult()
				}
			)
		case let .unserializeJSONData(data):
			self = .parseJSON(
				try JSONSerialization.jsonObject(with: data, options: [])
			)
		case let .parseJSON(object):
			self = .success(
				try Example(json: object)
			)
		case .success:
			break
		}
		return nil
	}
	
	// The associated value if this is a completion case
	var result: Example? {
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
		
		JSONFileReadProgression<Example>.open(fileURL: fileURL) / .utility >>= { useResult in
			do {
				let example = try useResult()
				XCTAssertEqual(example.text, "abc")
				XCTAssertEqual(example.number, 5)
				XCTAssertEqual(example.arrayOfText.count, 2)
				XCTAssertEqual(example.arrayOfText[1], "ghi")
			}
			catch {
				XCTFail("Error \(error)")
			}
			
			expectation.fulfill()
		}
		
		waitForExpectations(timeout: 3, handler: nil)
	}
}
