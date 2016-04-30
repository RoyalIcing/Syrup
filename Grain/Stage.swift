//
//  Stage.swift
//  Grain
//
//  Created by Patrick Smith on 17/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public protocol StageProtocol {
	associatedtype Result
	
	func next() -> Task<Self>
	
	var result: Result? { get }
}

extension StageProtocol {
	public func compose
		<Other>
		(transformNext transformNext: (Self) throws -> Other, transformResult: (Result) throws -> Other) -> Task<Other>
	{
		if let result = result {
			return Task.unit({ try transformResult(result) })
		}
		else {
			return next().map(transformNext)
		}
	}
}


extension StageProtocol {
	public func execute(
		environment environment: Environment,
		            completionService: ServiceProtocol?,
		            completion: (() throws -> Result) -> ()
		)
	{
		func complete(useResult: (() throws -> Result)) {
			if let completionService = completionService {
				completionService.async{
					completion(useResult)
				}
			}
			else {
				completion(useResult)
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
				
				if let result = stage.result {
					complete{ result }
				}
				else {
					let nextTask = stage.next()
					nextTask.perform(handleResult)
				}
			}
		}
		
		runStage(self)
	}
	
	public func taskExecuting
		(environment: Environment) -> Task<Result>
	{
		return Task.future{ resolve in
			self.execute(environment: environment, completionService: nil, completion: resolve)
		}
	}
}


@noreturn public func completedStage
	<Stage : StageProtocol>
	(stage: Stage)
{
	fatalError("No next task for completed stage \(stage)")
}
