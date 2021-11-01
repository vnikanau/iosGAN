//
//  DGSettingsViewController.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 9/17/20.
//

import UIKit

class DGSettingsViewController: UIViewController {

    @IBOutlet weak var tfUserName: UITextField!
    @IBOutlet weak var tfPassword: UITextField!
    @IBOutlet weak var tfURL: UITextField!


    private var _userNameObserver: NSKeyValueObservation!
    private var _passwordObserver: NSKeyValueObservation!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // TODO: Retrieve Settings
        let manager = DGSettingsManager.shared

        tfUserName.text = manager.userName
        tfPassword.text = manager.password
        tfURL.text = manager.url?.absoluteString

        _userNameObserver = tfUserName.observe(\.text) { [self] (label, change) in
            let manager = DGSettingsManager.shared
            manager.userName = tfUserName.text ?? ""
            tfURL.text = manager.url?.absoluteString
        }

        _passwordObserver = tfPassword.observe(\.text) { [self] (label, change) in
            let manager = DGSettingsManager.shared
            manager.password = tfPassword.text ?? ""
            tfURL.text = manager.url?.absoluteString
        }

    }


    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        updateSettings()
    }

    // MARK: - Actions

    @IBAction func btnSavePressed(_ sender: UIBarButtonItem) {
        updateSettings()
    }


    // MARK: - Private

    private func updateSettings() {

        guard let url = URL(string: tfURL.text!) else {
            return
        }

        let manager = DGSettingsManager.shared
        manager.userName = tfUserName.text ?? ""
        manager.password = tfPassword.text ?? ""
        manager.url = url
        manager.save()

    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

}
