# Syrup

## Overview

Syrup makes data flow simple in Swift. Each step is represented by its own case in an enum.

Associated values are used to keep state for each step. This makes it very easy to implement — just write what it takes to get from one step to the next, and so on.

Grand Central Dispatch is then used to run the steps asynchronously on a queue.

Having explicit enum cases for each step makes it easy to test from any point in the data flow.

## Installation

### Carthage

```
github "BurntCaramel/Syrup"
```

## Usage

A real world example for loading and saving JSON in my app Lantern can be seen here: https://github.com/BurntCaramel/Lantern/blob/9e5e8aa95e967b07a9968efaef22e8c10ea3358f/LanternModel/ModelManager.swift#L41

---

The example below scopes access to a security scoped file.

```swift
struct FileAccessProgression : Progression {
	let fileURL: URL
	private var startAccess: Bool
	private var done: Bool
	
	init(fileURL: URL) {
		self.fileURL = fileURL
		startAccess = true
		done = false
	}
	
	enum ErrorKind : Error {
		case cannotAccess(fileURL: URL)
	}
	
	mutating func updateOrDeferNext() throws -> Deferred<FileAccessProgression>? {
		if startAccess {
			let accessSucceeded = fileURL.startAccessingSecurityScopedResource()
			if !accessSucceeded {
				throw ErrorKind.cannotAccess(fileURL: fileURL)
			}
		}
		else {
			fileURL.stopAccessingSecurityScopedResource()
		}
		
		done = true
		
		// Mutated, so no need to return future
		return nil
	}
	
	typealias Result = FileAccessProgression
	var result: FileAccessProgression? {
		guard done else { return nil }
		
		var copy = self
		if startAccess {
			copy.startAccess = false
			copy.done = false
		}
		return copy
	}
}
```

Each step updates to or returns its next step. Asynchronous steps can return a Deferred which resolves to the next step.

Syrup runs each step on a Grand Central Dispatch queue.

To run, create a progression and divide it by the quality of service to run on.
Then bind `>>=` a callback to start the progression and receive the result.

Your callback is passed a throwing function `useResult` — call it to get the result.
Errors thrown in any of the steps will bubble up, so use Swift error
handling to `catch` them all here in the one place. 

```swift
FileAccessProgression(fileURL: fileURL) / .utility >>= { useResult in
	do {
		let stopAccessing = try useResult()
		// Use stopAccessing.fileURL

		// Run when done accessing
		stopAccessing / .utility >>= { _ in
		}
		catch {
			// Handle `error` here
		}
	}
}
```

## Using existing asynchronous libraries

Syrup can create tasks for existing asychronous libraries, such as NSURLSession.
Use the `.future` task, and resolve the value, or resolve throwing an error.

```swift
enum HTTPRequestProgression : Progression {
	typealias Result = (response: HTTPURLResponse, body: Data?)
	
	case get(url: URL)
	case post(url: URL, body: Data)
	
	case success(Result)
	
	mutating func updateOrDeferNext() -> Deferred<HTTPRequestProgression>? {
		switch self {
		case let .get(url):
			return Deferred.future{ resolve in
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
			}
		case let .post(url, body):
			return Deferred.future{ resolve in
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
			}
		case .success:
			return nil
		}
	}
	
	var result: Result? {
		guard case let .success(result) = self else { return nil }
		return result
	}
}
```

## Motivations

- Captures data flow in a declarative form making it easier to understand. Your progression is a reusable recipe for what to do.
- Associated values capture the entire state at a particular stage in the flow. There’s no external state or side effects, just work with what’s stored in each case.
- Each step is distinct, and can produce its next step easily in either a sychronous or asychronous manner.
- Steps are able to be stored and restored at will, as they are just enums with associated data. This allows easier unit testing, since you can resume at any step in the progression.
- Swift’s native error handling is used.

## Multiple inputs or outputs

Stages can have multiple choices of initial stages: just add multiple cases!

For multiple choice of output, use a `enum` for the `Result` associated type.

## Composing stages

`Progression` includes `.map` and `.flatMap` (also `>>=`) methods, allowing progressions to be composed
inside other progressions. A series of progressions can become a single progression in a combined
enum, and so on.

For example, combining a file read with a web upload:

```swift
enum HTTPRequestProgression : Progression {
	typealias Result = (response: HTTPURLResponse, body: Data?)
	
	case get(url: URL)
	case post(url: URL, body: Data)
	
	case success(Result)
	
	mutating func updateOrDeferNext() -> Deferred<HTTPRequestProgression>? {
		switch self {
		case let .get(url):
			return Deferred.future{ resolve in
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
			}
		case let .post(url, body):
			return Deferred.future{ resolve in
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
			}
		case .success:
			break
		}
		return nil
	}
	
	var result: Result? {
		guard case let .success(result) = self else { return nil }
		return result
	}
}
```
