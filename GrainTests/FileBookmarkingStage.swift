//
//  FileBookmarkingStage.swift
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


enum FileBookmarkingStage: StageProtocol {
	/// Initial stages
	case fileURL(fileURL: NSURL)
	case bookmark(bookmarkData: NSData)
	/// Completed stages
	case resolved(fileURL: NSURL, bookmarkData: NSData, wasStale: Bool)
}

extension FileBookmarkingStage {
	/// The task for each stage
	func nextTask<Customizer: ExecutionCustomizing where Customizer.Stage == FileBookmarkingStage>(customizer: Customizer) -> Task<FileBookmarkingStage>? {
		switch self {
		case let .fileURL(fileURL):
			return Task{
				.resolved(
					fileURL: fileURL,
					bookmarkData: try createBookmarkDataForFileURL(fileURL),
					wasStale: false
				)
			}
		case let .bookmark(bookmarkData):
			return Task{
				var stale: ObjCBool = false
				// Resolve the bookmark data.
				let fileURL = try NSURL(byResolvingBookmarkData: bookmarkData, options: .WithSecurityScope, relativeToURL: nil, bookmarkDataIsStale: &stale)
				
				var bookmarkData = bookmarkData
				if stale {
					bookmarkData = try createBookmarkDataForFileURL(fileURL)
				}

				return .resolved(
					fileURL: fileURL,
					bookmarkData: bookmarkData,
					wasStale: Bool(stale)
				)
			}
		case .resolved:
			return nil
		}
	}
}
