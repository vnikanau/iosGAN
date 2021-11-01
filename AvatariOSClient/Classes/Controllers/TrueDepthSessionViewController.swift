//
//  TrueDepthSessionViewController.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 11/2/20.
//

import UIKit
import AVFoundation
import CoreVideo

class TrueDepthSessionViewController: BaseSessionViewController {

    private enum VideoSessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }

    private var imgAim = UIImage()
    private let imageHelper = UIImageHelper()
    private var setupResult: VideoSessionSetupResult = .success

    private let sessionQueue = DispatchQueue(
        label: "com.indatalabs.AvatarIOSClient.sessionQueue",
        attributes: [],
        autoreleaseFrequency: .workItem)

    private let dataOutputQueue = DispatchQueue(
        label: "com.indatalabs.AvatarIOSClient.videoDataQueue",
        qos: .userInitiated,
        attributes: [],
        autoreleaseFrequency: .workItem)

    private let session = AVCaptureSession()
    private var videoDeviceInput: AVCaptureDeviceInput!
    private let videoDataOutput = AVCaptureVideoDataOutput()
    private let depthDataOutput = AVCaptureDepthDataOutput()
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?

    // MARK: - A Video source defintion
    // MARK: - TrueDepth camera
    private let deviceType:AVCaptureDevice.DeviceType = .builtInTrueDepthCamera
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInTrueDepthCamera],
                                                                               mediaType: .video,
                                                                               position: .front)
    
    private lazy var module: TorchModule =
    {
        let filePath = Bundle.main.path(forResource: "2000", ofType: "ptl")
        //let filePath = Bundle.main.path(forResource: "smile200000", ofType: "ptl")
        print(filePath)
        
        if let module = TorchModule(fileAtPath: filePath ?? "")
        {
            return module
        }
        else
        {
            fatalError("Can't find the model file!")
        }
    }()

    private lazy var labels: [String] = {
        if let filePath = Bundle.main.path(forResource: "words", ofType: "txt"),
            let labels = try? String(contentsOfFile: filePath) {
            return labels.components(separatedBy: .newlines)
        } else {
            fatalError("Can't find the text file!")
        }
    }()

    // MARK: - UltraWideCamera camera
