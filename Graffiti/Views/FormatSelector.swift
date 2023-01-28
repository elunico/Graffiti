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
    
        
    @State var options: [Format: FormatOption] = [
        .csv: FormatOption(format: .csv, name: "CSV File", description: "Saves all tags of all files in a directory to a single CSV file also placed in that directory"),
        .plist: FormatOption(format: .plist , name: "Property List File", description: "Saves all tags of all files in a directory to a single (binary) Property List file also placed in that directory"),
        .json: FormatOption(format: .json, name: "JSON File", description: "Saves all tags of all files in a directory to a single JSON file also placed in that directory"),
        .ccts: FormatOption(format: .ccts, name: "Custom Compressed Tag Store File", description: "Saves all tags of all files in a directory to a single custom compressed binary format meant to make efficient use of space at the cost of compatibility with external editors"),
        .xattr: FormatOption(format: .xattr, name: "Extended File Attributes", description: "Saves all tags of each files as extended attributes (xattr) of that file. The file retains its tags even when moved"),
        ]
    
    func removing(formatOption option: Format) -> FormatSelector {
        let this = self
        this.options.removeValue(forKey: option)
        return this
    }
    
    var body: some View {
        VStack {
            
            Picker("", selection: $formatChoice, content: {
                
                    ForEach(Array(options.values), content: { option in
                        Text(option.name).tag(option.format).help(option.description)
                    })
                
            })
            .pickerStyle(RadioGroupPickerStyle())
            .frame(minWidth: 200.0, maxWidth: 300.0)
            .padding()
            
        }
    }
}
