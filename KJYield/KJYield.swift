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

import Foundation

// Generates values from a closure that invokes a "yield" function
public struct YieldGenerator<T>: GeneratorType {
    private var yieldedValues = Array<T>()
    private var index = 0
    
    private mutating func yield(value: T) {
        yieldedValues.append(value)
    }
    
    public init(_ yielder: ((T) -> ()) -> ()) {
        yielder(yield)
    }
    
    public mutating func next() -> T? {
        return index < yieldedValues.count ? yieldedValues[index++] : nil
    }
}

// Background task used by LazyYieldGenerator
//
// (This should be a nested class of LazyYieldGenerator, but the Xcode 6 Beta 2 editor freaks out.)
class LazyYieldTask<T> {
    private let _yielder: ((T) -> ()) -> ()
    private let _semValueDesired: dispatch_semaphore_t
    private let _semValueAvailable: dispatch_semaphore_t
    private let _syncQueue: dispatch_queue_t
    
    private var _lastYieldedValue = Array<T>()
    private var _isBackgroundTaskRunning = false
    private var _isComplete = false
    
    public init(_ yielder: ((T) -> ()) -> ()) {
        _yielder = yielder
        
        _semValueDesired = dispatch_semaphore_create(0)
        _semValueAvailable = dispatch_semaphore_create(0)
        
        // TODO: analyze whether this queue is necessary.
        // The semaphores may be enough to ensure proper synchronization.
        _syncQueue = dispatch_queue_create("LazyYieldTask syncQueue", DISPATCH_QUEUE_SERIAL)
    }
    
    // Called from background thread to yield a value to be returned by next()
    private func _yield(value: T) {
        dispatch_semaphore_wait(_semValueDesired, DISPATCH_TIME_FOREVER)
        dispatch_sync(_syncQueue) {
            self._lastYieldedValue = [value]
            dispatch_semaphore_signal(self._semValueAvailable)
        }
    }
    
    // Called from background thread to yield nil from next()
    private func _yieldNil() {
        dispatch_semaphore_wait(_semValueDesired, DISPATCH_TIME_FOREVER)
        dispatch_sync(_syncQueue) {
            self._lastYieldedValue = Array<T>()
            dispatch_semaphore_signal(self._semValueAvailable)
        }
    }
    
    // Called from generator thread to get next yielded value
    private func next() -> T? {
        if !_isBackgroundTaskRunning {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
                self.run()
            }
            _isBackgroundTaskRunning = true
        }
        
        dispatch_semaphore_signal(_semValueDesired)
        dispatch_semaphore_wait(_semValueAvailable, DISPATCH_TIME_FOREVER)
        
        var value: T? = nil
        dispatch_sync(_syncQueue) {
            if !self._lastYieldedValue.isEmpty {
                value = self._lastYieldedValue[0]
                self._lastYieldedValue = Array<T>()
            }
        }
        return value
    }
    
    // Executed in background thread
    private func run() {
        _yielder(_yield)
        _yieldNil()
    }
}

// Generates values from a closure that invokes a "yield" function.
//
// The yielder closure is executed on another thread, and each call to yield()
// will block until next() is called by the generator's thread.
public struct LazyYieldGenerator<T>: GeneratorType {
    private var _task: LazyYieldTask<T>?
    private let _yielder: ((T) -> ()) -> ()
    
    public init(_ yielder: ((T) -> ()) -> ()) {
        _yielder = yielder
    }
    
    public mutating func next() -> T? {
        if !(_task != nil) {
            _task = LazyYieldTask(_yielder)
        }
        
        return _task!.next()
    }
}


// Create a sequence from a closure that invokes a "yield" function
public func sequence<T>(yielder: ((T) -> ()) -> ()) -> SequenceOf<T> {
    return SequenceOf<T>({YieldGenerator(yielder)})
}

// Create a sequence from a closure that invokes a "yield" function.
//
// The closure is executed on another thread, and each call to yield()
// will block until next() is called by the generator's thread.
public func lazySequence<T>(yielder: ((T) -> ()) -> ()) -> SequenceOf<T> {
    return SequenceOf<T>({LazyYieldGenerator(yielder)})
}

