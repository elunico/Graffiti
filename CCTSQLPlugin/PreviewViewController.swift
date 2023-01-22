//
//  PreviewViewController.swift
//  CCTSQLPlugin
//
//  Created by Thomas Povinelli on 1/20/23.
//

import Cocoa
import Quartz

class PreviewViewController: NSViewController, QLPreviewingController {
    
    @IBOutlet var dirLabel: NSTextField!
    
    @IBOutlet weak var table: NSTableView!
    
    let source: GraffitiQLTableViewSource = GraffitiQLTableViewSource()
    
    override var nibName: NSNib.Name? {
        return NSNib.Name("PreviewViewController")
    }
    
    override func loadView() {
        super.loadView()
        table.delegate = self
        table.dataSource = self
        
        // Do any additional setup after loading the view.
    }
    
    /*
     * Implement this method and set QLSupportsSearchableItems to YES in the Info.plist of the extension if you support CoreSpotlight.
     *
     func preparePreviewOfSearchableItem(identifier: String, queryString: String?, completionHandler handler: @escaping (Error?) -> Void) {
     // Perform any setup necessary in order to prepare the view.
     
     // Call the completion handler so Quick Look knows that the preview is fully loaded.
     // Quick Look will display a loading spinner while the completion handler is not called.
     handler(nil)
     }
     */
    
    var data: [(String, Set<Tag>)]? = nil
    
    func preparePreviewOfFile(at url: URL, completionHandler handler: @escaping (Error?) -> Void) {
        
        // Add the supported content types to the QLSupportedContentTypes array in the Info.plist of the extension.
        
        // Perform any setup necessary in order to prepare the view.
        
        // Call the completion handler so Quick Look knows that the preview is fully loaded.
        // Quick Look will display a loading spinner while the completion handler is not called.
        dirLabel.stringValue = url.absolutePath
        data = try? CompressedCustomTagStoreWriter().loadFrom(path: url.absolutePath).tagData.map { (key, value) in (key, value) }
        table.reloadData()
        handler(nil)
    }
    
}

extension PreviewViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return data?.count ?? 0
    }
    
}

extension PreviewViewController: NSTableViewDelegate {
    
    enum CellIdentifiers {
        static let fileNameCell = "Filename"
        static let kindCell = "Kind"
        static let tagsCell = "Tags"
        static let countCell = "Count"
        
        static func forColumn(withIndex index: Int) -> String {
            switch index {
            case 0:
                return fileNameCell
            case 1:
                return kindCell
            case 2:
                return tagsCell
            case 3:
                return countCell
            default:
                fatalError("Too many table columns")
            }
        }
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        var text: String = ""
        var cellIdentifier: String = ""
        
        // 1
        guard let item = data?[row] else {

            return nil
        }
        
        for (index, column) in tableView.tableColumns.enumerated() {
            if tableColumn == column {
                cellIdentifier = CellIdentifiers.forColumn(withIndex: index)
                switch index {
                case 0:
                    text = (item.0 as NSString).lastPathComponent
                case 1:
                    text = (item.0 as NSString).pathExtension
                case 2:
                    text = item.1.map{ $0.value }.joined(separator: ", ")
                case 3:
                    text = item.1.count.description
                default:
                    fatalError()
                }
            }
        }
        
        // 3
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            cell.textField?.stringValue = text
            return cell
        }
        return nil
    }
    
}
