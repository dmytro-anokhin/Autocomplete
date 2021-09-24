# SwiftUI autocomplete using async/await and actors

With [Swift 5.5 released](https://swift.org/blog/swift-5-5-released/) I want to offer a look how new [concurrency](https://docs.swift.org/swift-book/LanguageGuide/Concurrency.html) model can be used to create autocomplete feature in SwiftUI.

// I assume you already know what async/await is. We will focus on how to use it in practice.
// [async/await](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md)

---

Before we start, here is the problem: we have an app that can show information about a city; user types city in a `TextField` and we want to offer autocomplete suggestions.

This is our UI.

<img src="https://user-images.githubusercontent.com/5136301/134250533-0c20f55c-b1b2-4b0b-9d57-8036d77cfb4b.png" data-canonical-src="https://user-images.githubusercontent.com/5136301/134250533-0c20f55c-b1b2-4b0b-9d57-8036d77cfb4b.png" width="375"/>

SwiftUI code hardcodes suggestions for a prototype. Our goal is to make it work.

```swift
struct ContentView: View {

    private var suggestions = ["Amstelveen", "Amsterdam", "Amsterdam-Zuidoost", "Amstetten"]

    @State var input: String = ""

    var body: some View {
        VStack {
            TextField("", text: $input)
                .textFieldStyle(.roundedBorder)
                .padding()
        }
        List(suggestions, id: \.self) { suggestion in
            ZStack {
                Text(suggestion)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}
```

---

Suggestions can come from a server or bundled with the app. For simplicity, in the example we store suggestions as a plain text (`cities` file), where each city name separated with a newline.

```
...
Amstelveen
Amsterdam
Amsterdam-Zuidoost
Amstetten
...
```

To load the file in memory we use `CitiesSource` protocol and `CitiesFile` object that implements it. You may choose not to declare a protocol and use an object directly. But I find that having a protocol creates simple to understand abstraction, further useful for unit testing.

```swift
protocol CitiesSource {

    func loadCities() -> [String]
}

struct CitiesFile: CitiesSource {

    /// Location of the file to load
    let location: URL

    init(location: URL) {
        self.location = location
    }

    /// Looks up for `cities` file in the main bundle
    init?() {
        guard let location = Bundle.main.url(forResource: "cities", withExtension: nil) else {
            assertionFailure("cities file is not in the main bundle")
            return nil
        }

        self.init(location: location)
    }

    func loadCities() -> [String] {
        do {
            let data = try Data(contentsOf: location)
            let string = String(data: data, encoding: .utf8)
            return string?.components(separatedBy: .newlines) ?? []
        }
        catch {
            return []
        }
    }
}
```

Next we need to build a cache. In our example `CitiesCache` keeps the complete list of cities in-memory. For a real app you should consider creating something smarter. We, instead, focus on concurrency. A good cache should be thread-safe. This is where new Swift concurrency model comes to life. 

`CitiesCache` is an `actor`. [Actor](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md) protects its own data, ensuring that only a single thread will access that data at a given time. Precisely what we need.

```swift
actor CitiesCache {

    let source: CitiesSource

    init(source: CitiesSource) {
        self.source = source
    }

    var cities: [String] {
        if let cities = cachedCities {
            return cities
        }

        let cities = source.loadCities()
        cachedCities = cities

        return cities
    }

    private var cachedCities: [String]?
}
```

`CitiesCache` stores the list of cities in `cachedCities`, loaded lazily on first access to computed `cities` property.

Cache lookup is a straight forward enumeration comparing prefixes. In the example we only do case-insensitive comparison. The real app may want more greedy algorithm.

```swift
extension CitiesCache {

    func lookup(prefix: String) -> [String] {
        let lowercasedPrefix = prefix.lowercased()
        return cities.filter { $0.lowercased().hasPrefix(lowercasedPrefix) }
    }
}
```

Notice a thing: so far there is not a line of synchronization code that we wrote. Actors allow only one task to access their state at a time. So we don't need to worry about.

---

Pieces are almost ready to connect. One small autocomplete feature to consider is a slight delay between user input and autocomplete routine, to limit number of calls. This is especially useful if autocomplete extensively uses I/O, like database lookup or sending network requests.

`AutocompleteObject` object implements autocomplete and notifies SwiftUI using `@Published var suggestions: [String]` property. To execute autocomplete asynchronously we use [`Task`](https://developer.apple.com/documentation/swift/task), new in Swift Standard Library. A `Task` can execute concurrent routines and supports cancellation.

You can also notice that `AutocompleteObject` uses [`@MainActor`](https://developer.apple.com/documentation/swift/mainactor) to always execute its code on the main thread.

Important that asyncronous calls, such as `Task.sleep` to add delay, and using `CitiesCache` actor, are marked with `await`. What it does, is indicates that the routine must stop and wait for asynchronous subroutine (marked with `async` keyword) to complete. You may previously used semaphores or `asyncAndWait` in GCD to achieve similar behaviour. The difference is that `await` won't block calling thread and simply return execution when `async` subroutine completes. Even that `AutocompleteObject` always uses the main thread, `await Task.sleep`  won't block it.

```swift
@MainActor
final class AutocompleteObject: ObservableObject {

    let delay: TimeInterval = 0.3

    @Published var suggestions: [String] = []

    init() {
    }

    private let citiesCache = CitiesCache(source: CitiesFile()!)

    private var task: Task<Void, Never>?

    func autocomplete(_ text: String) {
        guard !text.isEmpty else {
            suggestions = []
            task?.cancel()
            return
        }

        task?.cancel()

        task = Task {
            await Task.sleep(UInt64(delay * 1_000_000_000.0))

            guard !Task.isCancelled else {
                return
            }

            let newSuggestions = await citiesCache.lookup(prefix: text)

            if isSuggestion(in: suggestions, equalTo: text) {
                // Do not offer only one suggestion same as the input
                suggestions = []
            } else {
                suggestions = newSuggestions
            }
        }
    }

    private func isSuggestion(in suggestions: [String], equalTo text: String) -> Bool {
        guard let suggestion = suggestions.first, suggestions.count == 1 else {
            return false
        }

        return suggestion.lowercased() == text.lowercased()
    }
}
```

---

The final solution looks this.

```swift
struct ContentView: View {

    @ObservedObject private var autocomplete = AutocompleteObject()

    @State var input: String = ""

    var body: some View {
        VStack {
            TextField("", text: $input)
                .textFieldStyle(.roundedBorder)
                .padding()
                .onChange(of: input) { newValue in
                    autocomplete.autocomplete(input)
                }
        }
        List(autocomplete.suggestions, id: \.self) { suggestion in
            ZStack {
                Text(suggestion)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .onTapGesture {
                input = suggestion
            }
        }
    }
}
```

I hope you find this example useful.
