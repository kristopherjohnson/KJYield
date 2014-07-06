KJYield
=======

This Swift library provides "yield" functionality intended to be similar to that provided by Python's [generators](http://legacy.python.org/dev/peps/pep-0255/) and [generator expressions](http://legacy.python.org/dev/peps/pep-0289/) or F#'s [sequence expressions](http://msdn.microsoft.com/en-us/library/dd233209.aspx).

The library provides two generic functions with these signatures:

```swift
func sequence<T>(yielder: ((T) -> ()) -> ()) -> SequenceOf<T>

func lazySequence<T>(yielder: ((T) -> ()) -> ()) -> SequenceOf<T>
```

The type _T_ is the type of the elements in the generated sequence. The `yielder` argument is a closure that takes a function, `yield(T)`, that can be called within the closure to add a value to the generated sequeence.

The typical pattern for using the functions looks like this:

```swift
// Generate a sequence of T
let seq: SequenceOf<T> = sequence { yield in
    // statements that call yield(T)
}
```

or like this:

```swift
// Generate a collection of T
let array = Array<T>(sequence { yield in
    // statements that call yield(T)
})
```

For example, you can generate an array with the values `[3, 6, 9, 12, ..., 27, 30]` like this:

```swift
let array = Array<Int>(sequence { yield in
    for n in 1...10 { yield(n * 3) }
})
```

Or you can generate a Fibonacci sequence like this:

```swift
// Produce first 20 elements of Fibonacci sequence
let fibSequence = Array<Int>(sequence { yield in
    var a = 0, b = 1
    for _ in 0..20 {
        yield(b)
        let sum = a + b
        a = b
        b = sum
    }
})
```

Or you can generate a deck of playing cards like this:

```swift
let suits = ["Clubs", "Diamonds", "Hearts", "Spades"]
let ranks = ["2", "3", "4", "5", "6", "7", "8", "9", "10", "Jack", "Queen", "King", "Ace"]
let deckOfCards: SequenceOf<String> = lazySequence { yield in
    for suit in suits {
        for rank in ranks {
            yield("\(rank) of \(suit)")
        }
    }
}
for card in deckOfCards {
    println("Next card: \(card)")
}
```

The `sequence` function immediately evaluates the expressions. The `lazySequence` function executes the expressions on background thread, and each call to `yield()` until the main thread calls `next()` to consume the value.  For example, you could do something like this to process all lines of a file as a sequence without reading the entire file into memory at once:

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
