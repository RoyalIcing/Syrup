//
//  Types.swift
//  Grain
//
//  Created by Patrick Smith on 5/5/17.
//  Copyright © 2017 Burnt Caramel. All rights reserved.
//

import Foundation


protocol JSONDecodable {
	init(json: Any) throws
}


struct Example {
	var text: String
	var number: Double
	var arrayOfText: [String]
	
	// Any errors thrown by the stages
	enum Error : Swift.Error {
		case cannotAccess
		case invalidJSON
		case missingInformation
	}
}

extension Example : JSONDecodable {
	init(json: Any) throws {
		guard let dictionary = json as? [String: AnyObject] else {
			throw Error.invalidJSON
		}
		
		guard let
			text = dictionary["text"] as? String,
			let number = dictionary["number"] as? Double,
			let arrayOfText = dictionary["arrayOfText"] as? [String]
			else { throw Error.missingInformation }
		
		self.init(
			text: text,
			number: number,
			arrayOfText: arrayOfText
		)
	}
}
