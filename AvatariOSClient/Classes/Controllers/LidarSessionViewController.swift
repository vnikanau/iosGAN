//
//  SessionViewController.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 7/2/20.
//

import Foundation
import UIKit
import ARKit
import RealityKit
import MetalKit
import CoreMotion

class LidarSessionViewController: UIViewController {

    @IBOutlet var arView: ARView!
    @IBOutlet weak var btnStart: RoundedButton!
    @IBOutlet weak var btnExport: RoundedButton!
    @IBOutlet weak var btnReset: RoundedButton!
    @IBOutlet weak var ivAim: UIImageView!
    @IBOutlet weak var ivDepth: UIImageView!
    @IBOutlet weak var slDepth: IDLVerticalSlider!
    @IBOutlet weak var lbDepth: UILabel!
    @IBOutlet weak var scConfidence: UISegmentedControl!


    private var isActive = false
    private var configuration = ARWorldTrackingConfiguration()
    private let frameSkipValue = 12//6 // 60 / 15
    private var frameSkipCounter = 0
    private let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let maxFrames = 400
    private var processedFrames = 0
    private var currentSession: Session? = nil
    private var intrinsics: [String] = []
    private let imgConverter = IDLImageConverter()
    private var camCalibration: DGCameraCalibration? = nil
    private var _cameraCalibration: AVCameraCalibrationData? = nil

    private var _sessionManager: DGSessionManager? = nil
    private var _isAllowCapture: Bool = false

    private var _depth: UInt16 = 500

    private var skipColor: Bool = false
    private var dumper: IDLARDumper = IDLARDumper.shared
    private var _confidenceLevel = 2

    let coachingOverlay = ARCoachingOverlayView()
//    let observer

    let motionManager = CMMotionManager()
    
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
        arView.debugOptions.insert(.showFeaturePoints)
        arView.debugOptions.insert(.showWorldOrigin)
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
        configuration.isAutoFocusEnabled = false

        if type(of: configuration).supportsFrameSemantics(.sceneDepth) {
            configuration.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        }

        _sessionManager = DGSessionManager.shared
        _sessionManager!.delegate = self

//        removeOldFiles()

//        let imgAim = UIImage(named: "imgAim")?.resizableImage(withCapInsets: UIEdgeInsets(top: 362, left: 274, bottom: 362, right: 274), resizingMode: .stretch)
//        ivAim.image = imgAim

        slDepth.delegate = self
        
        // Read stored confidence level
        let defaults = UserDefaults.standard

        if let confidence = defaults.value(forKey: "confidenceLevel") {
            _confidenceLevel = Int(truncating: confidence as! NSNumber)
        }

        scConfidence.selectedSegmentIndex = _confidenceLevel;

