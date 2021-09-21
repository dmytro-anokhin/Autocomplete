//
//  Autocomplete.swift
//  Autocomplete
//
//  Created by Dmytro Anokhin on 21/09/2021.
//

import Combine
import Foundation


@MainActor
final class AutocompleteObject: ObservableObject {

    @Published var isUpdating: Bool = false

    @Published var suggestions: [String] = []

    init() {
    }

    private var autocompleteTask: Task<Void, Never>?

    private let autocompleteActor = CitiesAutocomplete(delay: 1.0)

    func autocomplete(_ text: String) {
        guard !text.isEmpty else { // Check if text is empty or current suggestions already contain it
            suggestions = []
            autocompleteTask?.cancel()
            return
        }

        isUpdating = true
        autocompleteTask?.cancel()

        autocompleteTask = Task {
            let newSuggestions = await autocompleteActor.autocomplete(text)

            if isSuggestion(in: suggestions, equalTo: text) {
                // Do not offer only one suggestion same as the input
                suggestions = []
            } else {
                suggestions = newSuggestions
            }

            isUpdating = false
        }
    }

    private func isSuggestion(in suggestions: [String], equalTo text: String) -> Bool {
        guard let suggestion = suggestions.first, suggestions.count == 1 else {
            return false
        }

        return suggestion.lowercased() == text.lowercased()
    }
}

actor CitiesAutocomplete {

    let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func autocomplete(_ text: String) async -> [String] {
        await Task.sleep(UInt64(delay * 1_000_000_000.0))
        print(Thread.current)
        return Task.isCancelled ? [] : await performAutocomplete(text)
    }

    private let cache = CitiesCache()

    private func performAutocomplete(_ text: String) async -> [String] {
        let prefix = text.lowercased()
        return await cache.cities.filter { $0.lowercased().hasPrefix(prefix) }
    }
}
