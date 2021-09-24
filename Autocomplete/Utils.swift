//
//  Utils.swift
//  Autocomplete
//
//  Created by Dmytro Anokhin on 24/09/2021.
//

extension String {

    func hasCaseAndDiacriticInsensitivePrefix(_ prefix: String) -> Bool {
        guard let range = self.range(of: prefix, options: [.caseInsensitive, .diacriticInsensitive]) else {
            return false
        }

        return range.lowerBound == startIndex
    }
}
