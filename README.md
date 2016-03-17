# Grain

Grain makes data flow easier, using an enum to create discrete stages.
Associated values are used to keep state for each stage.

## Usage

```swift
enum FileOpenStage: StageProtocol {
	/// Initial stages
	case read(fileURL: NSURL)
	/// Intermediate stages
	case unserializeJSON(data: NSData)
	case parseJSON(object: AnyObject)
	/// Completed stages
	case success(text: String, number: Double, arrayOfText: [String])

	enum Error: ErrorType {
		case invalidJSON
		case missingData
	}
}
```

Each stage creates a task, which resolves to the next stage.
Tasks can be synchronous subroutines (.unit) or asynchronous futures (.future).

```swift
extension FileOpenStage {
	/// The task for each stage
	var nextTask: Task<FileOpenStage>? {
		switch self {
		case let .read(fileURL):
			return .unit({
				.unserializeJSON(
					data: try NSData(contentsOfURL: fileURL, options: .DataReadingMappedIfSafe)
				)
			})
		case let .unserializeJSON(data):
			return .unit({
				.parseJSON(
					object: try NSJSONSerialization.JSONObjectWithData(data, options: NSJSONReadingOptions())
				)
			})
		case let .parseJSON(object):
			return .unit({
				guard let dictionary = object as? [String: AnyObject] else {
					throw Error.invalidJSON
				}
				
				guard let
					text = dictionary["text"] as? String,
					number = dictionary["number"] as? Double,
					arrayOfText = dictionary["arrayOfText"] as? [String]
					else { throw Error.missingData }
				
				
				return .success(
					text: text,
					number: number,
					arrayOfText: arrayOfText
				)
			})
		case .success:
			return nil
		}
	}
}
```

To execute, create an initial stage and call `.execute()`, which uses
Grand Central Dispatch to asychronously dispatch each stage.

Your callback is passed `useResult`, which you call to return the result.
Any errors thrown in the stages will bubble up, so use Swift error
handling to catch these here in the one place. 

```swift
FileOpenStage.read(fileURL: fileURL).execute { useResult in
	do {
		let result = try useResult()
		if case let .success(text, number, arrayOfText) = result {
			// Do something with result
		}
		else {
			// Invalid stage to complete at
			fatalError("Invalid success stage \(result)")
		}
	}
	catch {
		// Handle `error` here
	}
	
	expectation.fulfill()
}
```



## Advanced

Stages can have multiple choices of initial stages or success stages.

(More to come)
