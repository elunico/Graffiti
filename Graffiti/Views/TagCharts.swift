//
//  TagCharts.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/17/23.
//

import SwiftUI
import Charts

func windows(from min: Int, to high: Int, count: Int) -> [(Int, Int)] {
    var max = high + (count - ((high - min) % count))
    var elementsPerWindow = Int(Double(max - min) / Double(count))
    var windows = [(Int, Int)]()
    
    var current = min
    for _ in 0..<(count - 1) {
        windows.append((current, current + elementsPerWindow - 1))
        current += elementsPerWindow
        
    }
    windows.append((current, max))
    return windows
}

func fileCount(files: [TaggedFile], inRange range: ClosedRange<Int>) -> Int {
    files.map { range.contains($0.tags.count) ? 1 : 0 }.reduce(0, +)
}

struct TagCharts: View {
    
    @EnvironmentObject var directory: TaggedDirectory
    
    
    @State var tabSelection: Int = 1
    var body: some View {
        let tags = directory.files.flatMap { $0.tags }
        let textTags = tags.filter { $0.image == nil }.count
        let imageTags = tags.filter { $0.image != nil }.count
        
        let maxTags = printing(directory.files.map { $0.tags.count }.max() ?? 0)
        
        let ranges = printing(windows(from: 0, to: maxTags, count: 10))
        
        
        TabView(selection: $tabSelection) {
            Chart {
                BarMark(x: .value("Tag Type", "Text"), y: .value("Number of Tags", textTags))
                BarMark(x: .value("Tag Type", "Images"), y: .value("Number of Tags", imageTags))
            }.padding()
                .tabItem {
                    Text("Tag Types")
                }
                .tag(1)
              
            Chart {
                ForEach(ranges, id: \.0) { item in
                    BarMark(x: .value("Count", "\(item.0)-\(item.1)"), y: .value("Files with Tags", fileCount(files: directory.files, inRange: item.0...item.1)))
                }
            }.padding()
                .tag(2)
                .tabItem {
                    Text("Tag Counts")
                }
            
        }
        
    }
}

struct TagCharts_Previews: PreviewProvider {
    static var previews: some View {
        TagCharts()
    }
}
