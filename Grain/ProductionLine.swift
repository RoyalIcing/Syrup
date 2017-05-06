//
//	ProductionLine.swift
//	Grain
//
//	Created by Patrick Smith on 19/04/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public class ProductionLine<Stage : StageProtocol> {
	fileprivate let maxCount: Int
	fileprivate let performer: AsyncPerformer
	fileprivate var pending: [Stage] = []
	fileprivate var active: [Stage] = []
	fileprivate var completed: [() throws -> Stage.Result] = []
	fileprivate var stateQueue = DispatchQueue(label: "ProductionLine \(String(describing: Stage.self))")
	
	public init(maxCount: Int, performer: @escaping AsyncPerformer) {
		precondition(maxCount > 0, "maxCount must be greater than zero")
		self.maxCount = maxCount
		self.performer = performer
	}
	
	fileprivate func executeStage(_ stage: Stage) {
		stage.deferred(performer: self.performer).perform(self.stateQueue + {
			[weak self] useCompletion in
			guard let receiver = self else { return }
			
			receiver.completed.append(useCompletion)
			receiver.activateNext()
		})
	}
	
	public func add(_ stages: [Stage]) {
		stateQueue.async {
			for stage in stages {
				if self.active.count < self.maxCount {
					self.executeStage(stage)
				}
				else {
					self.pending.append(stage)
				}
			}
		}
	}
	
	public func add(_ stage: Stage) {
		add([stage])
	}
	
	fileprivate func activateNext() {
		stateQueue.async {
			let dequeueCount = self.maxCount - self.active.count
			guard dequeueCount > 0 else { return }
			let dequeued = self.pending.prefix(dequeueCount)
			self.pending.removeFirst(dequeueCount)
			dequeued.forEach(self.executeStage)
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
