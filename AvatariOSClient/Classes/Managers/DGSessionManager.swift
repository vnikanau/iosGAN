//
//  DGSessionManager.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 8/24/20.
//

import UIKit
//import RMQClient

//fileprivate let __urlString: String = "amqp://idl:idlpwd@192.168.0.26:5672"
fileprivate let __defaultUrlString: String = "amqp://idl:idlpwd@gpu-08.indatalabs.com:5672"
fileprivate let __inboundQueueName: String = "q_s2c"
fileprivate let __outboundQueueName: String = "q_c2s"
fileprivate let __inboundQueueNamePlaceholder: String = "s2c_"
fileprivate let __outboundQueueNamePlaceholder: String = "c2s_"


@objc protocol DGSessionManagerDelegate {
    @objc optional func sessionDidFinishUploading(_ session:Session)
    @objc optional func session(_ session:Session, didFinishProcessingUrl url: URL)
}

class DGSessionManager {

    static let shared = DGSessionManager()

//    private var _rmqManager: IDLRMQManager!
    private var _sessionId: String = ""

    /*
    private var _inboundChannel: RMQChannel?
    private var _outboundChannel: RMQChannel?

    private var _inboundQueue: RMQQueue?
    private var _outboundQueue: RMQQueue?

    private var _inboundQueueName: String = ""
    private var _outboundQueueName: String = ""
     */

    private var _currentSession: Session? = nil

    private let _documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    private let _appDelegate = UIApplication.shared.delegate as? AppDelegate
    private let _jsonEncoder = JSONEncoder()
    private var _settingsManager: DGSettingsManager!
//    private let _jsonDecoder = JSONDecoder()

    private var _urlString: String!

    var currentSession: Session? {
        get {
            return _currentSession
        }
    }

    var delegate: DGSessionManagerDelegate? = nil

    private init() {
        _settingsManager = DGSettingsManager.shared
    }


    public func createSession(local: Bool) -> Bool {
        let sessionId = String(Int(Date().timeIntervalSince1970))

        if !self.createSession(withId: sessionId, local: local) {
            return false
        }

        guard let session = _currentSession else {
            return false
        }

        if !session.local {

//            if !self.createRMQSession(withId: sessionId) {
//                return false
//            }

        }

        return true
    }

    public func startSet() {
//        _ = _rmqManager.sendCommand(aCommand: "special:startset", aQueue: _outboundQueue)
    }

    public func endSet() {
//        _ = _rmqManager.sendCommand(aCommand: "special:endset", aQueue: _outboundQueue)
    }

    public func sendCameraCalibration(aCalibration: DGCameraCalibration) -> Bool {

        do {

            // 1. Convert to json
            let json = try _jsonEncoder.encode(aCalibration)
            #if DEBUG
            print(String(bytes: json, encoding: .utf8) as Any)
            #endif


            // 2. Send file
            return sendJson(json, withFileName: "cam_c_calib.json")

        } catch {
            print(error)
            return false
        }

    }

    public func storeCameraCalibration(aCalibration: DGCameraCalibration) -> Bool {

        do {

            // 1. Convert to json
            let json = try _jsonEncoder.encode(aCalibration)
            #if DEBUG
            print(String(bytes: json, encoding: .utf8) as Any)
            #endif

            guard let session = _currentSession else {
                return false
            }

            // 2. Store file
            let filePath = _documentsPath.appendingPathComponent(session.modelId!).appendingPathComponent("cam_c_calib.json")
            try json.write(to: filePath, options: .atomicWrite)

        } catch {
            print(error)
            return false
        }

        return true
    }

    public func sendDepthCalibration(aCalibration: DGDepthCalibration) -> Bool {

        do {

            // 1. Convert to json
            let json = try _jsonEncoder.encode(aCalibration)
            #if DEBUG
            print(String(bytes: json, encoding: .utf8) as Any)
            #endif


            // 2. Send file
            return sendJson(json, withFileName: "cam_d_calib.json")

        } catch {
            print(error)
            return false
        }

    }

