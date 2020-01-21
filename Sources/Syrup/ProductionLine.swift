//
//	ProductionLine.swift
//	Grain
//
//	Created by Patrick Smith on 19/04/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public class ProductionLine<InnerProgression : Progression> {
	fileprivate let maxCount: Int
	fileprivate let performer: AsyncPerformer
	fileprivate var pending: [InnerProgression] = []
	fileprivate var active: [InnerProgression] = []
	fileprivate var completed: [() throws -> InnerProgression.Result] = []
	fileprivate var stateQueue = DispatchQueue(label: "ProductionLine \(String(describing: InnerProgression.self))")
	
	public init(maxCount: Int, performer: @escaping AsyncPerformer) {
		precondition(maxCount > 0, "maxCount must be greater than zero")
		self.maxCount = maxCount
		self.performer = performer
	}
	
	fileprivate func perform(_ progression: InnerProgression) {
		progression.deferred(performer: self.performer) >>= self.stateQueue + {
			[weak self] useCompletion in
			guard let receiver = self else { return }
			
			receiver.completed.append(useCompletion)
			receiver.activateNext()
		}
	}
	
	public func add(_ progressions: [InnerProgression]) {
		stateQueue.async {
			for progression in progressions {
				if self.active.count < self.maxCount {
					self.perform(progression)
				}
				else {
					self.pending.append(progression)
				}
			}
		}
	}
	
	public func add(_ stage: InnerProgression) {
		add([stage])
	}
	
	fileprivate func activateNext() {
		stateQueue.async {
			let dequeueCount = self.maxCount - self.active.count
			guard dequeueCount > 0 else { return }
			let dequeued = self.pending.prefix(dequeueCount)
			self.pending.removeFirst(dequeueCount)
			dequeued.forEach(self.perform)
		}
	}
	
	public func clearPending() {
		stateQueue.async {
			self.pending.removeAll()
		}
	}
	
	public func suspend() {
		stateQueue.suspend()
	}
	
	public func resume() {
		stateQueue.resume()
	}
}
