//
//  Environment.swift
//  Grain
//
//  Created by Patrick Smith on 17/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public protocol Environment {
	func service
		<Stage : StageProtocol>
		(forStage stage: Stage) -> ServiceProtocol
	
	func shouldStop
		<Stage : StageProtocol>
		(stage: Stage) -> Bool
	
	func before
		<Stage : StageProtocol>
		(stage: Stage) -> ()
	
	func adjust
		<Stage : StageProtocol>(stage: Stage) -> Stage
}

extension Environment {
	public func shouldStop
		<Stage : StageProtocol>
		(stage: Stage) -> Bool
	{
		return false
	}
	
	public func before
		<Stage : StageProtocol>
		(stage: Stage) -> ()
	{}
	
	public func adjust
		<Stage : StageProtocol>
		(stage: Stage) -> Stage
	{
		return stage
	}
}


public enum EnvironmentError : ErrorType {
	case stopped
}


extension ServiceProtocol where Self : Environment {
	func service
		<Stage : StageProtocol>
		(forStage stage: Stage) -> ServiceProtocol
	{
		return self
	}
}


extension StageProtocol {
	public func execute(
		environment environment: Environment,
		            completionService: ServiceProtocol?,
		            completion: (() throws -> Completion) -> ()
		)
	{
		func complete(useStage: (() throws -> Self)) {
			if let completionService = completionService {
				completionService.async{
					completion{
						try useStage().requireCompletion()
					}
				}
			}
			else {
				completion{
					try useStage().requireCompletion()
				}
			}
		}
		
		func handleResult(getStage: () throws -> Self) {
			do {
				let nextStage = try getStage()
				runStage(nextStage)
			}
			catch let error {
				complete{ throw error }
			}
		}
		
		func runStage(stage: Self) {
			environment.service(forStage: stage).async {
				if environment.shouldStop(stage) {
					complete{ throw EnvironmentError.stopped }
					return
				}
				
				environment.before(stage)
				
				if let nextTask = stage.nextTask {
					nextTask.perform(handleResult)
				}
				else {
					complete{ stage }
				}
			}
		}
		
		runStage(self)
	}
	
	public func taskExecuting
		(environment environment: Environment, completionService: ServiceProtocol?) -> Task<Completion>
	{
		return Task.future{ resolve in
			self.execute(environment: environment, completionService: completionService, completion: resolve)
		}
	}
}
