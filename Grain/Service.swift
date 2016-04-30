//
//  Service.swift
//  Grain
//
//  Created by Patrick Smith on 17/03/2016.
//  Copyright © 2016 Burnt Caramel. All rights reserved.
//

import Foundation


public protocol ServiceProtocol {
	func async(closure: () -> ())
}


public func + <Result>(lhs: Task<Result>, rhs: ServiceProtocol) -> Task<Result> {
	return Task.future{ resolve in
		lhs.perform{ useResult in
			rhs.async{
				resolve(useResult)
			}
		}
	}
}

public func += <Result>(inout lhs: Task<Result>, rhs: ServiceProtocol) {
	lhs = lhs + rhs
}

