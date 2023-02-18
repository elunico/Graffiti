//
//  TagCharts.swift
//  Graffiti
//
//  Created by Thomas Povinelli on 2/17/23.
//

import SwiftUI
import Charts

extension Array {
    func windowed(into groups: Int) -> Array<Array<Element>> {
        if count < groups {
            return map { [$0] }
        }
        var result = [[Element]]()
        var elementsPerGroup = count / groups
        var extra = count % groups
        
        var currentGroup = [Element]()
        for elt in self {
            currentGroup.append(elt)
            if currentGroup.count == elementsPerGroup {
                result.append(currentGroup)
                currentGroup.removeAll(keepingCapacity: true)
            }
        }
        var a = result[result.endIndex - 1]
        a.append(contentsOf: Array(self[self.endIndex-1 - extra..<self.endIndex-1]))
        result[result.endIndex - 1] = a
        
        //        return (result, extra == 0 ? [] : Array(self[self.endIndex-1 - extra..<self.endIndex-1]))
        return result
    }
}

func fileCount(files: [TaggedFile], inRange range: Range<Int>) -> Int {
    files.map { range.contains($0.tags.count) ? 1 : 0 }.reduce(0, +)
}

func printing<T>(_ t: T) -> T {
    print(t)
    return t
}

struct TagCharts: View {
    
    @EnvironmentObject var directory: TaggedDirectory
    
    
    @State var tabSelection: Int = 1
    var body: some View {
        let tags = directory.files.flatMap { $0.tags }
        let textTags = tags.filter { $0.image == nil }.count
        let imageTags = tags.filter { $0.image != nil }.count
        
        let maxTags = printing(directory.files.map { $0.tags.count }.max() ?? 0)
        
        let ranges = printing(Array(0...maxTags).windowed(into: 10).map { ($0.first ?? 0, ($0.last ?? 0) + 1) })
        
        
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
                    BarMark(x: .value("Count", "\(item.0)-\(item.1)"), y: .value("Files with Tags", fileCount(files: directory.files, inRange: item.0..<item.1)))
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
