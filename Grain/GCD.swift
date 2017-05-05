//
//	GCD.swift
//	Grain
//
//	Created by Patrick Smith on 17/03/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


extension Deferred {
	init<Item>
		(concurrentlyPerform itemFuncs: [() -> Item], queue: DispatchQueue)
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

// Execute on queue
public func +
	<Input>
	(lhs: @escaping (Input) -> (), rhs: DispatchQueue) -> ((Input) -> ())
{
	return { input in
		rhs.async {
			lhs(input)
		}
	}
}

// Concurrently execute
public func *
	<Result>
	(lhs: [() -> Result], rhs: DispatchQueue) -> Deferred<[Result]>
{
	return Deferred(concurrentlyPerform: lhs, queue: rhs)
}