    public func storeDepthCalibration(aCalibration: DGDepthCalibration) -> Bool {

        do {

            // 1. Convert to json
            let json = try _jsonEncoder.encode(aCalibration)
            #if DEBUG
            print(String(bytes: json, encoding: .utf8) as Any)
            #endif

            guard let session = _currentSession else {
                return false
            }

            // 2. Store file
            let filePath = _documentsPath.appendingPathComponent(session.modelId!).appendingPathComponent("cam_d_calib.json")
            try json.write(to: filePath, options: .atomicWrite)

        } catch {
            print(error)
            return false
        }

        return true
    }


    public func sendConfiuration(aConfigration: DGConfigurationModel) -> Bool {

        do {
            // 1. Convert to json
            let json = try _jsonEncoder.encode(aConfigration)

            #if DEBUG
            print(String(bytes: json, encoding: .utf8) as Any)
            #endif

            // 2. Send file
            return sendJson(json, withFileName: "config.json")

        } catch {

            print(error)
            return false

        }
    }

    public func storeConfiuration(aConfigration: DGConfigurationModel) -> Bool {

        do {

            // 1. Convert to json
            let json = try _jsonEncoder.encode(aConfigration)
            #if DEBUG
            print(String(bytes: json, encoding: .utf8) as Any)
            #endif

            guard let session = _currentSession else {
                return false
            }

            // 2. Store file
            let filePath = _documentsPath.appendingPathComponent(session.modelId!).appendingPathComponent("config.json")
            try json.write(to: filePath, options: .atomicWrite)

        } catch {
            print(error)
            return false
        }

        return true

    }

    public func sendImage(_ imageData: Data, atTimeStamp timeStamp: UInt64) {

        /*
        let messageId = "\(timeStamp)"
        let fileName = "\(timeStamp)_c.png"
        */
//        _ = _rmqManager.sendData(aData: imageData, aContentType: fileName, aMessageId: messageId, aQueue: _outboundQueue)

    }

    public func sendDepth(_ depthData: Data, atTimeStamp timeStamp: UInt64) {

        /*
        let messageId = "\(timeStamp)"
        let fileName = "\(timeStamp)_d.png"
        */
//        _ = _rmqManager.sendData(aData: depthData, aContentType: fileName, aMessageId: messageId, aQueue: _outboundQueue)
    }

    public func deleteSession(_ session: Session) {

        do {

            guard let modelId = session.modelId else {
                return
            }

            let sessionPath = _documentsPath.appendingPathComponent(modelId)
            var isDir:ObjCBool = true

            if FileManager.default.fileExists(atPath: sessionPath.path, isDirectory: &isDir) {

                let filePaths = try FileManager.default.contentsOfDirectory(at: sessionPath,
                                                                           includingPropertiesForKeys: nil,
                                                                           options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants])
                for fileURL in filePaths {
                    try FileManager.default.removeItem(at: fileURL)
                }

                try FileManager.default.removeItem(at: sessionPath)

            }

            guard let appDelegate =
              UIApplication.shared.delegate as? AppDelegate else {
              return
            }

            let managedContext =
               appDelegate.persistentContainer.viewContext

            managedContext.delete(session)
            try managedContext.save()

        } catch  { print(error) }

    }

    // MARK: - Private methods

    private func sendJson(_ jsonData:Data, withFileName fileName:String) -> Bool {
        //let result = _rmqManager.sendData(aData: jsonData, aContentType: fileName, aMessageId: "0", aQueue: _outboundQueue)
        let result = -1
        return result != -1
    }

    private func createSession(withId anId:String, local: Bool) -> Bool {
        // TODO: Implementation

        let path = _documentsPath.appendingPathComponent(anId)

        if !createDBSession(withId: anId, local: local) {
            return false
        }

        if local {

            if !createSessionDirectory(atPath: path) {
                return false
            }

            _currentSession?.path = path
            saveContext()

        }

        return true
    }

    private func createDBSession(withId anId: String, local: Bool) -> Bool {
        
        guard let appDelegate = _appDelegate else {
            return false
        }

        let managedContext = appDelegate.persistentContainer.viewContext

        let session = Session(context: managedContext)
        session.date = Date(timeIntervalSince1970: TimeInterval(anId) ?? Date().timeIntervalSince1970)
        session.modelId = anId
        session.local = local

        saveContext()

        _currentSession = session

        return true
    }

    private func updateServerUrl() {

        let url = _settingsManager.url

        if url != nil {
            _urlString = url!.absoluteString
        } else {
            _urlString = __defaultUrlString
        }
    }

