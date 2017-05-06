//
//	HTTPRequestStage.swift
//	Grain
//
//	Created by Patrick Smith on 17/03/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import XCTest
@testable import Grain


enum HTTPRequestProgression : Progression {
	typealias Result = (response: HTTPURLResponse, body: Data?)
	
	case get(url: URL)
	case post(url: URL, body: Data)
	
	case success(Result)
	
	mutating func updateOrDeferNext() -> Deferred<HTTPRequestProgression>? {
		switch self {
		case let .get(url):
			return Deferred.future{ resolve in
				let session = URLSession.shared
				let task = session.dataTask(with: url, completionHandler: { data, response, error in
					if let error = error {
						resolve{ throw error }
					}
					else {
						resolve{ .success((response: response as! HTTPURLResponse, body: data)) }
					}
				}) 
				task.resume()
			}
		case let .post(url, body):
			return Deferred.future{ resolve in
				let session = URLSession.shared
				var request = URLRequest(url: url)
				request.httpBody = body
				let task = session.dataTask(with: request, completionHandler: { (data, response, error) in
					if let error = error {
						resolve{ throw error }
					}
					else {
						resolve{ .success((response: response as! HTTPURLResponse, body: data)) }
					}
				}) 
				task.resume()
			}
		case .success:
			return nil
		}
	}
	
	var result: Result? {
		guard case let .success(result) = self else { return nil }
		return result
	}
}

enum FileUploadProgression : Progression {
	typealias Result = Any?
	
	case openFile(fileStage: JSONFileReadProgression<Example>, destinationURL: URL)
	case uploadRequest(request: HTTPRequestProgression)
	case parseUploadResponse(data: Data?)
	case success(Result)
	
	enum ErrorKind : Error {
		case uploadFailed(statusCode: Int, body: Data?)
		case uploadResponseParsing(body: Data?)
	}
	
	mutating func updateOrDeferNext() throws -> Deferred<FileUploadProgression>? {
		switch self {
		case let .openFile(fileProgression, destinationURL):
			return compose(fileProgression,
				mapNext: { .openFile(fileStage: $0, destinationURL: destinationURL) },
				mapResult: { result in
					.uploadRequest(
						request: .post(
							url: destinationURL,
							body: try JSONSerialization.data(withJSONObject: [ "number": result.number ], options: [])
						)
					)
				}
			)
		case let .uploadRequest(stage):
			return compose(stage,
				mapNext: { .uploadRequest(request: $0) },
				mapResult: { (response, body) in
					switch response.statusCode {
					case 200:
						return .parseUploadResponse(data: body)
					default:
						throw ErrorKind.uploadFailed(statusCode: response.statusCode, body: body)
					}
				}
			)
		case let .parseUploadResponse(data):
			self = .success(
				try data.map{ try JSONSerialization.jsonObject(with: $0, options: []) }
			)
		default:
			break
		}
		return nil
	}
	
	var result: Result? {
		guard case let .success(result) = self else { return nil }
		return result
	}
}
