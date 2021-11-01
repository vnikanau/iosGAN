//
//  ViewController.swift
//  DepthGrabber
//
//  Created by Andrei Kazialetski on 7/2/20.
//

import Foundation
import UIKit
import ARKit
import RealityKit

class Session: UIViewController {

    @IBOutlet var arView: ARView!
    @IBOutlet weak var btnStart: RoundedButton!
    @IBOutlet weak var btnExport: RoundedButton!
    @IBOutlet weak var btnReset: RoundedButton!
    @IBOutlet weak var ivAim: UIImageView!

    private var isActive = false
    private var configuration = ARWorldTrackingConfiguration()
    private let frameSkipValue = 6 // 60 / 15
    private var frameSkipCounter = 0
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let maxFrames = 400
    private var processedFrames = 0
    private var currentSession: Session? = nil
    private var intrinsics: [String] = []
    private let imgConverter = IDLImageConverter()
    private var camCalibration: DGCameraCalibration? = nil

    private var _sessionManager: DGSessionManager? = nil
    private var _isAllowCapture: Bool = false

    let coachingOverlay = ARCoachingOverlayView()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

        arView.session.delegate = self

        setupCoachingOverlay()

        arView.environment.sceneUnderstanding.options = []

        // Turn on occlusion from the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.occlusion)

        // Turn on physics for the scene reconstruction's mesh.
        arView.environment.sceneUnderstanding.options.insert(.physics)

        // Display a debug visualization of the mesh.
        arView.debugOptions.insert(.showSceneUnderstanding)
//        arView.debugOptions.insert(.showFeaturePoints)
//        arView.debugOptions.insert(.showWorldOrigin)
        arView.debugOptions.insert(.showAnchorOrigins)
        arView.debugOptions.insert(.showAnchorGeometry)

        // For performance, disable render options that are not required for this app.
        arView.renderOptions = [.disablePersonOcclusion, .disableDepthOfField, .disableMotionBlur]

        // Manually configure what kind of AR session to run
        arView.automaticallyConfigureSession = false

        configuration = ARWorldTrackingConfiguration()
        configuration.sceneReconstruction = .mesh
        configuration.environmentTexturing = .none
//        configuration.environmentTexturing = .automatic
//        configuration.wantsHDREnvironmentTextures = true
//        configuration.isAutoFocusEnabled = false

        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = .sceneDepth
        }

        _sessionManager = DGSessionManager.shared
        _sessionManager!.delegate = self

//        removeOldFiles()

