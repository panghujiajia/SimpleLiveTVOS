//
//  ApiManager.swift
//  SimpleLiveTVOS
//
//  Created by pc on 2023/12/29.
//

import Foundation
import LiveParse

class ApiManager {
    /**
     获取当前房间直播状态。
     
     - Returns: 直播状态
    */
    class func getCurrentRoomLiveState(roomId: String, userId: String?, liveType: LiveType) async throws -> LiveState {
        switch liveType {
            case .bilibili:
                return try await Bilibili.getLiveState(roomId: roomId, userId: nil)
            case .huya:
                return try await Huya.getLiveState(roomId: roomId, userId: nil)
            case .douyin:
                return try await Douyin.getLiveState(roomId: roomId, userId: userId)
            case .douyu:
                return try await Douyu.getLiveState(roomId: roomId, userId: nil)
            default:
                return .unknow
        }
    }

    class func fetchRoomList(liveCategory: LiveCategoryModel, page: Int, liveType: LiveType) async throws -> [LiveModel] {
        switch liveType {
            case .bilibili:
                return try await Bilibili.getRoomList(id: liveCategory.id, parentId: liveCategory.parentId, page: page)
            case .huya:
                return try await Huya.getRoomList(id: liveCategory.id, parentId: liveCategory.parentId, page: page)
            case .douyin:
                return try await Douyin.getRoomList(id: liveCategory.id, parentId: liveCategory.parentId, page: page)
            case .douyu:
                return try await Douyu.getRoomList(id: liveCategory.id, parentId: liveCategory.parentId, page: page)
            default:
                return []
        }
    }

    class func fetchCategoryList(liveType: LiveType) async throws -> [LiveMainListModel] {
        switch liveType {
            case .bilibili:
                return try await Bilibili.getCategoryList()
            case .huya:
                return try await Huya.getCategoryList()
            case .douyin:
                return try await Douyin.getCategoryList()
            case .douyu:
                return try await Douyu.getCategoryList()
            default:
                return []
            }
    }

}