//    private func createRMQSession(withId anId: String) -> Bool {
//
//        updateServerUrl()
//
//        _rmqManager = IDLRMQManager(anUri: _urlString,
//                                    anInboundQueueName: __inboundQueueName,
//                                    anOutboundQueueName: __outboundQueueName)
//        _rmqManager.start()
//
//
//
//        let tmpName = _rmqManager.createSession(withId: anId)
//
//        if tmpName == "" {
//            return false
//        }
//
//        _inboundQueueName = __inboundQueueNamePlaceholder + tmpName
//        _outboundQueueName = __outboundQueueNamePlaceholder + tmpName
//
//        _outboundChannel = _rmqManager.channel()
//        _inboundChannel = _rmqManager.channel()
//
//        _outboundQueue = _rmqManager.queue(aChanel: _outboundChannel!, aQueueName: _outboundQueueName)
//        _inboundQueue = _rmqManager.queue(aChanel: _inboundChannel!, aQueueName: _inboundQueueName)
//
//        subscribe(aChannel: _inboundChannel!, aQueue: _inboundQueue!)
//
//        return true
//    }

//    func subscribe(aChannel: RMQChannel, aQueue: RMQQueue) {
//
//        print("Waiting for messages.")
//
//        let consumer:RMQConsumer? = aQueue.subscribe([]) { [self] (message: RMQMessage) in
//
//            let contentType = message.contentType()
//            let body = String(data: message.body, encoding: .utf8)
//
//
//            if contentType! == "info" {
//
//                DispatchQueue.global().async {
//                    processUploadedModelUrl(body!)
//                }
//
//                // send command on delete queue
//                _outboundChannel!.queueDelete(_inboundQueueName, options: [])
//                _outboundChannel!.close()
//
//                // Stop monitoring inbound queue
//                _inboundChannel!.close()
//
//                _rmqManager.close()
//            } else {
//                // TODO: Process if needed
//            }
//
//        }
//
//        print(consumer as Any)
//    }

    func processUploadedModelUrl(_ urlString:String) {

        guard let url = URL(string: urlString) else {
            print("Error while parsing url")
            // TODO: Notify error
            return
        }

        guard let session = currentSession else {
            print("Problem with session")
            return
        }

        session.uploaded = true
        session.modelDetailsUrl = url


        // 1. Notify that model uploaded
        DispatchQueue.main.async { [self] in

            self.saveContext()

            self.delegate?.sessionDidFinishUploading?(session)
        }

        // 2. PollRequest
        let req = IDLPollingRequest(delegate: self)
        
        do {

            try req.poll(endpointUrl: urlString)

        } catch {
            print(error)
        }

        // 3. Check if status succeeded got 5

        // 4. if no goto 2
        // 5. Get model url

        print(urlString)
    }

    // MARK: - Private

    private func createSessionDirectory(atPath path: URL) -> Bool {
        
        do {
            try FileManager.default.createDirectory(at: path, withIntermediateDirectories: true, attributes: [:])
        } catch {
            print(error)
            return false
        }

        return true
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

}


// MARK: - IDLPollingRequestDelegate

extension DGSessionManager: IDLPollingRequestDelegate {

    func didReceive(_ request: IDLPollingRequest, data: Data?) {

        // Parse JSON
        guard let model = try? JSONDecoder().decode(DGSketchfabModel.self, from: data!) else {
            return
        }

        print("Status: \(model.status.processing)")

        // Check status
        if model.status.processing == "SUCCEEDED" {
            request.stop()

            guard let session = currentSession else {
                return
            }

            guard let modelUrl = URL(string: model.viewerURL) else {
                return
            }

            print("Model URL: \(modelUrl)")

            session.modelUrl = modelUrl
            session.processed = true

            DispatchQueue.main.async { [self] in

                self.saveContext()

                self.delegate?.session?(session, didFinishProcessingUrl: modelUrl)
            }

        }
        
    }

    func didReceiveError(_ error: Error?) {
        // TODO: Notify error

    }
}
