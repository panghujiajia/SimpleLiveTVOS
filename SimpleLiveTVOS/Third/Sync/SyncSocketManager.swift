//
//  SyncSocketManager.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2024/4/1.
//

import Foundation
import CocoaAsyncSocket
import SwiftyJSON
import NIO
import NIOHTTP1
import LiveParse

enum SimpleSyncType {
    case favorite
    case history
    case danmuBlockWords
    case bilibiliCookie
}

let httpPort = 23234
let udpPort = 23235

protocol SyncManagerDelegate: AnyObject {
    func syncManagerDidReciveRequest(type: SimpleSyncType, needOverlay: Bool, info: Any)
}

class SyncManager {
    
    let httpHandler = HTTPHandler()
    var serverChannel: Channel?
    var delegate: SyncManagerDelegate?
    
    init() {
        
        httpHandler.syncSuccess = { type, needOverlay, result in
            self.delegate?.syncManagerDidReciveRequest(type: type, needOverlay: needOverlay, info: result)
        }
        
        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let bootstrap = ServerBootstrap(group: group)
            .childChannelInitializer { channel in
                channel.pipeline.configureHTTPServerPipeline().flatMap {
                    channel.pipeline.addHandler(self.httpHandler)
                }
            }
            .childChannelOption(ChannelOptions.maxMessagesPerRead, value: 1)
            .childChannelOption(ChannelOptions.recvAllocator, value: AdaptiveRecvByteBufferAllocator())

        do {
            serverChannel = try bootstrap.bind(host: Common.getWiFiIPAddress() ?? "localhost", port: httpPort).wait()
            print("Server is running on \(serverChannel?.localAddress?.ipAddress ?? "")")
        } catch {
            print("Failed to start server: \(error)")
        }
        
    }
    
    func closeServer() {
        try? serverChannel?.close().wait()
    }
}


class UDPListener: NSObject, GCDAsyncUdpSocketDelegate {
    
    var udpSocket: GCDAsyncUdpSocket?
    
    override init() {
        super.init()
        udpSocket = GCDAsyncUdpSocket(delegate: self, delegateQueue: DispatchQueue.main)
        do {
            try udpSocket?.bind(toPort: UInt16(udpPort)) // 绑定到任意可用端口
            try udpSocket?.beginReceiving() // 开始接收数据
        } catch {
            print("Failed to start UDP server: \(error)")
        }
    }
    
    func closeServer() {
        udpSocket?.close()
    }
    
    // GCDAsyncUdpSocketDelegate 方法
    func udpSocket(_ sock: GCDAsyncUdpSocket, didReceive data: Data, fromAddress address: Data, withFilterContext filterContext: Any?) {
        // 处理接收到的数据
        if let message = String(data: data, encoding: .utf8) {
            print("Received message: \(message)")
            do {
                let json = try JSON(data: data)
                if json["type"] == "hello" {
                    udpSocket?.send(try JSON(["id": UUID().uuidString, "type": "tv", "name": Common.hostName()]).rawData(), toAddress: address, withTimeout: 10, tag: 0)
                }
            }catch {
                
            }
        }
    }
}


final class HTTPHandler: ChannelInboundHandler {
    
    typealias InboundIn = HTTPServerRequestPart
    typealias OutboundOut = HTTPServerResponsePart
    var response: HTTPServerResponsePart?
    var responseBody: HTTPServerResponsePart?
    private var requestBody: ByteBuffer?
    var requestHeaderT: HTTPRequestHead?
    var syncSuccess: ((SimpleSyncType, Bool, Any) -> Void)?

