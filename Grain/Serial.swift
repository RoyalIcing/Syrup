//
//  SerialStage.swift
//  Grain
//
//  Created by Patrick Smith on 19/04/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public enum Serial<Stage : StageProtocol> {
	public typealias Completion = [() throws -> Stage.Completion]
	
	case start(stages: [Stage], environment: Environment)
	case running(remainingStages: [Stage], activeStage: Stage, completedSoFar: [() throws -> Stage.Completion], environment: Environment)
	case completed(Completion)
}

extension Serial : StageProtocol {
	public var nextTask: Task<Serial>? {
		switch self {
		case let .start(stages, environment):
			if stages.count == 0 {
				return Task{ .completed([]) }
			}
			
			var remainingStages = stages
			let nextStage = remainingStages.removeAtIndex(0)
			
			return Task{
				.running(remainingStages: remainingStages, activeStage: nextStage, completedSoFar: [], environment: environment)
			}
		case let .running(remainingStages, activeStage, completedSoFar, environment):
			return activeStage.taskExecuting(environment: environment, completionService: nil).flatMap { useCompletion in
				var completedSoFar = completedSoFar
				completedSoFar.append(useCompletion)
				
				if remainingStages.count == 0 {
					return Task{ .completed(completedSoFar) }
				}
				
				var remainingStages = remainingStages
				let nextStage = remainingStages.removeAtIndex(0)
				
				return Task{ .running(remainingStages: remainingStages, activeStage: nextStage, completedSoFar: completedSoFar, environment: environment) }
			}
		case .completed:
			return nil
		}
	}
	
	public var completion: Completion? {
		guard case let .completed(completion) = self else { return nil }
		return completion
	}
}


extension SequenceType where Generator.Element : StageProtocol {
	public func executeSerially(
		environment: Environment,
		completion: (() throws -> [() throws -> Generator.Element.Completion]) -> ()
		)
	{
		Serial.start(stages: Array(self), environment: environment)
			.execute(environment: environment, completionService: nil, completion: completion)
	}
}
