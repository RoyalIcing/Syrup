//
//  HTTPRequestStage.swift
//  Grain
//
//  Created by Patrick Smith on 17/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import XCTest
@testable import Grain


enum HTTPRequestStage : StageProtocol {
	typealias Result = (response: NSHTTPURLResponse, body: NSData?)
	
	case get(url: NSURL)
	case post(url: NSURL, body: NSData)
	
	case success(Result)
	
	func next() -> Deferred<HTTPRequestStage> {
		return Deferred.future{ resolve in
			switch self {
			case let .get(url):
				let session = NSURLSession.sharedSession()
				let task = session.dataTaskWithURL(url) { data, response, error in
					if let error = error {
						resolve{ throw error }
					}
					else {
						resolve{ .success((response: response as! NSHTTPURLResponse, body: data)) }
					}
				}
				task.resume()
			case let .post(url, body):
				let session = NSURLSession.sharedSession()
				let request = NSMutableURLRequest(URL: url)
				request.HTTPBody = body
				let task = session.dataTaskWithRequest(request) { (data, response, error) in
					if let error = error {
						resolve { throw error }
					}
					else {
						resolve { .success((response: response as! NSHTTPURLResponse, body: data)) }
					}
				}
				task.resume()
			case .success:
				completedStage(self)
			}
		}
	}
	
	var result: Result? {
		guard case let .success(result) = self else { return nil }
		return result
	}
}

enum FileUploadStage : StageProtocol {
	typealias Result = ()
	
	case openFile(fileOpenStage: FileOpenStage, destinationURL: NSURL)
	case uploadRequest(HTTPRequestStage)
	case success
	
	enum Error: ErrorType {
		case uploadFailed(statusCode: Int, body: NSData?)
	}
	
	func next() -> Deferred<FileUploadStage> {
		switch self {
		case let .openFile(stage, destinationURL):
			return stage.compose(
				transformNext: {
					.openFile(fileOpenStage: $0, destinationURL: destinationURL)
				},
				transformResult: { result in
					return .uploadRequest(.post(
						url: destinationURL,
						body: try NSJSONSerialization.dataWithJSONObject([ "number": result.number ], options: [])
					))
				}
			)
		case let .uploadRequest(stage):
			return stage.compose(
				transformNext: FileUploadStage.uploadRequest,
				transformResult: { result in
					let (response, body) = result
					switch response.statusCode {
					case 200:
						return .success
					default:
						throw Error.uploadFailed(statusCode: response.statusCode, body: body)
					}
				}
			)
		case .success:
			completedStage(self)
		}
	}
	
	var result: Result? {
		// CRASHES: guard case let .success(completion) = self else { return nil }
		guard case .success = self else { return nil }
		return ()
	}
}
