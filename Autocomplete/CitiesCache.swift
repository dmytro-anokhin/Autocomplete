//
//  CitiesCache.swift
//  CitiesCache
//
//  Created by Dmytro Anokhin on 21/09/2021.
//

import Foundation

protocol CitiesSource {

    func loadCities() async -> [String]
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

    func loadCities() async -> [String] {
        print("load cities thread: \(Thread.current)")
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

actor CitiesCache {

    let source: CitiesSource

    init(source: CitiesSource) {
        self.source = source
    }

    var cities: [String] {
        get async {
            if let cities = cachedCities {
                return cities
            }

            let cities = await source.loadCities()
            cachedCities = cities

            return cities
        }
    }

    private var cachedCities: [String]?
}


extension CitiesCache {

    func lookup(prefix: String) async -> [String] {
        print("lookup thread: \(Thread.current)")
        let lowercasedPrefix = prefix.lowercased()
        return await cities.filter { $0.lowercased().hasPrefix(lowercasedPrefix) }
    }
}
