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

    private let citiesCache = CitiesCache()

    func autocomplete(_ text: String) {
        guard !text.isEmpty else { // Check if text is empty or current suggestions already contain it
            suggestions = []
            autocompleteTask?.cancel()
            return
        }

        isUpdating = true
        autocompleteTask?.cancel()

        autocompleteTask = Task {
            await Task.sleep(UInt64(0.3 * 1_000_000_000.0))

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
