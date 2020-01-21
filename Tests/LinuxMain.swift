import XCTest

import SyrupTests

var tests = [XCTestCaseEntry]()
tests += SyrupTests.allTests()
XCTMain(tests)
