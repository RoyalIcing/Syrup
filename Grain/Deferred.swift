//
//  Deferred.swift
//  Grain
//
//  Created by Patrick Smith on 17/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public enum Deferred<Result> {
	public typealias UseResult = () throws -> Result
	
	case unit(UseResult)
	case future(((UseResult) -> ()) -> ())
}

extension Deferred {
	public init(_ subroutine: UseResult) {
			self = .unit(subroutine)
	}
	
	public init(_ error: ErrorType) {
		self = .unit({ throw error })
	}
}

extension Deferred {
	public func perform(handleResult: (UseResult) -> ()) {
		switch self {
		case let .unit(useResult):
			handleResult(useResult)
		case let .future(requestResult):
			requestResult(handleResult)
		}
	}
}

extension Deferred {
	public func map<Output>(transform: (Result) throws -> Output) -> Deferred<Output> {
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
	
	public func flatMap<Output>(transform: (UseResult) throws -> Deferred<Output>) -> Deferred<Output> {
		switch self {
		case let .unit(useResult):
			do {
				return try transform(useResult)
			}
			catch {
				return Deferred<Output>(error)
			}
		case let .future(requestResult):
			return .future({ resolve in
				requestResult{ useResult in
					do {
						let transformedDeferred = try transform(useResult)
						transformedDeferred.perform(resolve)
					}
					catch {
						resolve{ throw error }
					}
				}
			})
		}
	}
}
