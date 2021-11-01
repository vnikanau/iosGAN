//
//  SessionsViewController.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 9/9/20.
//

import UIKit
import CoreData

protocol SessionsViewControllerSelectionDelegate : class {
    func sessionDidSelect(_ session: Session)
}

class SessionsViewController: UITableViewController {

    private var _sessionManager: DGSessionManager? = nil
    weak var delegate: SessionsViewControllerSelectionDelegate?

    lazy var fetchedResultsController: NSFetchedResultsController<Session> = {
        // Request
        let fetchRequest = NSFetchRequest<Session>(entityName: "Session")
        // Sort
        let sortDescriptor = NSSortDescriptor(key:"date", ascending: false)
        fetchRequest.sortDescriptors = [sortDescriptor]

        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext

        let fetchedResultsController =
            NSFetchedResultsController(fetchRequest: fetchRequest,
                                       managedObjectContext: context,
                                       sectionNameKeyPath: nil, cacheName: nil)
        fetchedResultsController.delegate = self
        return fetchedResultsController
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
//         self.navigationItem.rightBarButtonItem = self.editButtonItem

        self.splitViewController?.delegate = self

        if UIDevice.current.userInterfaceIdiom == .phone {
            self.splitViewController?.preferredDisplayMode = .oneOverSecondary
        }


        do {
            _sessionManager = DGSessionManager.shared
            try fetchedResultsController.performFetch()
        } catch {
            print(error)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2;
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {

        if section == 0 {
            // Settings
            return 1
        } else {

            if let sections = fetchedResultsController.sections {
                return sections[section - 1].numberOfObjects
            } else {
                return 0
            }

        }

    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: "sessionCell", for: indexPath)

        if indexPath.section == 0 {
            cell.textLabel?.text = "Settings"
            cell.detailTextLabel?.text = ""
        } else {
            let newIndexPath = IndexPath(row: indexPath.row, section: indexPath.section - 1)
            let session = fetchedResultsController.object(at: newIndexPath)
            cell.textLabel?.text = session.modelName ?? "Unitiled"
            cell.detailTextLabel?.text = session.date?.description
        }


        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            // TODO: Push SettingsViewController
            self.performSegue(withIdentifier: "settingsSegue", sender: self)
        } else {
            let newIndexPath = IndexPath(row: indexPath.row, section: indexPath.section - 1)
            let session = fetchedResultsController.object(at: newIndexPath)
            delegate?.sessionDidSelect(session)
        }
    }

    // MARK: - 

    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    override func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {

        return indexPath.section != 0 ? UISwipeActionsConfiguration(actions: [
                    makeDeleteContextualAction(forRowAt: indexPath)
        ]) : nil
    }

    // MARK: - Actions
    @IBAction func btnNewSessionPressed(aSender: UIButton) {
        
    }

    // MARK: - Private
    func load() {

    }

    func makeDeleteContextualAction(forRowAt indexPath:IndexPath) -> UIContextualAction {
        return UIContextualAction(style: .destructive, title: "Delete") { (action, swipeButtonView, completion) in
            print("DELETE HERE")

            DispatchQueue.main.async { [self] in

                let newIndexPath = IndexPath(row: indexPath.row, section: indexPath.section-1)
                let session = fetchedResultsController.object(at: newIndexPath)

                _sessionManager?.deleteSession(session)

                completion(true)

            }
        }
    }

    // MARK: - Actions

    @IBAction func btnNewSessionPressed(_ sender: UIBarButtonItem) {

        let device = IDLDevice.shared
        
        if device.isLidarSupported {

            let alert = UIAlertController(title: "Choose a source", message: "Could you, please, select a camera", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: NSLocalizedString("TrueDepth camera", comment: "TrueDepth camera"), style: .default, handler: { _ in
                self.performSegue(withIdentifier: "trueDepthSessionSegue", sender: sender)
            }))
            alert.addAction(UIAlertAction(title: NSLocalizedString("LiDAR", comment: "LiDAR"), style: .default, handler: { _ in
                DispatchQueue.main.async {
                    self.performSegue(withIdentifier: "lidarSessionSegue", sender: sender)
                }
            }))

            self.present(alert, animated: true, completion: nil)

        } else {
        
            performSegue(withIdentifier: "trueDepthSessionSegue", sender: sender)
            
        }
        
    }
}

extension SessionsViewController : NSFetchedResultsControllerDelegate {
    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        self.tableView.reloadData()
    }
}

extension SessionsViewController : UISplitViewControllerDelegate {
    func splitViewController(_ splitViewController: UISplitViewController,
                             collapseSecondary secondaryViewController: UIViewController,
                             onto primaryViewController: UIViewController) -> Bool {
        return true
    }
}