//        let imgAim = UIImage(named: "imgAim")?.resizableImage(withCapInsets: UIEdgeInsets(top: 362, left: 274, bottom: 362, right: 274), resizingMode: .stretch)
//        ivAim.image = imgAim

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
    }


    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }


    override var prefersStatusBarHidden: Bool {
        return true
    }


    @IBAction func btnStartPressed(aSender: UIButton) {

//        showSessionDialog()


        if !isActive {
            isActive = true
            processedFrames = 0
//            removeOldFiles()
            createSession()
            arView.session.run(configuration)
            aSender.setTitle("Stop", for: .normal)
            print("start")

        } else {

            print("stop")

            stopSession()
            isActive = false
            arView.session.pause()

            if let configuration = arView.session.configuration {
                arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                [self] in

                arView.session.pause()
                aSender.setTitle("Start", for: .normal)

            }

        }
    }


    @IBAction func btnExportPressed(aSender: UIButton) {
        print("export")
    }

    @IBAction func resetButtonPressed(_ sender: Any) {

        print("reset")

        // TODO: Reset Active session

        if let configuration = arView.session.configuration {
            arView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors, .resetSceneReconstruction])
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            [self] in
            arView.session.pause()
        }
    }

    @IBAction func autoFocusButtonPressed(_ sender: UIButton) {

        if let configuration = arView.session.configuration as? ARWorldTrackingConfiguration {
            
            sender.isSelected = !sender.isSelected

            configuration.isAutoFocusEnabled = sender.isSelected
            arView.session.run(configuration, options: [])
            print("autofocus: \(configuration.isAutoFocusEnabled ? "yes" : "no")")
        } else {
            print("no session")
        }
    }

    // MARK: - Private methods

    func dump(anImage: CVPixelBuffer, atTimeStamp timeStamp: UInt64) {

        let data = imgConverter.convertYpCbCrToRGBData(aSource: anImage)

        // TODO: Check if local session and write locally
//        guard let session = currentSession else {
//            return
//        }
//        let filePath = session.path!.appendingPathComponent("\(timeStamp)_c.png")
//        try! data?.write(to: filePath, options: .atomicWrite)

        guard data != nil else {
            print("Failed to convert image data")
            return
        }

        _sessionManager!.sendImage(data!, atTimeStamp: timeStamp)

    }

    func dump(aDepth: CVPixelBuffer, atTimeStamp timeStamp: UInt64) {

        let data = imgConverter.convertDepthToData(aSource: aDepth)

        // TODO: Check if local session and write locally
//        guard let session = currentSession else {
//            return
//        }
//        let filePath = session.path!.appendingPathComponent("\(timeStamp)_d.png")
//        try! data?.write(to: filePath, options: .atomicWrite)

        guard data != nil else {
            print("Failed to convert depth data")
            return
        }

        _sessionManager!.sendDepth(data!, atTimeStamp: timeStamp)

    }

    func dump(aConfidence: CVPixelBuffer, atTimeStamp: UInt64) {

        guard let session = currentSession else {
            return
        }

        #if false
        let filePath = session.path!.appendingPathComponent("\(atTimeStamp)_conf.dat")

        CVPixelBufferLockBaseAddress(aConfidence, .readOnly)

        let dataSize = CVPixelBufferGetDataSize(aConfidence)
        let dataAddr = CVPixelBufferGetBaseAddress(aConfidence)
        let data = Data(bytes: dataAddr!, count: dataSize)
        try! data.write(to: filePath, options: .atomicWrite)

        CVPixelBufferUnlockBaseAddress(aConfidence, .readOnly)
        #endif

    }

    func dump(aCamera: ARCamera, atTimeStamp: UInt64) {
//        let filePath = documentsPath.appendingPathComponent("\(atTimeStamp)_camera.json")
//
//        let jsonEncoder = JSONEncoder()
//        let jsonData = try jsonEncoder.encode(aCamera)
//        try! jsonData.
//        let json = String(data: jsonData, encoding: String.Encoding.utf16)
//        intrinsics.append(aCamera.intrinsics.debugDescription + "\n" )
    }

    func setCalibration(fromCamera camera: ARCamera) {

        let intrinsics = camera.intrinsics
        camCalibration = DGCameraCalibration(cx: intrinsics[2][0],
                                             cy: intrinsics[2][1],
                                             fx: intrinsics[0][0],
                                             fy: intrinsics[1][1])

        camCalibration!.client = DGDevice.shared.clientString

        if !_sessionManager!.sendCalibration(aCalibration: camCalibration!) {
            print("Failed to send calibrations")
        }
    }

    func setConfiguration() {

        let configuration = DGConfigurationModel()

        if !_sessionManager!.sendConfiuration(aConfigration: configuration) {
            print("Failed to send configuration")
        }

    }

    func removeOldFiles() {

        do {
            let filePaths = try FileManager.default.contentsOfDirectory(at: documentsPath,
                                                                       includingPropertiesForKeys: nil,
                                                                       options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
            for fileURL in filePaths {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch  { print(error) }
    }

    private func createSessionDirectory(atPath path: URL) {
        do {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: [:])
        } catch {
            print(error)
        }
    }

    private func saveContext() {
        guard let appDelegate =
          UIApplication.shared.delegate as? AppDelegate else {
          return
        }

        let managedContext =
           appDelegate.persistentContainer.viewContext

        do {
            try managedContext.save()
        } catch let error as NSError {
            print("Could not save. \(error), \(error.userInfo)")
        }
    }

    func createSession() {

        if !_sessionManager!.createSession(local: false) {
            print("Failed to create session")
            return
        }

        currentSession = _sessionManager!.currentSession

        let date = Date()
        let name = String(Int(date.timeIntervalSince1970))
        let path = documentsPath.appendingPathComponent(name)

        intrinsics.removeAll()
        createSessionDirectory(atPath: path)

        guard let appDelegate =
          UIApplication.shared.delegate as? AppDelegate else {
          return
        }

        let managedContext =
           appDelegate.persistentContainer.viewContext

        let session = Session(context: managedContext)
        session.date = date
        session.path = path
//        session.name = name

        saveContext()

        currentSession = session

    }

    func stopSession() {

        _isAllowCapture = false

        _sessionManager!.endSet()

        //currentSession = nil
    }

    func showSessionDialog() {

        let alertController = UIAlertController(title: "New session",
                    message: "Could you, please, fill information about model",
                    preferredStyle: .alert)

        let defaultAction = UIAlertAction(title:"Ok", style: .default) { [self] (action) -> Void in

            let tfName = alertController.textFields![0] as UITextField
            let tfDescription = alertController.textFields![1] as UITextField

            // TODO: Update session details

            createSession(named: tfName.text!, description: tfDescription.text!)
        }

        let cancelAction = UIAlertAction(title:"Cancel", style: .cancel) { (action) -> Void in
            print("Session cancelled")
        }

        alertController.addAction(defaultAction)
        alertController.addAction(cancelAction)

        alertController.addTextField { (tfName:UITextField!) in
            tfName.placeholder = "Enter name here"
            tfName.text = "Unitiled"
        }

        alertController.addTextField { (tfDescription : UITextField!) in
            tfDescription.placeholder = "Enter description here"
            tfDescription.text = "Empty description"
        }

        self.present(alertController,
                    animated: true, completion: nil)
    }

    func createSession(named name: String, description: String) {
        // TODO: Implementation
        print(name, "\n", description)
    }
}

// MARK: - ARSessionDelegate

extension Session: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        guard case .normal = frame.camera.trackingState else {
            return
        }

        if (frameSkipCounter != frameSkipValue ) {
            frameSkipCounter += 1
            return
        }

        frameSkipCounter = 0


        DispatchQueue.global().async { [self] in

            // get timestamp from ARFrame
//            let ts = UInt64(Date().timeIntervalSince1970 * 10)
            let ts = UInt64(processedFrames)

            guard let depth = frame.sceneDepth, let confidence = depth.confidenceMap else {
                return
            }

            print("grab at \(ts)")

            let camera = frame.camera
            dump(aCamera: camera, atTimeStamp: ts)

            if camCalibration == nil {
                setCalibration(fromCamera: camera)
                usleep(1000)
                setConfiguration()
                usleep(1000)
                _sessionManager!.startSet()
                sleep(1)
                _isAllowCapture = true

                return
            }

            if _isAllowCapture {
                dump(anImage: frame.capturedImage, atTimeStamp: ts)
                dump(aDepth: depth.depthMap, atTimeStamp: ts)
                dump(aConfidence: confidence, atTimeStamp: ts)
            }

            processedFrames += 1

//            print("\(camera.intrinsics)")


//            if processedFrames >= maxFrames {
//                // Stop recording
//                self.btnStartPressed(aSender: btnStart)
//            }


        }

    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")

        DispatchQueue.main.async {
            // Present an alert informing about the error that has occurred.
            let alertController = UIAlertController(title: "The AR session failed.", message: errorMessage, preferredStyle: .alert)
            let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
                alertController.dismiss(animated: true, completion: nil)
                self.resetButtonPressed(self)
            }
            alertController.addAction(restartAction)
            self.present(alertController, animated: true, completion: nil)
        }
    }

}

