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
	
	public func after(delay: Double, closure: () -> ()) {
		let time = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
		dispatch_after(time, queue, closure)
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


// Used for + below
private struct GCDDelayedService : ServiceProtocol {
	private let underlyingService: GCDService
	private let delay: Double
	
	private func async(closure: () -> ()) {
		underlyingService.after(delay, closure: closure)
	}
}

// e.g. Delay by 4 seconds: `GCDService.mainQueue + 4.0`
public func + (lhs: GCDService, rhs: Double) -> ServiceProtocol {
	return GCDDelayedService(underlyingService: lhs, delay: rhs)
}


extension StageProtocol {
	// Convenience method for GCD
	public func execute(completion: (() throws -> Result) -> ()) {
		execute(environment: GCDService.utility, completionService: nil, completion: completion)
	}

	// Convenience method for GCD
	public func taskExecuting() -> Deferred<Result> {
		return .future({ self.execute($0) })
	}
}
