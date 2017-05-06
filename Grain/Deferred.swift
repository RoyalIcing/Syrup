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
}

extension Error {
	func deferred<T>() -> Deferred<T> {
		return Deferred.unit{ throw self }
	}
}


/// Perform deferred and call closure with result
public func >>=
	<Result>
	(lhs: Deferred<Result>, rhs: @escaping (@escaping () throws -> Result) -> ())
{
	lhs.perform(rhs)
}

/// Transform the input by the passed closure, returning a new deferred
public func >>=
	<Result, Output>
	(lhs: Deferred<Result>, rhs: @escaping (@escaping Deferred<Result>.UseResult) throws -> Deferred<Output>)
	-> Deferred<Output>
{
	return lhs.flatMap(rhs)
}


/// Wrap to execute on queue
public func +
	<Input>
	(lhs: DispatchQueue, rhs: @escaping (Input) -> ()) -> ((Input) -> ())
{
	return { input in
		lhs.async {
			rhs(input)
		}
	}
}

/// Execute completion on queue
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

/// Execute completion on queue of specified QoS
public func +
	<Result>
	(lhs: Deferred<Result>, rhs: DispatchQoS.QoSClass) -> Deferred<Result>
{
	return lhs + DispatchQueue.global(qos: rhs)
}


public func &
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

public func &
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

public func &
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

// Concurrent eecution of multiple deferreds
extension Deferred {
	init<Item>
		(concurrentlyPerforming itemFuncs: [() -> Item], queue: DispatchQueue)
		where Result == [Item]
	{
		self = .future{ resolve in
			queue.async{
				var results = Array<Item>()
				results.reserveCapacity(itemFuncs.count)
				results.withUnsafeMutableBufferPointer{ buffer in
					DispatchQueue.concurrentPerform(iterations: itemFuncs.count) { index in
						buffer[index] = itemFuncs[index]()
					}
				}
				resolve{ results }
			}
		}
	}
}

// Concurrently execute
public func /
	<Result>
	(lhs: [() -> Result], rhs: DispatchQueue) -> Deferred<[Result]>
{
	return Deferred(concurrentlyPerforming: lhs, queue: rhs)
}