//    private let deviceType:AVCaptureDevice.DeviceType = .builtInUltraWideCamera
//    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInDualWideCamera],
//                                                                               mediaType: .video,
//                                                                               position: .unspecified)
//

    private var isSessionRunning = false

    @IBOutlet weak var vCamera: UIView!
    @IBOutlet weak var swAutoFocus: UISwitch!

    // MARK: - ViewController life cycle
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        // Check video authorization status, video access is required
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera
            break

        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant video access
             We suspend the session queue to delay session setup until the access request has completed
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })

        default:
            // The user has previously denied access
            setupResult = .notAuthorized
        }

        sessionQueue.async {
            self.configureSession()
        }

    }

    fileprivate func configureMotion() {
        // motion
        if motionManager.isGyroAvailable {
            motionManager.accelerometerUpdateInterval = 0.01
            motionManager.startAccelerometerUpdates()
        }

        if motionManager.isGyroAvailable {
            motionManager.gyroUpdateInterval = 0.01
            motionManager.startGyroUpdates()
        }

        if motionManager.isMagnetometerAvailable {
            motionManager.magnetometerUpdateInterval = 0.01
            motionManager.startMagnetometerUpdates()
        }
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 0.01
            motionManager.startDeviceMotionUpdates()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        self.splitViewController?.preferredDisplayMode = .secondaryOnly

        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session running if setup succeeded
//                self.addObservers()

/*
                let videoOrientation = self.videoDataOutput.connection(with: .video)!.videoOrientation
                let videoDevicePosition = self.videoDeviceInput.device.position
*/

//                let rotation = PreviewMetalView.Rotation(with: interfaceOrientation,
//                                                         videoOrientation: videoOrientation,
//                                                         cameraPosition: videoDevicePosition)
//                self.jetView.mirroring = (videoDevicePosition == .front)
//                if let rotation = rotation {
//                    self.jetView.rotation = rotation
//                }
                self.dataOutputQueue.async {
//                    self.renderingEnabled = true
                }

                self.session.startRunning()
                self.isSessionRunning = self.session.isRunning

            case .notAuthorized:
                DispatchQueue.main.async {
                    let message = NSLocalizedString("TrueDepthStreamer doesn't have permission to use the camera, please change privacy settings",
                                                    comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "TrueDepthStreamer", message: message, preferredStyle: .alert)
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                    }))

                    self.present(alertController, animated: true, completion: nil)
                }

            case .configurationFailed:
                DispatchQueue.main.async {
//                    self.cameraUnavailableLabel.isHidden = false
//                    self.cameraUnavailableLabel.alpha = 0.0
//                    UIView.animate(withDuration: 0.25) {
//                        self.cameraUnavailableLabel.alpha = 1.0
//                    }
                }
            }
        }

        configureMotion()

    }
    
    
    // Convert CIImage to UIImage
    func convert(cmage: CIImage) -> UIImage {
         let context = CIContext(options: nil)
         let cgImage = context.createCGImage(cmage, from: cmage.extent)!
         let image = UIImage(cgImage: cgImage)
         return image
    }

    override func viewWillDisappear(_ animated: Bool)
    {
        dataOutputQueue.async
        {
//            self.renderingEnabled = false
        }
        sessionQueue.async
        {
            if self.setupResult == .success
            {
                self.session.stopRunning()
                self.isSessionRunning = self.session.isRunning
            }

            self.motionManager.stopDeviceMotionUpdates()
            self.motionManager.stopMagnetometerUpdates()
            self.motionManager.stopGyroUpdates()
            self.motionManager.stopAccelerometerUpdates()
        }

        super.viewWillDisappear(animated)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .all
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(
            alongsideTransition: { _ in

                let interfaceOrientation = self.window.windowScene!.interfaceOrientation // UIApplication.shared.statusBarOrientation
                self.statusBarOrientation = interfaceOrientation
                self.sessionQueue.async {
                    /*
                     The photo orientation is based on the interface orientation. You could also set the orientation of the photo connection based
                     on the device orientation by observing UIDeviceOrientationDidChangeNotification.
                     */

                    // TODO: Use if needed
                    //let videoOrientation = self.videoDataOutput.connection(with: .video)!.videoOrientation

//                    if let rotation = PreviewMetalView.Rotation(with: interfaceOrientation, videoOrientation: videoOrientation,
//                                                                cameraPosition: self.videoDeviceInput.device.position) {
//                        self.jetView.rotation = rotation
//                    }
                }
        }, completion: nil
        )
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

    @IBAction func swAutofocusChanged(_ sender: UISwitch!) {

        let isOn = sender.isOn

        sessionQueue.async {

            self.session.beginConfiguration()

            do {
                let input = self.session.inputs[0] as! AVCaptureDeviceInput
                let device = input.device

                try device.lockForConfiguration()

                if(device.isFocusModeSupported(.continuousAutoFocus)) {
                    device.focusMode = isOn ? .continuousAutoFocus : .locked
                }

                device.unlockForConfiguration()

            } catch {

                print("Could not lock device for configuration: \(error)")

            }

            self.session.commitConfiguration()

        }


    }

    @IBAction func btnStartPressed(_ sender: UIButton!) {

        if !isActive {

            processedFrames = 0

            createSession()
            sender.setTitle("Stop", for: .normal)
            print("start")

            isActive = true

        } else {

            print("stop")

            stopSession()
            isActive = false
            session.stopRunning()

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                [] in

                sender.setTitle("Start", for: .normal)

            }

        }

    }

    // MARK: -
    override func configureSession()
    {

        if setupResult != .success
        {
            return
        }

        let defaultVideoDevice: AVCaptureDevice? = videoDeviceDiscoverySession.devices.first

        guard let videoDevice = defaultVideoDevice else
        {
            print("Could not find any video device")
            setupResult = .configurationFailed
            return
        }
        do
        {
            videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
        }
        catch
        {
            print("Could not create video device input: \(error)")
            setupResult = .configurationFailed
            return
        }

        session.beginConfiguration()

        session.sessionPreset = AVCaptureSession.Preset.hd1920x1080 //.hd1920x1080 //.vga640x480

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer.frame = viewFrame
        previewLayer.connection?.videoOrientation = .portrait
        vCamera.layer.addSublayer(previewLayer)

        // Add a video input
        guard session.canAddInput(videoDeviceInput) else {
            print("Could not add video device input to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
        session.addInput(videoDeviceInput)

        // Add a video data output
        if session.canAddOutput(videoDataOutput)
        {
            session.addOutput(videoDataOutput)
            videoDataOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)]

            if let connection = videoDataOutput.connection(with: .video) {

                if connection.isCameraIntrinsicMatrixDeliverySupported {
                    connection.isCameraIntrinsicMatrixDeliveryEnabled = true
                }
                connection.isVideoMirrored = false

//                connection.videoOrientation = .portrait

            } else {
                print("No AVCaptureConnection")
            }

        } else {
            print("Could not add video data output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        // Add a depth data output
        if session.canAddOutput(depthDataOutput) {
            session.addOutput(depthDataOutput)

            depthDataOutput.isFilteringEnabled = false

            if let connection = depthDataOutput.connection(with: .depthData) {
                connection.isEnabled = true
                connection.isVideoMirrored = false
//                connection.videoOrientation = .portrait
            } else {
                print("No AVCaptureConnection for depthData")
            }
        } else {
            print("Could not add depth data output to the session")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }
//        AVCaptureDevice.Format
        // Search for highest resolution with half-point depth values
        let depthFormats = videoDevice.activeFormat.supportedDepthDataFormats
        let filtered = depthFormats.filter({
//            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat16
            CMFormatDescriptionGetMediaSubType($0.formatDescription) == kCVPixelFormatType_DepthFloat32
        })
        let selectedFormat = filtered.max(by: {
            first, second in CMVideoFormatDescriptionGetDimensions(first.formatDescription).width < CMVideoFormatDescriptionGetDimensions(second.formatDescription).width
        })

        do {
            try videoDevice.lockForConfiguration()
            videoDevice.activeDepthDataFormat = selectedFormat

            if(videoDevice.isFocusModeSupported(.continuousAutoFocus)) {
                videoDevice.focusMode = .continuousAutoFocus
                swAutoFocus.isEnabled = true;
            }
            
            videoDevice.unlockForConfiguration()
        } catch {
            print("Could not lock device for configuration: \(error)")
            setupResult = .configurationFailed
            session.commitConfiguration()
            return
        }

        // Use an AVCaptureDataOutputSynchronizer to synchronize the video data and depth data outputs.
        // The first output in the dataOutputs array, in this case the AVCaptureVideoDataOutput, is the "master" output.
        outputSynchronizer = AVCaptureDataOutputSynchronizer(dataOutputs: [videoDataOutput, depthDataOutput])
        outputSynchronizer!.setDelegate(self, queue: dataOutputQueue)
        session.commitConfiguration()
    }

    func setUpCamera() {

    }

    func createSession() {

        if !sessionManager!.createSession(local: true) {
            print("Failed to create session")
            return
        }

        currentSession = sessionManager!.currentSession
        guard let session = currentSession else {
            print("Error create session")
            return
        }

        let name = "Untitled"
        let path = documentsPath.appendingPathComponent(session.modelId!)
        print("\(path)")

        cameraIntrinsics = nil
        depthIntrinsics = nil

        createSessionDirectory(atPath: path)

        session.path = path
        session.modelName = name
        session.modelDescription = "Empty description"

        saveContext()

        currentSession = session

    }

    func stopSession() {

        isAllowCapture = false

        guard let session = currentSession else {
            return
        }

        if !session.local {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                sessionManager!.endSet()
            }
        } else {
            // TODO: Return to the main screen
        }

    }

}

