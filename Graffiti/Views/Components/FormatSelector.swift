//
//  FormatSelector.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 1/25/23.
//

import SwiftUI

struct FormatOption {
    let format: Format
    let name: String
    let description: String
}

extension FormatOption: Identifiable {
    var id: Format { format }
}

struct FormatSelector: View {
    @Binding var formatChoice: Format
    
    
    var options: [Format: FormatOption] = [
        .ccts: FormatOption(format: .ccts, name: "Custom Compressed Tag Store File", description: "Saves all tags of all files in a directory to a single custom compressed binary format meant to make efficient use of space at the cost of compatibility with external editors"),
        .json: FormatOption(format: .json, name: "JSON File", description: "Saves all tags of all files in a directory to a JSON file. Useful for external editing or programmatic manipulation, but creates larger files")
    ]
    
    func removing(formatOption option: Format?) -> FormatSelector {
        guard let option else { return self }
        var this = self
        this.options.removeValue(forKey: option)
        return this
    }
    
    var body: some View {
        VStack {
            
            Picker("", selection: $formatChoice, content: {
                
                ForEach(Array(options.values).sorted(by: { a, b in a.description < b.description }), content: { option in
                    Text(option.name).tag(option.format).help(option.description)
                })
                
            })
            .pickerStyle(RadioGroupPickerStyle())
            .frame(minWidth: 200.0, maxWidth: 300.0)
            .padding()
            
        }
    }
}
