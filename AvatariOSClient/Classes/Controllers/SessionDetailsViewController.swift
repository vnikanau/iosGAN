//
//  SessionDetailsViewController.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 9/9/20.
//

import UIKit

class SessionDetailsViewController: UIViewController {

    @IBOutlet weak var tfModelName: UITextField!
    @IBOutlet weak var lbProcessed: UILabel!
    @IBOutlet weak var lbUploaded: UILabel!
    @IBOutlet weak var lbModelName: UILabel!
    @IBOutlet weak var lbModelDesciption: UILabel!
    @IBOutlet weak var lbNoSessionsFound: UILabel!
    @IBOutlet weak var ivPreview: UIImageView!

    @IBOutlet weak var btnUpdate: UIButton!
    @IBOutlet weak var btnUpload: UIButton!
    @IBOutlet weak var btnPreview: UIButton!

    @IBOutlet weak var tvDetails: UITextView!

    var session: Session? {
        didSet {
            refreshUI()
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        btnUpdate.isExclusiveTouch = true
        btnUpload.isExclusiveTouch = true
        btnPreview.isExclusiveTouch = true

        tvDetails.layer.borderWidth = 1.0
        tvDetails.layer.cornerRadius = 5.0
        tvDetails.layer.borderColor = UIColor.darkGray.cgColor

        tfModelName.layer.borderWidth = 1.0
        tfModelName.layer.cornerRadius = 5.0
        tfModelName.layer.borderColor = UIColor.darkGray.cgColor

        hideControls()
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: - Actions

    func btnUpdatePressed(asender: UIButton) {
        print("Update")
    }

    func btnUploadPressed(asender: UIButton) {
        print("Upload")
    }

    func btnPreviewPressed(asender: UIButton) {
        print("Preview")
    }

    // MARK: - Private
    private func refreshUI() {
//        loadViewIfNeeded()

        if session != nil {
            showControls()

            guard let sess = session else {
                print("No session information")
                return
            }

            let name = sess.modelName ?? "Untitled"
            tfModelName.text = name
            self.title = name
            tvDetails.text = sess.modelDescription
            lbProcessed.text = "Processeded: \(sess.processed ? "YES" : "NO")"
            lbUploaded.text = "Uploaded: \(sess.uploaded ? "YES" : "NO")"

            let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            if sess.path != nil {


                let imageURL = documentDirectory.appendingPathComponent("\(sess.modelId!)")
                    .appendingPathComponent("preview.png")
                let img = UIImage(contentsOfFile: imageURL.path)
                ivPreview.image = img
            }

            btnPreview.isEnabled = sess.uploaded
            btnUpload.isEnabled = sess.processed



        } else {
            hideControls()
        }

    }

    private func showControls() {
        lbNoSessionsFound.isHidden = true

        lbModelName.isHidden = false
        tfModelName.isHidden = false
        lbModelDesciption.isHidden = false
        tvDetails.isHidden = false
        lbProcessed.isHidden = false
        lbUploaded.isHidden = false
        ivPreview.isHidden = false

        btnUpdate.isHidden = false
        btnUpload.isHidden = false
        btnPreview.isHidden = false

    }

    private func hideControls() {

        lbNoSessionsFound.isHidden = false

        lbModelName.isHidden = true
        tfModelName.isHidden = true
        lbModelDesciption.isHidden = true
        tvDetails.isHidden = true
        lbProcessed.isHidden = true
        lbUploaded.isHidden = true
        ivPreview.isHidden = true
        btnUpdate.isHidden = true
        btnUpload.isHidden = true
        btnPreview.isHidden = true

    }
}

extension SessionDetailsViewController : SessionsViewControllerSelectionDelegate {

    func sessionDidSelect(_ aSession: Session) {
        session = aSession
    }
}
