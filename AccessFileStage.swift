//
//  AccessFileStage.swift
//  Grain
//
//  Created by Patrick Smith on 24/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

//
//  AccessFileStage.swift
//  Grain
//
//  Created by Patrick Smith on 24/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import XCTest
@testable import Grain


private let coreResourceValueKeys = Array<String>()

private func createBookmarkDataForFileURL(fileURL: NSURL) throws -> NSData {
	if fileURL.startAccessingSecurityScopedResource() {
		defer {
			fileURL.stopAccessingSecurityScopedResource()
		}
	}
	
	return try fileURL.bookmarkDataWithOptions(.WithSecurityScope, includingResourceValuesForKeys: coreResourceValueKeys, relativeToURL:nil)
}

private func resolveFileURLFromBookmarkData(bookmarkData: NSData) throws -> (fileURL: NSURL, bookmarkData: NSData, wasState: Bool)
{
	var stale: ObjCBool = false

	// Resolve the bookmark data.
	let fileURL = try NSURL(byResolvingBookmarkData: bookmarkData, options: .WithSecurityScope, relativeToURL: nil, bookmarkDataIsStale: &stale)
	
	var bookmarkData = bookmarkData
	if stale {
		bookmarkData = try createBookmarkDataForFileURL(fileURL)
	}
	
	return (fileURL, bookmarkData, Bool(stale))
}


enum AccessFileStage: StageProtocol {
	/// Initial stages
	case fileURL(fileURL: NSURL)
	case bookmark(data: NSData)
	/// Completed stages
	case resolved(fileURL: NSURL, bookmarkData: NSData, wasStale: Bool)
}

extension AccessFileStage {
	/// The task for each stage
	var nextTask: Task<AccessFileStage>? {
		switch self {
		case let .fileURL(fileURL):
			return Task{
				.resolved(
					fileURL: fileURL,
					bookmarkData: try createBookmarkDataForFileURL(fileURL),
					wasStale: false
				)
			}
		case let .bookmark(data):
			return Task{
				let (fileURL, bookmarkData, wasStale) = try resolveFileURLFromBookmarkData(data)
				return .resolved(
					fileURL: fileURL,
					bookmarkData: bookmarkData,
					wasStale: wasStale
				)
			}
		case .resolved:
			return nil
		}
	}
}
