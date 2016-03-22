//
//  Task.swift
//  Grain
//
//  Created by Patrick Smith on 17/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public enum Task<Result> {
	public typealias UseResult = () throws -> Result
	
	case unit(UseResult)
	case future((UseResult -> ()) -> ())
}

extension Task {
	init(_ subroutine: UseResult) {
			self = .unit(subroutine)
	}
}

extension Task {
	public func perform(handleResult: UseResult -> ()) {
		switch self {
		case let .unit(useResult):
			handleResult(useResult)
		case let .future(requestResult):
			requestResult(handleResult)
		}
	}
	
	public func map<Output>(transform: Result throws -> Output) -> Task<Output> {
		switch self {
		case let .unit(useResult):
			return .unit({
				return try transform(useResult())
			})
		case let .future(requestResult):
			return .future({ resolve in
				requestResult{ useResult in
					resolve{ try transform(useResult()) }
				}
			})
		}
	}
	
	public func flatMap<Output>(transform: UseResult -> Task<Output>) -> Task<Output> {
		switch self {
		case let .unit(useResult):
			return transform(useResult)
		case let .future(requestResult):
			return .future({ resolve in
				requestResult{ useResult in
					let transformedTask = transform(useResult)
					transformedTask.perform(resolve)
				}
			})
		}
	}
}
