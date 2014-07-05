KJYield
=======

This Swift library provides "yield" functionality intended to be similar to that provided by Python's [generators](http://legacy.python.org/dev/peps/pep-0255/) and [generator expressions](http://legacy.python.org/dev/peps/pep-0289/) or F#'s [sequence expressions](http://msdn.microsoft.com/en-us/library/dd233209.aspx).


For example, you can generate an array with the values `[3, 6, 9, 12, ..., 27, 30]` like this:

```swift
let array = Array<Int>(sequence { yield in
    for n in 1...10 { yield(n * 3) }
})
```

You can use `lazySequence` to create a sequence whose generator closure is executed on a background thread, and which blocks on each `yield()` until the main thread calls `next()` to consume the value.  For example, you could do something like this to process all lines of a file as a sequence without reading the entire file into memory at once:

```swift
let lines: SequenceOf<String> = lazySequence { yield in
    let file = openInputFile()
    while true {
        if let line = readLineFromFile(file) {
            yield(line)
        }
        else {
            break
        }
    }
    closeFile(file)
}

for line in lines {
    processLine(line)
}
```

See the unit tests in [KJYieldTests.swift](https://github.com/kristopherjohnson/KJYield/blob/master/KJYieldTests/KJYieldTests.swift) for more examples.

Note: One limitation of `lazySequence` is that one must enumerate the entire sequence (that is, one must ensure that the generator `next()` method is called until it returns `nil`). If a lazy sequence is left partially unenumerated, memory and GCD objects will be leaked. This implies that infinite sequences are not supported.