extension TrueDepthSessionViewController : AVCaptureDataOutputSynchronizerDelegate {
    func dataOutputSynchronizer(_ synchronizer: AVCaptureDataOutputSynchronizer,
                                didOutput synchronizedDataCollection: AVCaptureSynchronizedDataCollection) {

        if (frameSkipCounter != frameSkipValue ) {
            frameSkipCounter += 1
            return
        }

        frameSkipCounter = 0

        if isActive {

            sessionQueue.async { [self] in

                // TODO: Visualize depth & etc

                guard let session = currentSession else {
                    return
                }

                // Read all outputs
                guard
                    let syncedDepthData: AVCaptureSynchronizedDepthData =
                    synchronizedDataCollection.synchronizedData(for: depthDataOutput) as? AVCaptureSynchronizedDepthData,
                    let syncedVideoData: AVCaptureSynchronizedSampleBufferData =
                    synchronizedDataCollection.synchronizedData(for: videoDataOutput) as? AVCaptureSynchronizedSampleBufferData else {
                        // only work on synced pairs
                        return
                }

                if syncedDepthData.depthDataWasDropped || syncedVideoData.sampleBufferWasDropped {
                    return
                }

                let depthData = syncedDepthData.depthData
                let depthPixelBuffer = depthData.depthDataMap
                let sampleBuffer = syncedVideoData.sampleBuffer

                guard let videoPixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)/*,
                    let formatDescription = CMSampleBufferGetFormatDescription(sampleBuffer)*/ else {
                        return
                }

                CVPixelBufferLockBaseAddress(videoPixelBuffer, .readOnly)
                CVPixelBufferLockBaseAddress(depthPixelBuffer, .readOnly)

                defer {
                    CVPixelBufferUnlockBaseAddress(videoPixelBuffer, .readOnly)
                    CVPixelBufferUnlockBaseAddress(depthPixelBuffer, .readOnly)
                }

                let ts = UInt64(processedFrames)

                if cameraIntrinsics == nil {

                    if let camData = CMGetAttachment(sampleBuffer,
                                                     key:kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix,
                                                     attachmentModeOut:nil) as? Data {

                        cameraIntrinsics = camData.withUnsafeBytes { $0.load(as: matrix_float3x3.self) }
                        print(cameraIntrinsics as Any)
                        
                        let width = CVPixelBufferGetWidth(videoPixelBuffer)
                        let height = CVPixelBufferGetHeight(videoPixelBuffer)
                        setCameraCalibration(cameraIntrinsics, width: width, height: height)
                    }

                    if let calibration = depthData.cameraCalibrationData {
                        depthIntrinsics = calibration.intrinsicMatrix
                        let size = calibration.intrinsicMatrixReferenceDimensions
                        dump(calibration: calibration)
                        setDepthCalibration(depthIntrinsics, width: Int(size.width), height: Int(size.height))
                    }

                    usleep(1000)
                    setConfiguration()
                    usleep(1000)

                    if !session.local {
                        sessionManager!.startSet()
                    }

                    sessionQueue.asyncAfter(deadline: .now() + 1) {
                        isAllowCapture = true
                    }

                    return
                }

                if isAllowCapture
                {
                    print("grab at \(ts)")

                    let ciimage = CIImage(cvPixelBuffer: videoPixelBuffer)
                    let image = self.convert(cmage: ciimage)
                    
                    ///////////
                    let resizedImage = image.resized(to: CGSize(width: 250, height: 250))
                    guard var pixelBuffer = resizedImage.normalized() else
                    {
                        return
                    }
                            
                    let w = Int32(resizedImage.size.width)
                    let h = Int32(resizedImage.size.height)
                    DispatchQueue.global().async
                    {
                        let date_start = NSDate()
                        
                        let buffer = module.segment(image: UnsafeMutableRawPointer(&pixelBuffer), withWidth:w, withHeight: h)
                        self.imgAim = imageHelper.convertRGBBuffer(toUIImage: buffer , withWidth: w, withHeight: h)
                        
                        let t = -date_start.timeIntervalSinceNow
                        print("time = ", t)
                    }
                    DispatchQueue.main.async
                    {
                        ivAim.image = self.imgAim
                        ivAim.alpha = 0.5
                    }
                    
                    ///////////
                    
                    //let resizedImage =  image.resized(to: CGSize(width: 224, height: 224))
                    //guard var pixelBuffer = resizedImage.normalized() else
                    //{
                    //    return
                    //}
                    //let date_start = NSDate()
                    
                    //guard let outputs = module.predict(image: UnsafeMutableRawPointer(&pixelBuffer)) else
                    //{
                    //    return
                    //}
                    
                    //let t = -date_start.timeIntervalSinceNow
                    //print("time = ", t)
                    
                    //let zippedResults = zip(labels.indices, outputs)
                    //let sortedResults = zippedResults.sorted { $0.1.floatValue > $1.1.floatValue }.prefix(3)
                    //var text = ""
                    //for result in sortedResults
                    //{
                    //    text += "\u{2022} \(labels[result.0]) \n\n"
                    //}
                    
                    //print("result = ", text)
                    dump(anImage: videoPixelBuffer, atTimeStamp: ts)
                    dump(aDepth: depthPixelBuffer, atTimeStamp: ts)

                    if let attitude = motionManager.deviceMotion?.attitude {
                        dump(anAttitude: attitude, atTimestamp: ts)
                        dump(aRotationMatrix: attitude.rotationMatrix, atTimeStamp: ts)
                    }

                    processedFrames += 1
                }

            }

        }

//        let threshold = _depth;
    }
}
