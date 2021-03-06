//
//  KingSocksProxy.swift
//  KingProxy
//
//  Created by Purkylin King on 2018/2/1.
//  Copyright © 2018年 Purkylin King. All rights reserved.
//

import Foundation
import CocoaLumberjackSwift
import CocoaAsyncSocket

public class KingSocksProxy: NSObject {
    /// Set forward proxy
    public var forwardProxy: ForwardProxy?
    
    private var address = "127.0.0.1"
    private var port: UInt16 = 0
    
    private var sessions = Set<SocksSession>()
    private var listenSocket: GCDAsyncSocket!
    
    public override init() {
        super.init()
        
        let queue = DispatchQueue(label: "com.purkylin.kingproxy.socks")
        let socketQueue = DispatchQueue(label: "com.purkylin.kingproxy.socks.socket", qos: .background, attributes: [.concurrent], autoreleaseFrequency: .inherit, target: nil)
        listenSocket = GCDAsyncSocket(delegate: self, delegateQueue: queue, socketQueue: socketQueue)
    }
    
    /// Init server with listen host and port
    public convenience init(address: String) {
        self.init()
        self.address = address
    }
    
    /// Start server, return lister port if succes else return 0
    public func start(on port: UInt16) -> UInt16 {
        self.port = port
        do {
            #if os(macOS)
                try listenSocket.accept(onPort: port)
            #else
                try listenSocket.accept(onInterface: address, port: port)
            #endif
            self.port = listenSocket.localPort
            DDLogInfo("[http] Start socks proxy on port:\(port) ok")
            return self.port
        } catch let e {
            DDLogError("[http] Start socks proxy failed: \(e.localizedDescription)")
            self.port = 0
            return self.port
        }
    }
    
    /// Start proxy server
    public func start() -> UInt16 {
        return start(on: self.port )
    }
    
    /// Stop proxy server
    public func stop() {
        listenSocket.disconnectAfterWriting()
        DDLogInfo("[http] Stop http proxy server")
    }
}

extension KingSocksProxy: GCDAsyncSocketDelegate, SocksSessionDelegate {
    public func socket(_ sock: GCDAsyncSocket, didAcceptNewSocket newSocket: GCDAsyncSocket) {
        let session = SocksSession(socket: newSocket, proxy: forwardProxy)
        sessions.insert(session)
        session.delegate = self
        DDLogInfo("[socks] New session, count:\(sessions.count)")
    }
    
    func sessionDidDisconnect(session: SocksSession) {
        if sessions.contains(session) {
            sessions.remove(session)
        }
        DDLogInfo("[socks] Disconnect session, count:\(sessions.count)")
    }
}


