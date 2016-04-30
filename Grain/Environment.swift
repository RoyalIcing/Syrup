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
