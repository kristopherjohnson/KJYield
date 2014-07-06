// Copyright (c) 2014 Kristopher Johnson
//
// Permission is hereby granted, free of charge, to any person obtaining
// a copy of this software and associated documentation files (the
// "Software"), to deal in the Software without restriction, including
// without limitation the rights to use, copy, modify, merge, publish,
// distribute, sublicense, and/or sell copies of the Software, and to
// permit persons to whom the Software is furnished to do so, subject to
// the following conditions:
//
// The above copyright notice and this permission notice shall be
// included in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
// EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
// MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
// NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
// LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
// OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
// WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

import XCTest
import Foundation
import KJYield

class KJYieldTests: XCTestCase {
    
    func testNumericSequence() {
        // Sequence [3, 6, 9, 12, 15]
        let seq: SequenceOf<Int> = sequence { yield in
            for n in 0..5 { yield((n+1) * 3) }
        }
        
        var a = Array<Int>(seq)
        XCTAssertEqual(5, a.count)
        XCTAssertEqual(3, a[0])
        XCTAssertEqual(6, a[1])
        XCTAssertEqual(9, a[2])
        XCTAssertEqual(12, a[3])
        XCTAssertEqual(15, a[4])
    }
    
    func testFibonacciSequence() {
        // Produce first 20 elements of Fibonacci sequence
        let fibs = Array<Int>(sequence { yield in
            var a = 0, b = 1
            for _ in 0..20 {
                yield(b)
                let sum = a + b
                a = b
                b = sum
            }
        })
        
        XCTAssertEqual(20, fibs.count)
        
        XCTAssertEqual(1,  fibs[0])
        XCTAssertEqual(1,  fibs[1])
        XCTAssertEqual(2,  fibs[2])
        XCTAssertEqual(3,  fibs[3])
        XCTAssertEqual(5,  fibs[4])
        XCTAssertEqual(8,  fibs[5])

        XCTAssertEqual(55, fibs[9])

        XCTAssertEqual(6765, fibs[19])
    }
    
    func testFizzBuzz() {
        let fizzBuzz = Array<String>(sequence { yield in
            for n in 1...100 {
                if n % 3 == 0 {
                    if n % 5 == 0 {
                        yield("FizzBuzz")
                    }
                    else {
                        yield("Fizz")
                    }
                }
                else if n % 5 == 0 {
                    yield("Buzz")
                }
                else {
                    yield(n.description)
                }
            }
        })
        
        XCTAssertEqual(100, fizzBuzz.count)
        
        XCTAssertEqual("1",        fizzBuzz[0])
        XCTAssertEqual("2",        fizzBuzz[1])
        XCTAssertEqual("Fizz",     fizzBuzz[2])
        XCTAssertEqual("4",        fizzBuzz[3])
        XCTAssertEqual("Buzz",     fizzBuzz[4])
        XCTAssertEqual("Fizz",     fizzBuzz[5])
        XCTAssertEqual("7",        fizzBuzz[6])
        
        XCTAssertEqual("14",       fizzBuzz[13])
        XCTAssertEqual("FizzBuzz", fizzBuzz[14])
        XCTAssertEqual("16",       fizzBuzz[15])
    }
    
    func testLazySequence() {
        var yieldCount = 0
        var yielderComplete = false
        
        let seq: SequenceOf<Int> = lazySequence { yield in
            ++yieldCount
            yield(1)
            
            ++yieldCount
            yield(2)
            
            ++yieldCount
            yield(3)
            
            yielderComplete = true
        }
        
        var gen = seq.generate()
        XCTAssertEqual(0, yieldCount, "yield should not be called until next()")
        XCTAssertFalse(yielderComplete)
        
        let val1 = gen.next()
        XCTAssertEqual(1, val1!)
        XCTAssertEqual(2, yieldCount, "should be blocked on second yield call")
        XCTAssertFalse(yielderComplete)
        
        let val2 = gen.next()
        XCTAssertEqual(2, val2!)
        XCTAssertEqual(3, yieldCount, "should be blocked on third yield call")
        XCTAssertFalse(yielderComplete)
        
        let val3 = gen.next()
        XCTAssertEqual(3, val3!)
        XCTAssertTrue(yielderComplete, "should have run to completion")
        
        let val4 = gen.next()
        XCTAssertNil(val4, "should have no more values")
    }
    
