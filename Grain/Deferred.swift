//
//	Deferred.swift
//	Grain
//
//	Created by Patrick Smith on 17/03/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public enum Deferred<Result> {
	public typealias UseResult = () throws -> Result
	
	case unit(UseResult)
	case future((@escaping (@escaping UseResult) -> ()) -> ())
	
	public enum Error : Swift.Error {
		case underlyingErrors([Swift.Error])
	}
}

extension Deferred {
	public init(running subroutine: @escaping UseResult) {
			self = .unit(subroutine)
	}
	
	public init(throwing error: Error) {
		self = .unit{ throw error }
	}
	
//	FIXME: use GCD
//	public init<Item>
//		(completing inputDeferreds: [Deferred<Item>])
//		where Result == [Item]
//	{
//		var results = Array<Item>()
//		results.reserveCapacity(inputDeferreds.count)
//		var errors = Array<Swift.Error?>(repeating: nil, count: inputDeferreds.count)
//		error.reserveCapacity(inputDeferreds.count)
//		
//		inputDeferreds[index].perform { useResult in
//			do {
//				result = try useResult
//			}
//			catch let error {
//				
//			}
//		}
//		resolve{ results }
//	}
}

extension Deferred {
	public func perform(_ handleResult: @escaping (@escaping UseResult) -> ()) {
		switch self {
		case let .unit(useResult):
			handleResult(useResult)
		case let .future(requestResult):
			requestResult(handleResult)
		}
	}

	public func map<Output>(_ transform: @escaping (Result) throws -> Output) -> Deferred<Output> {
		switch self {
		case let .unit(useResult):
			return .unit{
				try transform(useResult())
			}
		case let .future(requestResult):
			return .future{ resolve in
				requestResult{ useResult in
					resolve{ try transform(useResult()) }
				}
			}
		}
	}
	
	public func flatMap<Output>(_ transform: @escaping (@escaping UseResult) throws -> Deferred<Output>) -> Deferred<Output> {
		switch self {
		case let .unit(useResult):
			do {
				return try transform(useResult)
			}
			catch {
				//return Deferred<Output>(error)
				return error.deferred() //as Deferred<Output>
			}
		case let .future(requestResult):
			return .future{ resolve in
				requestResult{ useResult in
					do {
						let transformedDeferred = try transform(useResult)
						transformedDeferred.perform(resolve)
					}
					catch {
						resolve{ throw error }
					}
				}
			}
		}
	}
	
	public func ignoringResult() -> Deferred<()> {
		return map{ _ in () }
	}
	
	public func withBefore<Middle>(_ before: Deferred<Middle>) -> Deferred<Result> {
		return flatMap{ useResult -> Deferred<Result> in
			Deferred.future{ resolve in
				before.perform{ _ in
					resolve(useResult)
				}
			}
		}
	}
	
	public func withCleanUp<Middle>(_ cleanUpTask: Deferred<Middle>) -> Deferred<Result> {
		return flatMap{ useResult -> Deferred<Result> in
			Deferred.future{ resolve in
				resolve(useResult)
				cleanUpTask.perform{ _ in }
			}
		}
	}
}

extension Error {
	func deferred<T>() -> Deferred<T> {
		return Deferred.unit{ throw self }
	}
}


public func +
	<Result>
	(lhs: Deferred<Result>, rhs: DispatchQueue) -> Deferred<Result>
{
	return .future{ resolve in
		return lhs.perform{ use in
			rhs.async {
				resolve(use)
			}
		}
	}
}

public func +
	<Result>
	(lhs: Deferred<Result>, rhs: DispatchQoS.QoSClass) -> Deferred<Result>
{
	return lhs + DispatchQueue.global(qos: rhs)
}


public func +
	<A, B>
	(lhs: Deferred<A>, rhs: Deferred<B>) -> Deferred<(A, B)>
{
	return lhs.flatMap{ useA in
		do {
			let a = try useA()
			return rhs.map{ b in (a, b) }
		}
	}
}

public func +
	<Result>
	(lhs: Deferred<Result>, rhs: Deferred<()>) -> Deferred<Result>
{
	return lhs.flatMap{ use in
		do {
			let result = try use()
			return rhs.map{ _ in result }
		}
	}
}

public func +
	<Result>
	(lhs: Deferred<()>, rhs: Deferred<Result>) -> Deferred<Result>
{
	return lhs.flatMap{ use in
		do {
			let _ = try use()
			return rhs
		}
	}
}
