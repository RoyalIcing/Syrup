//
//	SerialStage.swift
//	Grain
//
//	Created by Patrick Smith on 19/04/2016.
//	Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public enum Serial<Stage : Progression> {
	public typealias Result = [Stage.Result]
	
	case start(stages: [Stage], performer: AsyncPerformer)
	case running(remainingStages: [Stage], activeStage: Stage, completedSoFar: [Stage.Result], performer: AsyncPerformer)
	case completed(Result)
}

extension Serial : Progression {
	public mutating func updateOrDeferNext() throws -> Deferred<Serial<Stage>>? {
		switch self {
		case let .start(stages, performer):
			guard stages.count > 0 else {
				self = .completed([])
				return nil
			}
			
			var remainingStages = stages
			let nextStage = remainingStages.remove(at: 0)
			
			self = .running(remainingStages: remainingStages, activeStage: nextStage, completedSoFar: [], performer: performer)
		case let .running(remainingStages, activeStage, completedSoFar, performer):
			return activeStage.deferred(performer: performer).map{ result in
				var completedSoFar = completedSoFar
				completedSoFar.append(result)
				
				if remainingStages.count == 0 {
					return .completed(completedSoFar)
				}
				
				var remainingStages = remainingStages
				let nextStage = remainingStages.remove(at: 0)
				
				return .running(remainingStages: remainingStages, activeStage: nextStage, completedSoFar: completedSoFar, performer: performer)
			}
		case .completed:
			break
		}
		return nil
	}
	
	public var result: Result? {
		guard case let .completed(result) = self else { return nil }
		return result
	}
}


extension Sequence where Iterator.Element : Progression {
	public func serially(on performer: @escaping AsyncPerformer) -> Deferred<[Iterator.Element.Result]>
	{
		return Serial.start(stages: Array(self), performer: performer)
			.deferred(performer: performer)
	}
}
