//
//  ContentView.swift
//  Autocomplete
//
//  Created by Dmytro Anokhin on 21/09/2021.
//

import SwiftUI

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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