// MARK: - ARCoachingOverlayViewDelegate

extension Session: ARCoachingOverlayViewDelegate {

    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
        btnReset.isHidden = true
        btnExport.isHidden = true
        btnStart.isHidden = true
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
        btnReset.isHidden = false
        btnReset.isHidden = false
        btnReset.isHidden = false
    }

    func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
        resetButtonPressed(self)
    }

    func setupCoachingOverlay() {
        // Set up coaching view
        coachingOverlay.session = arView.session
        coachingOverlay.delegate = self

        coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
        arView.addSubview(coachingOverlay)

        NSLayoutConstraint.activate([
            coachingOverlay.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            coachingOverlay.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            coachingOverlay.widthAnchor.constraint(equalTo: view.widthAnchor),
            coachingOverlay.heightAnchor.constraint(equalTo: view.heightAnchor)
            ])
    }
}


extension Session : DGSessionManagerDelegate {

    func sessionDidFinishUploading(_ session: Session) {

        print("Finished uploading model")
        showAlert(message: "The model uploading finished")
    }

    fileprivate func showAlert(title: String = "Information", message: String) {

        let alert = UIAlertController.init(title: title,
                                           message: message,
                                           preferredStyle: .alert)

        let defaultAction = UIAlertAction.init(title: "OK", style: .default) {
            (action) in
        }

        alert.addAction(defaultAction)
        self.present(alert, animated: true, completion: nil)
    }

    func session(_ session: Session, didFinishProcessingUrl url: URL) {

//        showAlert(message: "\(url)")

        UIApplication.shared.open(url)

    }

}