    func testDeckOfCards() {
        let suits = ["Clubs", "Diamonds", "Hearts", "Spades"]
        let ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King", "Ace"]
        let seq: SequenceOf<String> = lazySequence { yield in
            for suit in suits {
                for rank in ranks {
                    yield("\(rank) of \(suit)")
                }
            }
        }
        
        let deck = Array<String>(seq)
        XCTAssertEqual(52, deck.count)
        
        XCTAssertEqual("2 of Clubs",     deck[0])
        XCTAssertEqual("3 of Clubs",     deck[1])
        
        XCTAssertEqual("Ace of Clubs",   deck[12])
        XCTAssertEqual("2 of Diamonds",  deck[13])
        
        XCTAssertEqual("King of Spades", deck[50])
        XCTAssertEqual("Ace of Spades",  deck[51])
    }
    
    func testAsyncReadFileByLine() {
        
        // Return a lazily evaluated sequence of lines read from specified file
        func getLinesFromUTF8EncodedTextFileAtPath(path: NSString) -> SequenceOf<String> {
            
            // Determine length of null-terminated UTF8 string buffer
            func UTF8StringLength(var charPointer: UnsafePointer<CChar>) -> Int {
                var length = 0
                while charPointer.memory != 0 {
                    ++length
                    charPointer = charPointer.succ()
                }
                return length
            }
            
            // Read line from file. Returns line, or nil if at end-of-file
            func readLineFromFile(file: UnsafePointer<FILE>) -> String? {
                var buffer = Array<CChar>(count: 4096, repeatedValue: 0)
                let lineBytes = fgets(&buffer, CInt(buffer.count), file)
                if lineBytes {
                    let length = UTF8StringLength(lineBytes)
                    let string = NSString(bytes: lineBytes, length: length, encoding: NSUTF8StringEncoding)
                    return string
                }
                else {
                    return nil
                }
            }
            
            return lazySequence { yield in
                let file = fopen(path.UTF8String, "r")
                while let line = readLineFromFile(file) {
                    yield(line)
                }
                fclose(file)
            }
        }

        // Use TestData.txt resource from test bundle
        let testBundle = NSBundle(forClass: KJYieldTests.self)
        let testDataPath: NSString! = testBundle.pathForResource("TestData", ofType: "txt")
        
        let lines = getLinesFromUTF8EncodedTextFileAtPath(testDataPath)
        var lineNumber = 0
        for line in lines {
            ++lineNumber
            
            switch (lineNumber) {
            case 1:
                XCTAssertEqual("1. First Line\n", line)
            case 2:
                XCTAssertEqual("2. Second Line\n", line)
            case 3:
                XCTAssertEqual("3. Third Line\n", line)
            case 4:
                XCTAssertEqual("4. Fourth Line\n", line)
            default:
                XCTFail("unexpected input line: \(line)")
            }
        }
    }
    
