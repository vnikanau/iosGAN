//
//  BaseSessionViewController.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 11/2/20.
//

import UIKit
import AVFoundation
import CoreVideo
import MobileCoreServices
import Accelerate
import CoreMotion

class BaseSessionViewController: UIViewController {

    @IBOutlet weak var ivAim: UIImageView!

    let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    let imgConverter = IDLImageConverter()
    var processedFrames = 0
    var currentSession: Session? = nil
    var statusBarOrientation: UIInterfaceOrientation = .portrait

    var cameraIntrinsics: matrix_float3x3!
    var depthIntrinsics: matrix_float3x3!
    var sessionManager: DGSessionManager!
    var frameSkipValue = 6 // 5 FPS
    var frameSkipCounter = 0

    var isAllowCapture = false
    var isActive = false
    var viewFrame: CGRect!

    var dumper: IDLARDumper = IDLARDumper.shared
    let motionManager = CMMotionManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        viewFrame = self.view.frame

        // Do any additional setup after loading the view.

        sessionManager = DGSessionManager.shared
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        UIApplication.shared.isIdleTimerDisabled = true

    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        UIApplication.shared.isIdleTimerDisabled = false
    }


    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */

    func configureSession() {
        // Override in subclasses
    }

    func setCameraCalibration(_ intrinsics: matrix_float3x3, width: Int? = nil, height: Int? = nil) {

        guard let session = currentSession else {
            return
        }

        var calibration = DGCameraCalibration(cx: intrinsics[2][0],
                                       cy: intrinsics[2][1],
                                       fx: intrinsics[0][0],
                                       fy: intrinsics[1][1])

        if (width != nil && height != nil) {
            calibration.width = Float(width!)
            calibration.height = Float(height!)
        }

        calibration.client = IDLDevice.shared.clientString

        if session.local {

            if !sessionManager!.storeCameraCalibration(aCalibration: calibration) {
                print("Failed to save calibrations")
            }

        } else {

            if !sessionManager!.sendCameraCalibration(aCalibration: calibration) {
                print("Failed to send calibrations")
            }

        }

    }

    func setDepthCalibration(_ intrinsics: matrix_float3x3, width: Int? = nil, height: Int? = nil) {

        guard let session = currentSession else {
            return
        }

        var calibration = DGDepthCalibration(cx: intrinsics[2][0],
                                             cy: intrinsics[2][1],
                                             fx: intrinsics[0][0],
                                             fy: intrinsics[1][1])

        if (width != nil && height != nil) {
            calibration.width = Float(width!)
            calibration.height = Float(height!)
        }

        if session.local {

            if !sessionManager!.storeDepthCalibration(aCalibration: calibration) {
                print("Failed to save calibrations")
            }

        } else {

            if !sessionManager!.sendDepthCalibration(aCalibration: calibration) {
                print("Failed to send calibrations")
            }

        }

    }

    func setConfiguration() {

        let configuration = DGConfigurationModel()

        guard let session = currentSession else {
            return
        }

        if session.local {

            if !sessionManager!.storeConfiuration(aConfigration: configuration) {
                print("Failed to send configuration")
            }

        } else {

            if !sessionManager!.sendConfiuration(aConfigration: configuration) {
                print("Failed to send configuration")
            }

        }

    }

    func convertLensDistortionLookupTable(lookupTable: Data) -> [Float] {
        let tableLength = lookupTable.count / MemoryLayout<Float>.size
        var floatArray: [Float] = Array(repeating: 0, count: tableLength)
        _ = floatArray.withUnsafeMutableBytes{lookupTable.copyBytes(to: $0)}
        return floatArray
    }

    func dump(anImage: CVPixelBuffer, atTimeStamp timeStamp: UInt64, aStore:Bool = false, aFileName:String? = nil) {

        let data = imgConverter.convertPixelBufferToData(aSource: anImage)

        guard data != nil else {
            print("Failed to convert image data")
            return
        }

        guard let session = currentSession else {
            return
        }

        // Check if local session and write locally
        if aStore || session.local
        {

            let filePath = session.path!.appendingPathComponent(aFileName != nil ? aFileName! : String.init(format: "%010d_c.png", timeStamp))
            try! data?.write(to: filePath, options: .atomicWrite)

        }
        else
        {
            sessionManager!.sendImage(data!, atTimeStamp: timeStamp)
        }

    }

    func dump(aDepth: CVPixelBuffer, atTimeStamp timeStamp: UInt64, aThreshold threshold: UInt16 = 65535) {

        #if false
        let (data, preview) = imgConverter.convertDepthToDataAndPreview(aSource: aDepth, aThreshold: threshold)

        guard data != nil else {
            print("Failed to convert depth data")
            return
        }

        DispatchQueue.main.async { [self] in
            if preview != nil {
                ivDepth.image = UIImage(data: preview!)
            }

        }
        #else
        let data = imgConverter.convertDepthToData(aSource: aDepth, aThreshold: threshold)
        #endif


        // Check if local session and write locally
        guard let session = currentSession else {
            return
        }

        #if false
        // Dump raw depth
        let address = CVPixelBufferGetBaseAddress(aDepth)
        let length = CVPixelBufferGetDataSize(aDepth)
        let rawData = Data(bytes: address!, count: length)
        let rawPath = session.path!.appendingPathComponent(String.init(format: "%010d_d.dat", timeStamp))
        try! rawData.write(to: rawPath, options: .atomicWrite)
        #endif

        if session.local {
            let filePath = session.path!.appendingPathComponent(String.init(format: "%010d_d.png", timeStamp))
            try! data?.write(to: filePath, options: .atomicWrite)

        } else {

            sessionManager!.sendDepth(data!, atTimeStamp: timeStamp)
        }


    }

    func dump(calibration: AVCameraCalibrationData) {

        guard let session = currentSession else {
            return
        }

        let jsonDict: [String : Any] = [
            "extrinsic" : (0 ..< 3).map { x in
                (0 ..< 3).map { y in calibration.extrinsicMatrix[x][y] }
            }.reduce([], +),
            "intrinsic" : (0 ..< 3).map{ x in
                (0 ..< 3).map{ y in calibration.intrinsicMatrix[x][y] }
            }.reduce([], +),
            "intrinsicReferenceDimensionHeight" : calibration.intrinsicMatrixReferenceDimensions.height,
            "intrinsicReferenceDimensionWidth" : calibration.intrinsicMatrixReferenceDimensions.width,
            "inverseLensDistortionLookup" : calibration.inverseLensDistortionLookupTable?.base64EncodedString() as Any,
//            "inverseLensDistortionLookup" : convertLensDistortionLookupTable(
//                lookupTable: calibration.inverseLensDistortionLookupTable!
//            ),
            "lensDistortionCenter" : [
                calibration.lensDistortionCenter.x,
                calibration.lensDistortionCenter.y
            ],
//            "lensDistortionLookup" : convertLensDistortionLookupTable(
//                lookupTable: calibration.lensDistortionLookupTable!
//            ),
            "lensDistortionLookup" : calibration.lensDistortionLookupTable?.base64EncodedString() as Any,
            "pixelSize" : calibration.pixelSize
        ]
        let jsonData = try! JSONSerialization.data(
            withJSONObject: jsonDict,
            options: .prettyPrinted
        )

        let filePath = session.path!.appendingPathComponent("calibration.json")
        try! jsonData.write(to: filePath, options: .atomicWrite)

    }

    func dump(aRotationMatrix: CMRotationMatrix, atTimeStamp timestamp: UInt64) {
        guard let session = currentSession else {
            return
        }

        let filePath = session.path!.appendingPathComponent(String.init(format: "%010d_rotation.json", timestamp))
        let jsonEncoder = JSONEncoder()
        let jsonData = try! jsonEncoder.encode(CMRotationMatrixContainer(aMatrix: aRotationMatrix))
        try! jsonData.write(to: filePath, options: .atomicWrite)
    }

    func dump(anAttitude: CMAttitude, atTimestamp timestamp: UInt64) {
        guard let session = currentSession else {
            return
        }

        struct EulerAngles : Encodable {
            var roll: Double
            var pitch: Double
            var yaw: Double
        }

        let angles = EulerAngles(roll: anAttitude.roll, pitch: anAttitude.pitch, yaw: anAttitude.yaw)

        let filePath = session.path!.appendingPathComponent(String.init(format: "%010d_angles.json", timestamp))
        let jsonEncoder = JSONEncoder()
        let jsonData = try! jsonEncoder.encode(angles)
        try! jsonData.write(to: filePath, options: .atomicWrite)
    }

    func createSessionDirectory(atPath path: URL) {
        do {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: [:])
        } catch {
            print(error)
        }
    }

    func saveContext() {
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

    @objc
    func didEnterBackground(notification: NSNotification) {
        // Free up resources
        /*
        dataOutputQueue.async {
            self.renderingEnabled = false
            if let videoFilter = self.videoFilter {
                videoFilter.reset()
            }
            self.videoDepthMixer.reset()
            self.currentDepthPixelBuffer = nil
            self.videoDepthConverter.reset()
            self.previewView.pixelBuffer = nil
            self.previewView.flushTextureCache()
        }
        processingQueue.async {
            if let photoFilter = self.photoFilter {
                photoFilter.reset()
            }
            self.photoDepthMixer.reset()
            self.photoDepthConverter.reset()
        }
         */
    }

    @objc
    func willEnterForground(notification: NSNotification) {
//        dataOutputQueue.async {
//            self.renderingEnabled = true
//        }
    }

    @objc
    func sessionRuntimeError(notification: NSNotification) {
        guard let errorValue = notification.userInfo?[AVCaptureSessionErrorKey] as? NSError else {
            return
        }

        let error = AVError(_nsError: errorValue)
        print("Capture session runtime error: \(error)")

        /*
            Automatically try to restart the session running if media services were
            reset and the last start running succeeded. Otherwise, enable the user
            to try to resume the session running.
        */
        if error.code == .mediaServicesWereReset {
//            sessionQueue.async {
//                if self.isSessionRunning {
//                    self.session.startRunning()
//                    self.isSessionRunning = self.session.isRunning
//                } else {
//                    DispatchQueue.main.async {
//                        self.resumeButton.isHidden = false
//                    }
//                }
//            }
        } else {
//            resumeButton.isHidden = false
        }
    }

    @objc
    func thermalStateChanged(notification: NSNotification) {
        if let processInfo = notification.object as? ProcessInfo {
            showThermalState(state: processInfo.thermalState)
        }
    }

    func showThermalState(state: ProcessInfo.ThermalState) {

        DispatchQueue.main.async {

            var thermalStateString = "UNKNOWN"
            if state == .nominal {
                thermalStateString = "NOMINAL"
            } else if state == .fair {
                thermalStateString = "FAIR"
            } else if state == .serious {
                thermalStateString = "SERIOUS"
            } else if state == .critical {
                thermalStateString = "CRITICAL"
            }

            let message = NSLocalizedString("Thermal state: \(thermalStateString)", comment: "Alert message when thermal state has changed")
            let alertController = UIAlertController(title: "AVCamPhotoFilter", message: message, preferredStyle: .alert)
            alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil))
            self.present(alertController, animated: true, completion: nil)
        }
    }

    // MARK: - KVO
    func addObservers() {
        NotificationCenter.default.addObserver(self, selector: #selector(didEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(willEnterForground), name: UIApplication.willEnterForegroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(thermalStateChanged), name: ProcessInfo.thermalStateDidChangeNotification,    object: nil)
//        NotificationCenter.default.addObserver(self, selector: #selector(sessionRuntimeError), name: NSNotification.Name.AVCaptureSessionRuntimeError, object: session)
    }

    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
    }
}


extension UIViewController {

    var window : UIWindow {
        return UIApplication.shared.windows.first!
    }

}
