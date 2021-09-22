//
//  CitiesCache.swift
//  CitiesCache
//
//  Created by Dmytro Anokhin on 21/09/2021.
//

import Foundation


actor CitiesCache {

    var cities: [String] {
        get async {
            print("cities: \(Thread.current)")

            if let cities = cachedCities {
                return cities
            }

            let cities = await loadCities()
            cachedCities = cities

            return cities
        }
    }

    private var cachedCities: [String]?

    private func loadCities() async -> [String] {
        guard let location = Bundle.main.url(forResource: "cities", withExtension: nil) else {
            assertionFailure("cities file is not in the main bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: location)
            let string = String(data: data, encoding: .utf8)

            guard let cities = string?.components(separatedBy: .newlines), !cities.isEmpty else {
                assertionFailure("Can not parse cities file")
                return []
            }

            return cities
        }
        catch {
            print(error)
            return []
        }
    }
}


extension CitiesCache {

    func lookup(prefix: String) async -> [String] {
        let lowercasedPrefix = prefix.lowercased()
        return await cities.filter { $0.lowercased().hasPrefix(lowercasedPrefix) }
    }
}