    func testTokenizeAndParse() {
        
        // This is a simple Reverse Polish Notation (RPN) calculator.
        //
        // Input tokens consist of the following:
        //
        // - <sequence of numeric characters>: integer value, which is pushed onto the RPN stack
        // - "+": pops two integers from the stack, adds them, and pushes the sum on the stack
        // - "*": pops two integers from the stack, multiplies them, and pushes the product on the stack
        // - "=": pops an integer from the stack and produces it as a result
        //
        // All other input characters are ignored.
        //
        // The implementation uses two lazy sequences:
        //
        // - The tokenizer reads a sequence of characters to lazily produce a sequence of tokens
        // - The parser reads the sequence of tokens to lazily produce a sequence of expression results
        //
        // This use of two sequences makes it easy to keep the tokenizer's state machine separate
        // from the parser's state machine without tokenizing the entire input before passing it to
        // the parser. (The tokenizer and parser run on separate background threads.)
        //
        // This test simply parses a string, but this could be combined with code from testAsyncReadFileByLine()
        // to add another layer of lazy evaluation.
        
        enum Token {
            case Integer(Int)
            case Multiply
            case Plus
            case GetResult
        }
        
        struct Stack<T> {
            var values = Array<T>()
            
            mutating func push(value: T) {
                values.append(value)
            }
            
            mutating func pop() -> T {
                return values.removeLast()
            }
        }
        
        // Returns sequence of tokens read from character sequence
        func tokenize(characters: SequenceOf<Character>) -> SequenceOf<Token> {
            enum State {
                case LookingForToken
                case ScanningInteger
            }
            
            return lazySequence { yield in
                var state = State.LookingForToken
                var scannedIntegerDigits = ""
                
                func yieldScannedInteger() {
                    yield(.Integer(scannedIntegerDigits.bridgeToObjectiveC().integerValue))
                }
                
                for ch in characters {
                    switch ch {
                    
                    // For a numeric digit, start parsing integer or add on to one we're already parsing
                    case "0", "1", "2", "3", "4", "5", "6", "7", "8", "9":
                        switch state {
                        case .LookingForToken:
                            state = .ScanningInteger
                            scannedIntegerDigits = String(ch)
                        case .ScanningInteger:
                            scannedIntegerDigits = scannedIntegerDigits + ch
                        }
                    
                    // For other characters, yield the integer if we were scanning one,
                    // then yield appropriate new token or ignore character
                    default:
                        if state == .ScanningInteger {
                            yieldScannedInteger()
                            state = .LookingForToken
                        }
                        
                        switch ch {
                            
                        case "+":
                            yield(.Plus)
                        
                        case "*":
                            yield(.Multiply)
                        
                        case "=":
                            yield(.GetResult)
                        
                        default:
                            break
                        }
                    }
                }
                
                // If we were parsing an integer when the input ended, yield it
                if state == .ScanningInteger {
                    yieldScannedInteger()
                    state = .LookingForToken
                }
            }
        }
        
        func evaluateRPN(characters: SequenceOf<Character>) -> SequenceOf<Int> {
            return lazySequence { yield in
                var stack = Stack<Int>()
                for token in tokenize(characters) {
                    switch token {
                        
                    case .Integer(let value):
                        stack.push(value)
                        
                    case .Plus:
                        let a = stack.pop()
                        let b = stack.pop()
                        stack.push(a + b)
                        
                    case .Multiply:
                        let a = stack.pop()
                        let b = stack.pop()
                        stack.push(a * b)
                        
                    case .GetResult:
                        let result = stack.pop()
                        yield(result)
                    }
                }
            }
        }
        
        // Auxiliary function to convert a String to a sequence of character values
        func evaluateRPNString(string: String) -> SequenceOf<Int> {
            return evaluateRPN(SequenceOf(string.generate()))
        }
        
        // Should generate the results [3, 200, 30] (1+2, 10*20, (1+2)*10)
        let results = evaluateRPNString("1 2 + =  10 20 * =  1 2 + 10 * =")
        
        let resultsArray = Array<Int>(results)
        XCTAssertEqual(3, resultsArray.count)
        XCTAssertEqual(3, resultsArray[0])
        XCTAssertEqual(200, resultsArray[1])
        XCTAssertEqual(30, resultsArray[2])
    }
    
    func testEmptySequence() {
        let array = Array<String>(sequence { yield in return })
        
        XCTAssertTrue(array.isEmpty)
    }
    
    func testEmptyLazySequence() {
        let array = Array<String>(lazySequence { yield in return })
        
        XCTAssertTrue(array.isEmpty)
    }
}
