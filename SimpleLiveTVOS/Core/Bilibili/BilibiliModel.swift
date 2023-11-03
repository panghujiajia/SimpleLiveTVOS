//
//  BilibiliModel.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2023/7/4.
//

import Foundation
import Alamofire

struct BilibiliMainData<T: Codable>: Codable {
    var code: Int
    var msg: String
    var data: T
    
    enum CodingKeys: String, CodingKey {
        case code
        case msg = "message"
        case data
    }
}

struct BilibiliMainListModel: Codable {
    let id: Int
    let name: String
    let list: Array<BilibiliCategoryModel>?
}

struct BilibiliCategoryModel: Codable {
    let id: String
    let parent_id: String
    let old_area_id: String
    let name: String
    let act_id: String
    let pk_status: String
    let hot_status: Int
    let lock_status: String
    let pic: String
    let parent_name: String
    let area_type: Int
}


struct BiliBiliCategoryRoomMainModel: Codable {
    let banner: Array<BiliBiliCategoryBannerModel>?
    let list: Array<BiliBiliCategoryListModel>?
}

struct BiliBiliCategoryBannerModel: Codable {
    let id: Int
    let title: String
    let location: String
    let position: Int
    let pic: String
    let link: String
    let weight: Int
    let room_id: Int
    let up_id: Int
    let parent_area_id: Int
    let area_id: Int
    let live_status: Int
    let av_id: Int
    let is_ad: Bool
}

struct BiliBiliCategoryListModel: Codable {
    let roomid: Int
    let uid: Int
    let title: String
    let uname: String
    let online: Int
    let user_cover: String
    let user_cover_flag: Int
    let system_cover: String
    let cover: String
    let show_cover: String
    let link: String
    let face: String
    let parent_id: Int
    let parent_name: String
    let area_id: Int
    let area_name: String
    let area_v2_parent_id: Int
    let area_v2_parent_name: String
    let area_v2_id: Int
    let area_v2_name: String
    let session_id: String
    let group_id: Int
    let show_callback: String
    let click_callback: String
    let verify: BiliBiliVerifyModel
    let watched_show: BiliBiliWatchedShowModel
}

struct BiliBiliVerifyModel: Codable {
    let role: Int
    let desc: String
    let type: Int
}

struct BiliBiliWatchedShowModel: Codable {

    let the_switch: Bool
    let num: Int
    let text_small: String
    let text_large: String
    let icon: String
    let icon_location: Int
    let icon_web: String
    
    private enum CodingKeys: String, CodingKey {
        case the_switch = "switch"
        case num
        case text_small
        case text_large
        case icon
        case icon_location
        case icon_web
    }
}


struct BiliBiliQualityModel: Codable {
    let current_qn: Int
    let quality_description: Array<BiliBiliQualityDetailModel>?
//    let durl: Array<BilibiliPlayInfoModel>?
}

struct BiliBiliQualityDetailModel: Codable {
    let qn: Int
    let desc: String
}


struct BiliBiliPlayURLInfoMain: Codable {
    var playurl_info: BiliBiliPlayURLPlayURLInfo
    
//    var room_id: Int
}

struct BiliBiliPlayURLPlayURLInfo: Codable {
    var playurl: BiliBiliPlayURLPlayURL
    var conf_json: String
}

struct BiliBiliPlayURLPlayURL: Codable {
    var stream: Array<BiliBiliPlayURLStreamInfo>
}

struct BiliBiliPlayURLStreamInfo: Codable {
    var protocol_name: String
    var format: Array<BiliBiliPlayURLFormatInfo>
}

struct BiliBiliPlayURLFormatInfo: Codable {
    var format_name: String
    var codec: Array<BiliBiliPlayURLCodeCInfo>
}


struct BiliBiliPlayURLCodeCInfo: Codable {
    var codec_name: String
    var base_url: String
    var url_info: Array<BilibiliPlayInfoModel>
}

struct BilibiliPlayInfoModel: Codable {
    let host: String
    let extra: String
}

class Bilibili {
    public class func getBiliBiliList() async throws -> BilibiliMainData<[BilibiliMainListModel]> {
        return try await AF.request("https://api.live.bilibili.com/room/v1/Area/getList", method: .get).serializingDecodable(BilibiliMainData.self).value
    }
    
    public class func getCategoryRooms(category: BilibiliCategoryModel, page: Int) async throws -> Array<LiveModel> {
        let dataReq = try await AF.request(
            "https://api.live.bilibili.com/xlive/web-interface/v1/second/getList",
            method: .get,
            parameters: [
                "platform": "web",
                "parent_area_id": category.parent_id,
                "area_id": category.id,
                "sort_type": "",
                "page": page
            ]
        ).serializingDecodable(BilibiliMainData<BiliBiliCategoryRoomMainModel>.self).value
        if dataReq.code == 0 {
            if let listModelArray = dataReq.data.list {
                var tempArray: Array<LiveModel> = []
                for item in listModelArray {
                    tempArray.append(LiveModel(userName: item.uname, roomTitle: item.title, roomCover: item.cover, userHeadImg: item.face, liveType: .bilibili, liveState: "", userId: "\(item.uid)", roomId: "\(item.roomid)"))
                }
                return tempArray
            }else {
                return []
            }
        }else {
            return []
        }
    }

    public class func getVideoQualites(roomModel: LiveModel) async throws -> BilibiliMainData<BiliBiliQualityModel> {
        do {
            let dataReq = try await AF.request(
                "https://api.live.bilibili.com/room/v1/Room/playUrl",
                method: .get,
                parameters: [
                    "platform": "web",
                    "cid": roomModel.roomId,
                    "qn": ""
                ]
            ).serializingDecodable(BilibiliMainData<BiliBiliQualityModel>.self).value
            if dataReq.code != 0 {
                return BilibiliMainData(code: 0, msg: "解析清晰度错误", data: .init(current_qn: 10000, quality_description: [.init(qn: 10000, desc: "清晰")]))
            }else {
                return dataReq
            }
            
        }catch {
            return BilibiliMainData(code: 0, msg: "解析清晰度错误", data: .init(current_qn: 10000, quality_description: [.init(qn: 10000, desc: "清晰")]))
        }
    }

    public class func getPlayUrl(roomId: String, qn: Int) async throws -> BilibiliMainData<BiliBiliPlayURLInfoMain> {
        return try await AF.request(
            "https://api.live.bilibili.com/xlive/web-room/v2/index/getRoomPlayInfo",
            method: .get,
            parameters: [
                "platform": "web",
                "room_id": roomId,
                "qn": qn,
                "protocol": "0,1",
                "format": "0,2",
                "codec": "0,1",
                "mask": "0"
            ]
        ).serializingDecodable(BilibiliMainData.self).value
    }
    
    public class func getLiveStatus(roomId: String) async throws -> Int {
        let dataReq = try await AF.request(
            "https://api.live.bilibili.com/room/v1/Room/get_info",
            method: .get,
            parameters: [
                "room_id": roomId
            ]
        ).serializingData().value
        
        let json = try JSONSerialization.jsonObject(with: dataReq, options: .mutableContainers)
        let jsonDict = json as! Dictionary<String, Any>
        let dataDict = jsonDict["data"] as! Dictionary<String, Any>
        let liveStatus = dataDict["live_status"] as? Int ?? -1
        return liveStatus
    }
}
