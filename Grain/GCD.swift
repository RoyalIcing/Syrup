//
//  GCD.swift
//  Grain
//
//  Created by Patrick Smith on 17/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


enum GCDService: ServiceProtocol {
    case background, utility, userInitiated, userInteractive
    case mainQueue
    case customQueue(dispatch_queue_t)
    
    var queue: dispatch_queue_t {
        switch self {
        case .background:
            return dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
        case .utility:
            return dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)
        case .userInitiated:
            return dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
        case .userInteractive:
            return dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)
        case .mainQueue:
            return dispatch_get_main_queue()
        case let .customQueue(queue):
            return queue
        }
    }
    
    func async(closure: () -> ()) {
        dispatch_async(queue, closure)
    }
}


struct GCDExecutionCustomizer<Stage: StageProtocol>: ExecutionCustomizing {
    var serviceForStage: Stage -> ServiceProtocol = { _ in GCDService.userInitiated }
    var completionService: ServiceProtocol = GCDService.mainQueue
    
    var shouldStopStage: Stage -> Bool = { _ in false }
    var beforeStage: Stage -> () = { _ in }
}


extension StageProtocol {
    func execute(completion: (() throws -> Self) -> ()) {
        execute(customizer: GCDExecutionCustomizer(), completion: completion)
    }
}


extension StageProtocol {
    func createTask() -> Task<Self>? {
        return .future({ self.execute($0) })
    }
}
