//
//  GraffitiQLTableViewSource.swift
//  CCTSQLPlugin
//
//  Created by Thomas Povinelli on 1/22/23.
//

import Cocoa

class GraffitiQLTableViewSource: NSObject, NSTableViewDataSource {
    var url: URL? = nil
    var data: [(String, Set<Tag>)]? = nil
    
    func set(url: URL) {
        self.url = url
        self.data = try? CompressedCustomTagStoreWriter().loadFrom(path: url.absoluteString).tagData.map { (key, value) in (key, value) }
        print(data)
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return data == nil ? 0 : data!.count
    }
    
    func tableView(
        _ tableView: NSTableView,
        objectValueFor tableColumn: NSTableColumn?,
        row: Int
    ) -> Any? {
        guard let c = data?[row] else { return nil }
        return tableColumn?.title == "filename" ? c.0 : c.1.description
    }
}
