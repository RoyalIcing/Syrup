//
//	ProductionLine.swift
//	Grain
//
//	Created by Patrick Smith on 19/04/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public class ProductionLine<Stage : StageProtocol> {
	private let maxCount: Int
	private let environment: Environment
	private var pending: [Stage] = []
	private var active: [Stage] = []
	private var completed: [() throws -> Stage.Result] = []
	private var stateService = GCDService.serial("ProductionLine \(String(Stage))")
	
	public init(maxCount: Int, environment: Environment) {
		precondition(maxCount > 0, "maxCount must be greater than zero")
		self.maxCount = maxCount
		self.environment = environment
	}
	
	private func executeStage(stage: Stage) {
		stage.execute(environment: self.environment, completionService: self.stateService) {
			[weak self] useCompletion in
			guard let receiver = self else { return }
			
			receiver.completed.append(useCompletion)
			receiver.activateNext()
		}
	}
	
	public func add(stage: Stage) {
		stateService.async {
			if self.active.count < self.maxCount {
				self.executeStage(stage)
			}
			else {
				self.pending.append(stage)
			}
		}
	}
	
	private func activateNext() {
		stateService.async {
			let dequeueCount = self.maxCount - self.active.count
			guard dequeueCount > 0 else { return }
			let dequeued = self.pending.prefix(dequeueCount)
			self.pending.removeFirst(dequeueCount)
			dequeued.forEach(self.executeStage)
		}
	}
	
	public func add(stages: [Stage]) {
		for stage in stages {
			add(stage)
		}
	}
	
	public func clearPending() {
		stateService.async {
			self.pending.removeAll()
		}
	}
	
	public func suspend() {
		stateService.suspend()
	}
	
	public func resume() {
		stateService.resume()
	}
}
