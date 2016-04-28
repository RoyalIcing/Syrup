//
//  GCD.swift
//  Grain
//
//  Created by Patrick Smith on 17/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public enum GCDService : ServiceProtocol {
	case background, utility, userInitiated, userInteractive
	case mainQueue
	case customQueue(dispatch_queue_t)
	
	public var queue: dispatch_queue_t {
		switch self {
		case .background:
			return dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
		case .utility:
			return dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)
		case .userInitiated:
			return dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
		case .userInteractive:
			return dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)
		case .mainQueue:
			return dispatch_get_main_queue()
		case let .customQueue(queue):
			return queue
		}
	}
	
	public func async(closure: () -> ()) {
		dispatch_async(queue, closure)
	}
	
	public func suspend() {
		dispatch_suspend(queue)
	}
	
	public func resume() {
		dispatch_resume(queue)
	}
	
	public static func serial(label: UnsafePointer<Int8> = nil) -> GCDService {
		let queue = dispatch_queue_create(label, DISPATCH_QUEUE_SERIAL)
		return .customQueue(queue)
	}
}


extension GCDService : Environment {
	public func service
		<Stage : StageProtocol>
		(forStage stage: Stage) -> ServiceProtocol
	{
		return self
	}
}

// Convenience method for GCD
extension StageProtocol {
	public func execute(completion: (() throws -> Completion) -> ()) {
		execute(environment: GCDService.utility, completionService: nil, completion: completion)
	}
}


extension StageProtocol {
	public func taskExecuting() -> Task<Completion> {
		return .future({ self.execute($0) })
	}
}