        if let depth = defaults.value(forKey: "depth") {
            _depth = UInt16(truncating: depth as! NSNumber)
            slDepth.value = Float(_depth) / 1000.0
        } else {
            setDepth(slDepth.value)
        }

    }

    override func viewWillAppear(_ animated: Bool) {

        super.viewWillAppear(animated)
        self.splitViewController?.preferredDisplayMode = .secondaryOnly

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Prevent the screen from being dimmed to avoid interrupting the AR experience.
        UIApplication.shared.isIdleTimerDisabled = true
        arView.session.run(configuration)
        setDepth(slDepth.value)

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

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        self.splitViewController?.preferredDisplayMode = .automatic

        arView.session.pause()
        // Enable idle timer
        UIApplication.shared.isIdleTimerDisabled = false

        motionManager.stopDeviceMotionUpdates()
        motionManager.stopMagnetometerUpdates()
        motionManager.stopGyroUpdates()
        motionManager.stopAccelerometerUpdates()
        
        let defaults = UserDefaults.standard
        defaults.setValue(_confidenceLevel, forKey: "confidenceLevel")
        defaults.setValue(_depth, forKey: "depth")
        
    }


    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }


    override var prefersStatusBarHidden: Bool {
        return true
    }

    // MARK: - Actions
    @IBAction func btnStartPressed(aSender: UIButton) {

//        showSessionDialog()


        if !isActive {
            isActive = true
            processedFrames = 0
//            removeOldFiles()
            createSession()
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

        DispatchQueue.global().async { [self] in
            self.export()
        }
    }

    @IBAction func resetButtonPressed(_ sender: Any) {

        print("reset")

        // Reset Active AR session

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
    
    @IBAction func scConfidenceChanged(_ sender: UISegmentedControl) {
        _confidenceLevel = scConfidence.selectedSegmentIndex
    }

    // MARK: - Private methods

    private func setDepth(_ depth: Float) {
        _depth = UInt16(depth * 1000)
        lbDepth.text = String(format: "%3.1f", depth)
    }

    func dump(anImage: CVPixelBuffer, atTimeStamp timeStamp: UInt64, aStore:Bool = false, aFileName:String? = nil) {

        let data = imgConverter.convertYpCbCrToRGBData(aSource: anImage)

        guard data != nil else {
            print("Failed to convert image data")
            return
        }

        guard let session = currentSession else {
            return
        }

        // Check if local session and write locally
        if aStore || session.local {

            let filePath = session.path!.appendingPathComponent(aFileName != nil ? aFileName! : String.init(format: "%010d_c.png", timeStamp))
            try! data?.write(to: filePath, options: .atomicWrite)

        } else {
            _sessionManager!.sendImage(data!, atTimeStamp: timeStamp)

        }

    }

    func show(aDepth: CVPixelBuffer, atTimeStamp timeStamp: UInt64, aThreshold threshold: UInt16 = 65535) {

        let preview = imgConverter.convertDepthToCGimage(aSource: aDepth, aThreshold: threshold)

        guard preview != nil else {
            print("Failed to convert depth data")
            return
        }

        DispatchQueue.main.async { [self] in
            if preview != nil {
                ivDepth.image = UIImage(cgImage: preview!)
            }

        }

    }

    func show(aDepth: CVPixelBuffer, aConfigdence: CVPixelBuffer, atTimeStamp timeStamp: UInt64, aThreshold threshold: UInt16 = 65535, aConfThreshold confThreshold: UInt8 = 2) {

//        let preview = imgConverter.convertDepthToCGimage(aSource: aDepth, aThreshold: threshold)
        let preview = imgConverter.convertDepthToCGimage(aSource: aDepth,
                                                         aConfidence: aConfigdence,
                                                         aThreshold: threshold,
                                                         aConfThreshold: UInt8(_confidenceLevel))

        guard preview != nil else {
            print("Failed to convert depth data")
            return
        }

        DispatchQueue.main.async { [self] in
            if preview != nil {
                ivDepth.image = UIImage(cgImage: preview!)
            }

        }

    }

    
    func dump(aDepth: CVPixelBuffer, atTimeStamp timeStamp: UInt64, aThreshold threshold: UInt16 = 65535) {

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

        // Check if local session and write locally
        guard let session = currentSession else {
            return
        }

        if session.local {
            let filePath = session.path!.appendingPathComponent(String.init(format: "%010d_d.png", timeStamp))
            try! data?.write(to: filePath, options: .atomicWrite)

        } else {

            _sessionManager!.sendDepth(data!, atTimeStamp: timeStamp)
        }


    }
    
    func dump(aDepth: CVPixelBuffer,
              aConfidence: CVPixelBuffer,
              atTimeStamp timeStamp: UInt64,
              aThreshold threshold: UInt16 = 65535,
              aConfThreshold confThreshold: UInt8 = 2) {

//        let (data, preview) = imgConverter.convertDepthToDataAndPreview(aSource: aDepth, aThreshold: threshold)
        let (data, preview) = imgConverter.convertDepthToDataAndPreview(aSource: aDepth,
                                                                        aConfidence: aConfidence,
                                                                        aThreshold: threshold,
                                                                        aConfThreshold: UInt8(_confidenceLevel))

        guard data != nil else {
            print("Failed to convert depth data")
            return
        }

        DispatchQueue.main.async { [self] in
            if preview != nil {
                ivDepth.image = UIImage(data: preview!)
            }

        }

        // Check if local session and write locally
        guard let session = currentSession else {
            return
        }

        if session.local {
            let filePath = session.path!.appendingPathComponent(String.init(format: "%010d_d.png", timeStamp))
            try! data?.write(to: filePath, options: .atomicWrite)

        } else {

            _sessionManager!.sendDepth(data!, atTimeStamp: timeStamp)
        }


    }


    func dump(aConfidence: CVPixelBuffer, atTimeStamp: UInt64) {

        guard let session = currentSession else {
            return
        }

        #if false
        let filePath = session.path!.appendingPathComponent(String.init(format: "%010d_conf.dat", timeStamp))

        CVPixelBufferLockBaseAddress(aConfidence, .readOnly)

        let dataSize = CVPixelBufferGetDataSize(aConfidence)
        let dataAddr = CVPixelBufferGetBaseAddress(aConfidence)
        let data = Data(bytes: dataAddr!, count: dataSize)
        try! data.write(to: filePath, options: .atomicWrite)

        CVPixelBufferUnlockBaseAddress(aConfidence, .readOnly)
        #endif

    }

    func dump(aCamera: ARCamera, atTimeStamp timestamp: UInt64) {

        guard let session = currentSession else {
            return
        }

        let filePath = session.path!.appendingPathComponent(String.init(format: "%010d_camera.json", timestamp))
        let jsonEncoder = JSONEncoder()
        let jsonData = try! jsonEncoder.encode(ARCameraContainer(camera: aCamera))
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

    func setCalibration(fromCamera camera: ARCamera) {

        let intrinsics = camera.intrinsics
        camCalibration = DGCameraCalibration(cx: intrinsics[2][0],
                                             cy: intrinsics[2][1],
                                             fx: intrinsics[0][0],
                                             fy: intrinsics[1][1])

        camCalibration!.client = IDLDevice.shared.clientString

        guard let session = currentSession else {
            return
        }

        if session.local {

            if !_sessionManager!.storeCameraCalibration(aCalibration: camCalibration!) {
                print("Failed to save calibrations")
            }

        } else {

            if !_sessionManager!.sendCameraCalibration(aCalibration: camCalibration!) {
                print("Failed to send calibrations")
            }

        }
    }

    func dump(calibration: AVCameraCalibrationData) {

        guard let session = currentSession else {
            return
        }
        
        _cameraCalibration = calibration

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
            "lensDistortionCenter" : [
                calibration.lensDistortionCenter.x,
                calibration.lensDistortionCenter.y
            ],
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

    func setConfiguration() {

        let configuration = DGConfigurationModel()

        guard let session = currentSession else {
            return
        }

        if session.local {

            if !_sessionManager!.storeConfiuration(aConfigration: configuration) {
                print("Failed to send configuration")
            }

        } else {

            if !_sessionManager!.sendConfiuration(aConfigration: configuration) {
                print("Failed to send configuration")
            }

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

        if !_sessionManager!.createSession(local: true) {
            print("Failed to create session")
            return
        }

        currentSession = _sessionManager!.currentSession
        guard let session = currentSession else {
            print("Error create session")
            return
        }

//        let date = Date()
        let name = "Untitled"
        let path = documentsPath.appendingPathComponent(session.modelId!)
        print("\(path)")

        intrinsics.removeAll()
        createSessionDirectory(atPath: path)

//        guard let appDelegate =
//          UIApplication.shared.delegate as? AppDelegate else {
//          return
//        }

//        let managedContext =
//           appDelegate.persistentContainer.viewContext

//        let session = Session(context: managedContext)
//        session.date = date
        session.path = path
        session.modelName = name
        session.modelDescription = "Empty description"

        saveContext()

        currentSession = session

    }

    func stopSession() {

        _isAllowCapture = false

        guard let session = currentSession else {
            return
        }

        export()
        
        if !session.local {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [self] in
                _sessionManager!.endSet()
            }
        }
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

    func export() {

        // 1. get frame & device
        guard let frame = arView.session.currentFrame else {
            return
        }

        // Fetch the default MTLDevice to initialize a MetalKit buffer allocator with
        guard let device = MTLCreateSystemDefaultDevice() else {
            fatalError("Failed to get the system's default Metal device!")
        }

        // Using the Model I/O framework to export the scan, so we're initialising an MDLAsset object,
        // which we can export to a file later, with a buffer allocator
        let allocator = MTKMeshBufferAllocator(device: device)
        let asset = MDLAsset(bufferAllocator: allocator)

        // 2. get anchors
        let meshAnchors = frame.anchors.compactMap({ $0 as? ARMeshAnchor })

        var meshCnt = 0;

        for meshAnchor in meshAnchors {

            // Some short handles, otherwise stuff will get pretty long in a few lines
            let geometry = meshAnchor.geometry
            let vertices = geometry.vertices
            let normals = geometry.normals
            let faces = geometry.faces
            let verticesPointer = vertices.buffer.contents()
            let normalsPointer = normals.buffer.contents()
            let facesPointer = faces.buffer.contents()

            // Converting each vertex of the geometry from the local space of their ARMeshAnchor to world space
            for vertexIndex in 0..<vertices.count {

                // Extracting the current vertex with an extension method provided by Apple in Extensions.swift
                let vertex = geometry.vertex(at: UInt32(vertexIndex))
                let normal = geometry.normal(at: UInt32(vertexIndex))

                // Building a transform matrix with only the vertex position
                // and apply the mesh anchors transform to convert into world space
                var vertexLocalTransform = matrix_identity_float4x4
                vertexLocalTransform.columns.3 = SIMD4<Float>(x: vertex.0, y: vertex.1, z: vertex.2, w: 1)
                let vertexWorldPosition = (meshAnchor.transform * vertexLocalTransform).position

                var normalLocalTranform = matrix_identity_float4x4
                normalLocalTranform.columns.3 = SIMD4<Float>(x: normal.0, y: normal.1, z: normal.2, w: 1)
                let normalWorldPosition = (meshAnchor.transform * normalLocalTranform).position

                // Writing the world space vertex back into it's position in the vertex buffer
                let vertexOffset = vertices.offset + vertices.stride * vertexIndex
                var componentStride = vertices.stride / 3
                verticesPointer.storeBytes(of: vertexWorldPosition.x, toByteOffset: vertexOffset, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.y, toByteOffset: vertexOffset + componentStride, as: Float.self)
                verticesPointer.storeBytes(of: vertexWorldPosition.z, toByteOffset: vertexOffset + (2 * componentStride), as: Float.self)

                let normalOffset = normals.offset + normals.stride * vertexIndex
                componentStride = normals.stride / 3
                normalsPointer.storeBytes(of: normalWorldPosition.x, toByteOffset: normalOffset, as: Float.self)
                normalsPointer.storeBytes(of: normalWorldPosition.y, toByteOffset: normalOffset + componentStride , as: Float.self)
                normalsPointer.storeBytes(of: normalWorldPosition.z, toByteOffset: normalOffset + (2 * componentStride), as: Float.self)
            }

            // Initializing MDLMeshBuffers with the content of the vertex and face MTLBuffers
            let byteCountVertices = vertices.count * vertices.stride
            let byteCountFaces = faces.count * faces.indexCountPerPrimitive * faces.bytesPerIndex
            let vertexBuffer = allocator.newBuffer(with: Data(bytesNoCopy: verticesPointer, count: byteCountVertices, deallocator: .none), type: .vertex)
            let indexBuffer = allocator.newBuffer(with: Data(bytesNoCopy: facesPointer, count: byteCountFaces, deallocator: .none), type: .index)

            // Creating a MDLSubMesh with the index buffer and a generic material
            let indexCount = faces.count * faces.indexCountPerPrimitive
            let material = MDLMaterial(name: "mat1", scatteringFunction: MDLPhysicallyPlausibleScatteringFunction())
            let submesh = MDLSubmesh(indexBuffer: indexBuffer, indexCount: indexCount, indexType: .uInt32, geometryType: .triangles, material: material)

            // Creating a MDLVertexDescriptor to describe the memory layout of the mesh
            let vertexFormat = MTKModelIOVertexFormatFromMetal(vertices.format)
            let vertexDescriptor = MDLVertexDescriptor()
            vertexDescriptor.attributes[0] = MDLVertexAttribute(name: MDLVertexAttributePosition, format: vertexFormat, offset: 0, bufferIndex: 0)
            vertexDescriptor.layouts[0] = MDLVertexBufferLayout(stride: meshAnchor.geometry.vertices.stride)

            // Finally creating the MDLMesh and adding it to the MDLAsset
            let mesh = MDLMesh(vertexBuffer: vertexBuffer, vertexCount: meshAnchor.geometry.vertices.count, descriptor: vertexDescriptor, submeshes: [submesh])
            asset.add(mesh)

//            let data = Data(bytesNoCopy: facesPointer, count: byteCountFaces, deallocator: .none)
//            if data != nil {
//                let dataUrl = documentsPath.appendingPathComponent("faces\(meshCnt).dat")
//                try! data.write(to: dataUrl)
//            }

            meshCnt += 1
        }

        // 3. process anchors
        let ply = IDLPLYAsset(anchors: meshAnchors)

        // 3. process vertices

        // 4. export to PLY
        // 5. save PLY
        guard let session = currentSession else {
            return
        }
        
        guard let modelId = session.modelId else {
            return
        }
        
        let sessionPath = documentsPath.appendingPathComponent(modelId)
        
        let filePath = sessionPath.appendingPathComponent("mesh.ply")
        try! ply.write(toPath: filePath.path)

        // Export to obj
        if MDLAsset.canExportFileExtension("obj") {
            let urlOBJ = sessionPath.appendingPathComponent("mesh.obj")
            try! asset.export(to: urlOBJ)
        }
        
    }
}

// MARK: - ARSessionDelegate

extension LidarSessionViewController: ARSessionDelegate {

    func session(_ session: ARSession, didUpdate frame: ARFrame) {

        guard case .normal = frame.camera.trackingState else {
            return
        }


        if (frameSkipCounter != frameSkipValue ) {
            frameSkipCounter += 1
            return
        }

        frameSkipCounter = 0

        let threshold = _depth;

        DispatchQueue.global().async { [self] in

            // get timestamp from ARFrame
//            let ts = UInt64(Date().timeIntervalSince1970 * 10)
            let ts = UInt64(processedFrames)

            guard let depth = frame.sceneDepth /* frame.smoothedSceneDepth, frame.sceneDepth*/, let confidence = depth.confidenceMap else {
                return
            }

            let camera = frame.camera
            dump(aCamera: camera, atTimeStamp: ts)

            if isActive {

                print("grab at \(ts)")

                guard let session = currentSession else {
                    return
                }

                if camCalibration == nil {

                    dump(anImage: frame.capturedImage, atTimeStamp: ts, aStore: true, aFileName: "preview.png")

                    let calibration = camera.value(forKey: "calibrationData") as! AVCameraCalibrationData
                    dump(calibration: calibration)

                    setCalibration(fromCamera: camera)
                    usleep(1000)
                    setConfiguration()
                    usleep(1000)

                    if !session.local {
                        _sessionManager!.startSet()
                        sleep(1)
                    }

                    _isAllowCapture = true

                    return
                }

                if _isAllowCapture {
//                    if !skipColor {
                        dump(anImage: frame.capturedImage, atTimeStamp: ts)
//                    }

                    dump(aDepth: depth.depthMap, aConfidence: confidence, atTimeStamp: ts, aThreshold: threshold)
                    dump(aConfidence: confidence, atTimeStamp: ts)
                    dump(aCamera: camera, atTimeStamp: ts)

                    if let attitude = motionManager.deviceMotion?.attitude {
                        dump(anAttitude: attitude, atTimestamp: ts)
                        dump(aRotationMatrix: attitude.rotationMatrix, atTimeStamp: ts)
                    }

                }

                processedFrames += 1

            } else {
                // Show preview
                show(aDepth: depth.depthMap, aConfigdence: depth.confidenceMap!, atTimeStamp: ts, aThreshold: threshold)
            }

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

extension LidarSessionViewController: ARCoachingOverlayViewDelegate {

    func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
//        btnReset.isHidden = true
//        btnExport.isHidden = true
//        btnStart.isHidden = true
    }

    func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
//        btnReset.isHidden = false
//        btnReset.isHidden = false
//        btnReset.isHidden = false
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


extension LidarSessionViewController : DGSessionManagerDelegate {

    func sessionDidFinishUploading(_ session: Session) {

        print("Finished uploading model")
        showAlert(message: "The model uploading finished") {
            self.navigationController?.popToRootViewController(animated: true)
        }
    }

    fileprivate func showAlert(title: String = "Information", message: String,
                               completionHandler:(() -> Void)? = nil) {

        let alert = UIAlertController.init(title: title,
                                           message: message,
                                           preferredStyle: .alert)

        let defaultAction = UIAlertAction.init(title: "OK", style: .default) {
            (action) in
            completionHandler?()
        }

        alert.addAction(defaultAction)
        self.present(alert, animated: true, completion: nil)
    }

    func session(_ session: Session, didFinishProcessingUrl url: URL) {

//        showAlert(message: "\(url)")
        UIApplication.shared.open(url)

    }

}

extension LidarSessionViewController: IDLVerticalSliderDelegate {
    func slider(_ slider: IDLVerticalSlider, diChangeValue value: Float) {
        setDepth(value)
    }

}

extension LidarSessionViewController: ARSCNViewDelegate {

    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        /*
        Create a node for a new ARMeshAnchor
        We are only interested in anchors that provide mesh
        */
        guard let meshAnchor = anchor as? ARMeshAnchor else {
            return nil
        }
        /* Generate a SCNGeometry (explained further) */
        let geometry = SCNGeometry(arGeometry: meshAnchor.geometry)

        /* Let's assign random color to each ARMeshAnchor/SCNNode be able to distinguish them in demo */
//        geometry.firstMaterial?.diffuse.contents = colorizer.assignColor(to: meshAnchor.identifier)

        /* Create node & assign geometry */
        let node = SCNNode()
        node.name = "DynamicNode-\(meshAnchor.identifier)"
        node.geometry = geometry
        return node
    }

    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        /* Update the node's geometry when mesh or position changes */
        guard let meshAnchor = anchor as? ARMeshAnchor else {
            return
        }
        /* Generate a new geometry */
        let newGeometry = SCNGeometry(arGeometry: meshAnchor.geometry)  /* regenerate geometry */

        /* Assign the same color (colorizer stores id <-> color map internally) */
//        newGeometry.firstMaterial?.diffuse.contents = colorizer.assignColor(to: meshAnchor.identifier)
//        ARSCNView

        /* Replace node's geometry with a new one */
        node.geometry = newGeometry
    }

}
