//
//  CitiesCache.swift
//  CitiesCache
//
//  Created by Dmytro Anokhin on 21/09/2021.
//

import Foundation


actor CitiesCache {

    var cities: [String] {
        if let cities = cachedCities {
            return cities
        }

        let cities = loadCities()
        cachedCities = cities

        return cities
    }

    private var cachedCities: [String]?

    private func loadCities() -> [String] {
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
