KJYield
=======

This Swift library provides "yield" functionality intended to be similar to that provided by Python's [generators](http://legacy.python.org/dev/peps/pep-0255/) and [generator expressions](http://legacy.python.org/dev/peps/pep-0289/) or F#'s [sequence expressions](http://msdn.microsoft.com/en-us/library/dd233209.aspx).


For example, you can generate an array with the values `[3, 6, 9, 12, 15, 18]` like this:

    let array = Array<Int>(sequence { yield in
        for n in 1...6 { yield(n * 3) }
    })

You can use `lazy_sequence` to create a sequence whose generator closure is executed on a background thread, and which blocks on each `yield()` until the main thread calls `next()` to consume the value.  For example, you could do something like this to process all lines of a file as a sequence without reading the entire file into memory at once:

    let lines: SequenceOf<String> = lazy_sequence { yield in
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

See the `KJYieldTests.swift` file for more examples.
