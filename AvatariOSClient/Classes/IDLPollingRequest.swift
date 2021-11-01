//
//  IDLPollingRequest.swift
//  AvatariOSClient
//
//  Created by Andrei Kazialetski on 8/26/20.
//

import UIKit

enum IDLPollingRequestError: Error {
    case IncorrectlyFormattedUrl
    case HttpError
}

public protocol IDLPollingRequestDelegate : class {
    func didReceive(_ request: IDLPollingRequest, data: Data?)
    func didReceiveError(_ error: Error?)
}

public class IDLPollingRequest: NSObject {

    var GlobalUserInitiatedQueue: DispatchQueue {
        return DispatchQueue.global(qos: .userInitiated)
    }

    var GlobalBackgroundQueue: DispatchQueue {
        return DispatchQueue.global(qos: .background)
    }

    weak var longPollDelegate: IDLPollingRequestDelegate?
    var request: URLRequest?

    private var _needStop: Bool = false

    init(delegate:IDLPollingRequestDelegate) {
        longPollDelegate = delegate
    }

    public func poll(endpointUrl:String) throws -> Void {

        guard let url = URL(string: endpointUrl) else {
            throw IDLPollingRequestError.IncorrectlyFormattedUrl
        }

        request = URLRequest(url: url)

        poll()
    }

    public func stop() {
        _needStop = true
    }

    private func poll() {
        GlobalBackgroundQueue.async {
            self.longPoll()
        }
    }

    private func longPoll() -> Void {

        if _needStop {
            return
        }

        autoreleasepool{

            do{

                let urlSession = URLSession.shared

                let dataTask = urlSession.dataTask(with: self.request!) { [self]
                    (data, response, error) in

                    if error == nil {

                        if !_needStop {

                            self.longPollDelegate?.didReceive(self, data: data)

                            // Check if polling needed

                            GlobalBackgroundQueue.asyncAfter(deadline: .now() + 10) {
                                self.poll()
                            }
                        }

                    } else {

                        self.longPollDelegate?.didReceiveError(error)
                    }
                }

                dataTask.resume()
            }
        }
    }
}
