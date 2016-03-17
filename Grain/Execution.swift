//
//  Executor.swift
//  Grain
//
//  Created by Patrick Smith on 17/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


protocol ExecutionCustomizing {
    typealias Stage: StageProtocol
    
    var serviceForStage: Stage -> ServiceProtocol { get }
    var completionService: ServiceProtocol { get }
    
    var shouldStopStage: Stage -> Bool { get }
    var tap: Stage -> () { get }
}


enum ExecutionError: ErrorType {
    case stopped
}


extension StageProtocol {
    func execute<ExecutionCustomizer: ExecutionCustomizing where ExecutionCustomizer.Stage == Self>(customizer customizer: ExecutionCustomizer, completion: (() throws -> Self) -> ()) {
        func complete(getStage: (() throws -> Self)) {
            customizer.completionService.async {
                completion(getStage)
            }
        }
        
        func handleResult(getStage: () throws -> Self) {
            do {
                let nextStage = try getStage()
                runStage(nextStage)
            }
            catch let error {
                complete { throw error }
            }
        }
        
        func runStage(stage: Self) {
            customizer.serviceForStage(stage).async {
                if customizer.shouldStopStage(stage) {
                    complete { throw ExecutionError.stopped }
                    return
                }
                
                customizer.tap(stage)
                
                if let nextTask = stage.nextTask {
                    nextTask.perform(handleResult)
                }
                else {
                    complete { stage }
                }
            }
        }
        
        runStage(self)
    }
}

