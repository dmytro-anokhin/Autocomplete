# Autocomplete

With [Swift 5.5 released](https://swift.org/blog/swift-5-5-released/) I want to offer a look how [async/await](https://github.com/apple/swift-evolution/blob/main/proposals/0296-async-await.md) can be used to create autocomplete feature in SwiftUI.

I assume you already know what async/await is. We will focus on how to use it in practice.

Before we start here is the problem. Say we have an app that can show information about a city. User types city in a `TextField` and we want to offer autocomplete suggestions. This is our UI.

<img src="https://user-images.githubusercontent.com/5136301/134250533-0c20f55c-b1b2-4b0b-9d57-8036d77cfb4b.png" data-canonical-src="https://user-images.githubusercontent.com/5136301/134250533-0c20f55c-b1b2-4b0b-9d57-8036d77cfb4b.png" width="375"/>

Suggestions can come from a server or bundled with the app. For simplicity, in the example we store suggestions as a plain text (`cities` file), where each city name separated by newline.

```
...
Amstelveen
Amsterdam
Amsterdam-Zuidoost
Amstetten
...
```

To load the file in memory we use `CitiesSource` protocol and `CitiesFile` object that implements it. You may choose not to declare a protocol, but I find it a nice and simple separation, useful for unit testing.

```swift
protocol CitiesSource {

    func loadCities() -> [String]
}

struct CitiesFile: CitiesSource {

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

Let's talk about caching. A good cache is thread safe. Cache is where `async/await` comes to life. 

`CitiesCache` loads and stores cities in memory. `CitiesCache` is an actor. [Actor](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md) protects its own data, ensuring that only a single thread will access that data at a given time. Precisely what we need for a cache.

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

    func lookup(prefix: String) async -> [String] {
        print("lookup thread: \(Thread.current)")
        let lowercasedPrefix = prefix.lowercased()
        return cities.filter { $0.lowercased().hasPrefix(lowercasedPrefix) }
    }
}

```

`CitiesCache` is an actor. [Actor](https://github.com/apple/swift-evolution/blob/main/proposals/0306-actors.md) protects its own data, ensuring that only a single thread will access that data at a given time. Precisely what we need for a cache.










You can notice that `loadCities` function is not creating secondary threads or queues, and returns when the file is loaded and processed. It's basically a synchronous routine. However, it is marked as `async` and will run asynchronously when called.

`cachedCities` property is used to store cities in memory and because `CitiesCache` is an actor it is protected from data races.

Now getting to the `cities` property. It's declared as `get async` to indicate that it must be called inside concurrent context. Internally it uses `loadCities` via `await` keyword, to execute it asynchronously.

Note, for this example using `async/await` on `loadCities` is not strictly necessary. Because `loadCities` is synchronous function and `cities` property


Next let's think how we want to use it. Good autocomplete mechanism must not disturb user interactions and should be lightweight. Not blocking the main thread comes without saying.

Good idea is to delay reaction a bit. Say when user enters word "Amsterdam", we can show results with a slight delay, when user takes a break to enter next character. This allows to display more precise results, when users need it. And reduce operations by cancelling previous, including I/O and networking if such take place.


```swift
actor CitiesAutocomplete {

    let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func autocomplete(_ text: String) async -> [String] {
        await Task.sleep(UInt64(delay * 1_000_000_000.0))
        return Task.isCancelled ? [] : await performAutocomplete(text)
    }

    private let cache = CitiesCache()

    private func performAutocomplete(_ text: String) async -> [String] {
        let prefix = text.lowercased()
        return await cache.cities.filter { $0.lowercased().hasPrefix(prefix) }
    }
}

```

Main interface here is `autocomplete(_:)` function that adds delay and performs heavy lookup only if the task want's cancelled.

Here we can see function marked as `async`, because they are executed concurrently. Also we're using `Task` - new in Swift 5.5.