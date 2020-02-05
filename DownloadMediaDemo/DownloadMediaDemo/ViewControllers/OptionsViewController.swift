//
//  OptionsViewController.swift
//  DownloadMediaDemo
//
//  Created by Sezorus
//  Copyright © 2018 Sezorus. All rights reserved.
//

import UIKit

class OptionsViewController: UITableViewController {

    // MARK: - UITableViewDelegate & UITableViewDataSource

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "CellIdentifier", for: indexPath)
        
        switch indexPath.row {
        case 0: cell.textLabel?.text = "Simple Export"
        case 1: cell.textLabel?.text = "Simple Resouce Loader"
        default: break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        var segueIdentifier = "SimpleExport"
        switch indexPath.row {
        case 1: segueIdentifier = "SimpleResourceLoader"
        default: break
        }
        
        self.performSegue(withIdentifier: segueIdentifier, sender: nil)
    }
    
}
