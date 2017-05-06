# Grain

Grain makes data flow simple in Swift. Each step in the flow is represented by its own case in an enum.

Associated values are used to keep state for each step. This makes it easy to implement each step — just write what it takes to get to the next step, and so on.

Having explicit enum cases for each step also makes it easy to test from any point in the data flow.

## Installation

### Carthage

```
github "BurntCaramel/Grain"
```

## Usage

A real world example for loading and saving JSON in my app Lantern can be seen here: https://github.com/BurntCaramel/Lantern/blob/9e5e8aa95e967b07a9968efaef22e8c10ea3358f/LanternModel/ModelManager.swift#L41

---

The example below scopes access to a security scoped file.

```swift
indirect enum FileAccessProgression : Progression {
	typealias Result = (fileURL: URL, hasAccess: Bool, stopper: FileAccessProgression?)
	
	/// Initial steps
	case start(fileURL: URL, forgiving: Bool)
	case stop(fileURL: URL)
	/// Completed step
	case complete(Result)
	
	enum ErrorKind : Error {
		case cannotAccess(fileURL: URL)
	}
}
```

Each step creates a next task, which resolves to the next stage.
Deferreds can be subroutines (`Deferred()`) or asynchronous futures (`Deferred.future()`).

Grain by default runs deferred steps on a background queue, even synchronous ones.

```swift
extension FileAccessProgression {
	/// The task for each stage
	func next() -> Deferred<FileAccessProgression> {
		switch self {
		case let .start(fileURL, forgiving):
			return Deferred{
				let accessSucceeded = fileURL.startAccessingSecurityScopedResource()
				
				if !accessSucceeded && !forgiving {
					throw ErrorKind.cannotAccess(fileURL: fileURL)
				}
				
				return FileAccessProgression.complete((
					fileURL: fileURL,
					hasAccess: accessSucceeded,
					stopper: accessSucceeded ? FileAccessProgression.stop(
						fileURL: fileURL
					) : nil
				))
			}
		case let .stop(fileURL):
			return Deferred{
				fileURL.stopAccessingSecurityScopedResource()
				
				return FileAccessProgression.complete((
					fileURL: fileURL,
					hasAccess: false,
					stopper: nil
				))
			}
		case .complete:
			completedStage(self)
		}
	}
	
	var result: Result? {
		guard case let .complete(result) = self else { return nil }
		return result
	}
}
```

To run, create an initial stage and call `.execute()`, which uses
Grand Central Dispatch to asychronously dispatch each step, by default
with a **utility** quality of service.

Your callback is passed `useResult` — call it to get the result.
Errors thrown in any of the steps will bubble up, so use Swift error
handling to `catch` them all here in the one place. 

```swift
FileAccessProgression.start(fileURL: fileURL, forgiving: true).execute { useResult in
	do {
		let result = try useResult()
		if let stopper = result.stopper {
			// Use result.fileURL
			// All when done accessing
			stopper.execute { _ in
			}
		}
		catch {
			// Handle `error` here
		}
	}
}
```

## Using existing asynchronous libraries

Grain can create tasks for existing asychronous libraries, such as NSURLSession.
Use the `.future` task, and resolve the value, or resolve throwing an error.

```swift
enum HTTPRequestProgression : Progression {
	typealias Result = (response: HTTPURLResponse, body: Data?)
	
	case get(url: URL)
	case post(url: URL, body: Data)
	
	case success(Result)
	
	func next() -> Deferred<HTTPRequestProgression> {
		return Deferred.future{ resolve in
			switch self {
			case let .get(url):
				let session = URLSession.shared
				let task = session.dataTask(with: url, completionHandler: { data, response, error in
					if let error = error {
						resolve{ throw error }
					}
					else {
						resolve{ .success((response: response as! HTTPURLResponse, body: data)) }
					}
				}) 
				task.resume()
			case let .post(url, body):
				let session = URLSession.shared
        var request = URLRequest(url: url)
				request.httpBody = body
				let task = session.dataTask(with: request, completionHandler: { (data, response, error) in
					if let error = error {
						resolve { throw error }
					}
					else {
						resolve { .success((response: response as! HTTPURLResponse, body: data)) }
					}
				}) 
				task.resume()
			case .success:
				completedStage(self)
			}
		}
	}
	
	var result: Result? {
		guard case let .success(result) = self else { return nil }
		return result
	}
}
```

## Motivations

- Breaking a data flow into a more declarative form makes it easier to understand.
- Associated values capture the entire state at a particular stage in the flow. There’s no external state or side effects, just what’s stored in each case.
- Each stage is distinct, produces its next stage in a sychronous or
asychronous manner.
- Stages are able to be stored and restored at will as they are just enums. This allows easier testing, since you can resume at any stage, not just initial ones.
- Swift’s native error handling is used.

## Multiple inputs or outputs

Stages can have multiple choices of initial stages: just add multiple cases!

For multiple choice of output, use a `enum` for the `Result` associated type.

## Composing stages

`Progression` includes `.map` and `.flatMap` methods, allowing stages to be composed
inside other stages. A series of stages can become a single stage in a different
enum, and so on.

For example, combining a file read with a web upload progression:

```swift
enum FileUploadProgression : Progression {
	typealias Result = Any?
	
	case openFile(fileStage: JSONFileReadProgression, destinationURL: URL)
	case uploadRequest(request: HTTPRequestProgression)
	case parseUploadResponse(data: Data?)
	case success(Result)
	
	enum ErrorKind : Error {
		case uploadFailed(statusCode: Int, body: Data?)
		case uploadResponseParsing(body: Data?)
	}
	
	func next() -> Deferred<FileUploadProgression> {
		switch self {
		case let .openFile(stage, destinationURL):
			return stage.compose(
				transformNext: {
					.openFile(fileStage: $0, destinationURL: destinationURL)
				},
				transformResult: { result in
					Deferred{ .uploadRequest(
						request: .post(
							url: destinationURL,
							body: try JSONSerialization.data(withJSONObject: [ "number": result.number ], options: [])
						)
					) }
				}
			)
		case let .uploadRequest(stage):
			return stage.compose(
				transformNext: {
					.uploadRequest(request: $0)
				},
				transformResult: { result in
					let (response, body) = result
					switch response.statusCode {
					case 200:
            return Deferred{ .parseUploadResponse(data: body) }
					default:
            return Deferred{ throw ErrorKind.uploadFailed(statusCode: response.statusCode, body: body) }
					}
				}
			)
		case let .parseUploadResponse(data):
			return Deferred{
				.success(
					try data.map{ try JSONSerialization.jsonObject(with: $0, options: []) }
				)
			}
		case .success:
			completedStage(self)
		}
	}
	
	var result: Result? {
		guard case let .success(result) = self else { return nil }
		return result
	}
}
```