    func channelRead(context: ChannelHandlerContext, data: NIOAny) {
        let reqPart = self.unwrapInboundIn(data)
        var headers = HTTPHeaders()
        headers.add(name: "Content-Type", value: "application/json")
        switch reqPart {
        case .head(let requestHeader):
            requestHeaderT = requestHeader
            if requestHeader.uri == "/" {
                responseBody = HTTPServerResponsePart.body(.byteBuffer(ByteBuffer(string: "Hello, World!")))
                response = .head(HTTPResponseHead(version: requestHeader.version, status: .ok))
            }else if requestHeader.uri == "/info" {
                let resp = JSON([
                    "id": UUID().uuidString,
                    "type": "tv",
                    "name": Common.hostName() ?? "Apple TV",
                    "version": "1.1.0",
                    "address": Common.getWiFiIPAddress() ?? "127.0.0.1",
                    "port": httpPort
                ]).rawString()
                
                responseBody = HTTPServerResponsePart.body(.byteBuffer(ByteBuffer(string: resp ?? "")))
                response = .head(HTTPResponseHead(version: requestHeader.version, status: .ok, headers: headers))
            }
        case .body(let byteBuffer):
            // 处理请求体
            requestBody = byteBuffer
        case .end:
            // 请求体已完全接收，处理请求
            if let body = requestBody, let bodyString = body.getString(at: 0, length: body.readableBytes) {
                print("Request body: \(bodyString)")
                do {
                    if requestHeaderT?.uri.contains("sync/follow") == true {
                        let resp = JSON([
                            "status": true,
                            "message": "success",
                        ]).rawString()
                        
                        let respList = formatDatas(bodyString: bodyString)
                        let overlay = getOverlayFormat(url: requestHeaderT?.uri ?? "")
                        if self.syncSuccess != nil {
                            self.syncSuccess!(.favorite, overlay, respList)
                        }

                        responseBody = HTTPServerResponsePart.body(.byteBuffer(ByteBuffer(string: resp ?? "")))
                        response = .head(HTTPResponseHead(version: requestHeaderT!.version, status: .ok, headers: headers))
                    }
                    if requestHeaderT?.uri.contains("sync/history") == true {
                        let resp = JSON([
                            "status": true,
                            "message": "success",
                        ]).rawString()
                        let respList = formatDatas(bodyString: bodyString)
                        let overlay = getOverlayFormat(url: requestHeaderT?.uri ?? "")
                        if self.syncSuccess != nil {
                            self.syncSuccess!(.history, overlay, respList)
                        }
                        responseBody = HTTPServerResponsePart.body(.byteBuffer(ByteBuffer(string: resp ?? "")))
                        response = .head(HTTPResponseHead(version: requestHeaderT!.version, status: .ok, headers: headers))
                    }
                    if requestHeaderT?.uri.contains("blocked_word") == true {
                        let resp = JSON([
                            "status": false,
                            "message": "Apple TV 端暂不支持此功能",
                        ]).rawString()
                        responseBody = HTTPServerResponsePart.body(.byteBuffer(ByteBuffer(string: resp ?? "")))
                        response = .head(HTTPResponseHead(version: requestHeaderT!.version, status: .ok, headers: headers))
                    }
                    if requestHeaderT?.uri.contains("account/bilibili") == true {
                        let resp = JSON([
                            "status": false,
                            "message": "Apple TV 端暂不支持此功能",
                        ]).rawString()
                        responseBody = HTTPServerResponsePart.body(.byteBuffer(ByteBuffer(string: resp ?? "")))
                        response = .head(HTTPResponseHead(version: requestHeaderT!.version, status: .ok, headers: headers))
                    }
                    
                }catch {
                    let resp = JSON([
                        "status": false,
                        "message": "解析数据异常",
                    ]).rawString()
                    responseBody = HTTPServerResponsePart.body(.byteBuffer(ByteBuffer(string: resp ?? "")))
                    response = .head(HTTPResponseHead(version: requestHeaderT!.version, status: .ok, headers: headers))
                }
            }
            // Create and write the response
            if response == nil {
                response = HTTPServerResponsePart.head(HTTPResponseHead(version: .init(major: 1, minor: 1), status: .ok, headers: headers))
            }
            context.write(self.wrapOutboundOut(response!), promise: nil)
            if responseBody == nil {
                responseBody = HTTPServerResponsePart.body(.byteBuffer(ByteBuffer(string: "welcome")))
            }
            context.write(self.wrapOutboundOut(responseBody!), promise: nil)
            
            let end = HTTPServerResponsePart.end(nil)
            context.writeAndFlush(self.wrapOutboundOut(end), promise: nil)
            context.close(promise: nil)
        }
    
    func formatDatas(bodyString: String) -> [LiveModel] {
        let resp = JSON([
            "status": true,
            "message": "success",
        ]).rawString()
        var tempArray:[LiveModel] = []
        if let respFollowList = try? JSON(data: bodyString.data(using: .utf8)!) {
            for item in respFollowList.arrayValue {
                var liveType = LiveType.bilibili
                switch item["siteId"].stringValue {
                    case "bilibili":
                        liveType = .bilibili
                    case "huya":
                        liveType = .huya
                    case "douyu":
                        liveType = .douyu
                    case "douyin":
                        liveType = .douyin
                    default:
                        liveType = .bilibili
                }
                tempArray.append(LiveModel(userName: item["userName"].stringValue, roomTitle: "", roomCover: "", userHeadImg: item["face"].stringValue, liveType: liveType, liveState: nil, userId: "", roomId: item["roomId"].stringValue, liveWatchedCount: nil))
            }
        }
        return tempArray
    }
        
        func getOverlayFormat(url: String) -> Bool {
            do {
                let pattern = "\\?overlay=(\\d+)"
                let regex = try NSRegularExpression(pattern: pattern)
                let nsString = url as NSString
                let results = regex.matches(in: url, options: [], range: NSMakeRange(0, nsString.length))
                var overlay = "0"
                for result in results {
                    overlay = nsString.substring(with: result.range(at: 1))
                }
                return Int(overlay) == 1 ? true : false
            }catch {
                return false
            }
        }
    }
}
