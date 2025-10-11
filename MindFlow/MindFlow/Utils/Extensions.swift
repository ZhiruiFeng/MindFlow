//
//  Extensions.swift
//  MindFlow
//
//  Created on 2025-10-10.
//

import Foundation
import SwiftUI

// MARK: - Color Extensions

extension Color {
    /// 主题色
    static let mindflowBlue = Color(red: 0.0, green: 0.48, blue: 1.0)
    static let mindflowGreen = Color(red: 0.2, green: 0.78, blue: 0.35)
    static let mindflowRed = Color(red: 1.0, green: 0.23, blue: 0.19)
    static let mindflowOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
}

// MARK: - String Extensions

extension String {
    /// 移除字符串首尾的空白字符和换行符
    var trimmed: String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// 检查字符串是否为空（包括只有空白字符的情况）
    var isBlank: Bool {
        return self.trimmed.isEmpty
    }
    
    /// 截取字符串到指定长度，超出部分用省略号代替
    func truncate(to length: Int, addEllipsis: Bool = true) -> String {
        if self.count <= length {
            return self
        }
        
        let truncated = String(self.prefix(length))
        return addEllipsis ? truncated + "..." : truncated
    }
}

// MARK: - TimeInterval Extensions

extension TimeInterval {
    /// 格式化为 MM:SS 格式
    var formattedMMSS: String {
        let minutes = Int(self) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    /// 格式化为 HH:MM:SS 格式
    var formattedHHMMSS: String {
        let hours = Int(self) / 3600
        let minutes = (Int(self) % 3600) / 60
        let seconds = Int(self) % 60
        return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
    }
}

// MARK: - Date Extensions

extension Date {
    /// 格式化为友好的相对时间描述
    var relativeTimeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.localizedString(for: self, relativeTo: Date())
    }
    
    /// 格式化为 yyyy-MM-dd HH:mm:ss
    var fullDateTimeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "zh_CN")
        return formatter.string(from: self)
    }
}

// MARK: - View Extensions

extension View {
    /// 条件性应用修饰符
    @ViewBuilder
    func `if`<Transform: View>(_ condition: Bool, transform: (Self) -> Transform) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
    
    /// 添加圆角边框
    func roundedBorder(cornerRadius: CGFloat = 8, color: Color = .secondary, lineWidth: CGFloat = 1) -> some View {
        self
            .cornerRadius(cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(color, lineWidth: lineWidth)
            )
    }
}

// MARK: - URL Extensions

extension URL {
    /// 获取文件大小（字节）
    var fileSize: Int64? {
        guard let attributes = try? FileManager.default.attributesOfItem(atPath: self.path) else {
            return nil
        }
        return attributes[.size] as? Int64
    }
    
    /// 格式化文件大小为可读字符串
    var fileSizeString: String? {
        guard let size = fileSize else { return nil }
        
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
}

