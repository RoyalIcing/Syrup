//
//  FileAccessingStage.swift
//  Grain
//
//  Created by Patrick Smith on 24/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import XCTest
@testable import Grain


enum FileAccessingStage: StageProtocol {
	/// Initial stages
	case start(fileURL: NSURL)
	case stop(fileURL: NSURL, accessSucceeded: Bool)
	/// Completed stages
	case started(fileURL: NSURL, accessSucceeded: Bool)
	case stopped(fileURL: NSURL)
}

extension FileAccessingStage {
	/// The task for each stage
	var nextTask: Task<FileAccessingStage>? {
		switch self {
		case let .start(fileURL):
			return Task{
				let accessSucceeded = fileURL.startAccessingSecurityScopedResource()
				
				return .started(
					fileURL: fileURL,
					accessSucceeded: accessSucceeded
				)
			}
		case let .stop(fileURL, accessSucceeded):
			return Task{
				if accessSucceeded {
					fileURL.stopAccessingSecurityScopedResource()
				}
				
				return .stopped(
					fileURL: fileURL
				)
			}
		case .started, .stopped:
			return nil
		}
	}
}
