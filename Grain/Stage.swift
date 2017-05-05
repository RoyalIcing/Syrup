//
//	Stage.swift
//	Grain
//
//	Created by Patrick Smith on 17/03/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public typealias AsyncPerformer = (@escaping () -> ()) -> ()

enum ProgressionError : Swift.Error {
	case cancelled
}

public protocol StageProtocol {
	associatedtype Result
	
	mutating func updateOrReturnNext() throws -> Deferred<Self>?
	func next() -> Deferred<Self>
	
	var result: Result? { get }
}

extension StageProtocol {
	public mutating func updateOrReturnNext() throws -> Deferred<Self>? {
		fatalError("Implement either the updateOrReturnNext() or next() method")
	}
	
	public func next() -> Deferred<Self> {
		var copy = self
		return Deferred.future{ resolve in
			do {
				if let deferred = try copy.updateOrReturnNext() {
					deferred.perform(resolve)
				}
				else {
					resolve({ copy })
				}
			}
			catch {
				resolve({ throw error })
			}
		}
	}
}


extension StageProtocol {
	public func transform
		<Other>(
		next transformNext: @escaping (Self) throws -> Other,
		result transformResult: (Result) -> Deferred<Other>
		) -> Deferred<Other>
	{
		if let result = result {
			return transformResult(result)
		}
		else {
			return next().map(transformNext)
		}
	}
}

extension StageProtocol {
	public func deferred(
		performer: @escaping AsyncPerformer = { closure in DispatchQueue.global(qos: .utility).async(execute: closure) },
		progress: @escaping (Self) -> Bool = { _ in true }
		) -> Deferred<Result> {
		
		return Deferred.future{ resolve in
			func handleResult(_ getStage: () throws -> Self) {
				do {
					let nextStage = try getStage()
					next(nextStage)
				}
				catch let error {
					resolve{ throw error }
				}
			}
			
			func next(_ stage: Self) {
				performer {
					guard progress(stage) else {
						resolve{ throw ProgressionError.cancelled }
						return
					}
					
					if let result = stage.result {
						resolve{ result }
					}
					else {
						let nextDeferred = stage.next()
						nextDeferred.perform(handleResult)
					}
				}
			}
			
			next(self)
		}
	}
}


public func *
	<Result, Stage : StageProtocol>
	(lhs: Stage, rhs: @escaping AsyncPerformer) -> Deferred<Result> where Stage.Result == Result
{
	return lhs.deferred(performer: rhs)
}

public func *
	<Result, Stage : StageProtocol>
	(lhs: Stage, rhs: DispatchQueue) -> Deferred<Result> where Stage.Result == Result
{
	return lhs.deferred(performer: { rhs.async(execute: $0) })
}

public func *
	<Result, Stage : StageProtocol>
	(lhs: Stage, rhs: DispatchQoS.QoSClass) -> Deferred<Result> where Stage.Result == Result
{
	//return lhs + DispatchQueue.global(qos: rhs)
	let queue = DispatchQueue.global(qos: rhs)
	return lhs.deferred(performer: { queue.async(execute: $0) })
}


public func completedStage
	<Stage : StageProtocol>
	(_ stage: Stage) -> Never
{
	fatalError("No next task for completed stage \(stage)")
}
