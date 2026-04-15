//
//  UsersListView.swift
//  SosMienTrung
//
//  Danh sách users trong network + tìm kiếm
//

import SwiftUI

struct UsersListView: View {
    @ObservedObject var bridgefyManager: BridgefyNetworkManager
    @State private var searchText = ""
    @State private var selectedUser: User?
    @State private var showDirectChat = false
    @FocusState private var isSearchFocused: Bool
    
    var filteredUsers: [User] {
        if searchText.isEmpty {
            return bridgefyManager.connectedUsersList
        }
        return bridgefyManager.connectedUsersList.filter { user in
            user.name.localizedCaseInsensitiveContains(searchText) ||
            user.phoneNumber.contains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Editorial Header
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                EyebrowLabel(text: "MẠNG LƯỚI")
                Text("Người Dùng")
                    .font(DS.Typography.largeTitle)
                    .foregroundColor(DS.Colors.text)
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(bridgefyManager.connectedUsersList.isEmpty ? DS.Colors.textTertiary : DS.Colors.success)
                        .frame(width: 8, height: 8)
                    Text("\(bridgefyManager.connectedUsersList.count) người trong mạng")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }
                EditorialDivider(height: DS.Border.thick)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.top, DS.Spacing.md)

            // Search bar
            ResQTextField(placeholder: "Tìm kiếm theo tên hoặc số điện thoại...", text: $searchText, icon: "magnifyingglass")
                .focused($isSearchFocused)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)

            // Users List
            if bridgefyManager.connectedUsersList.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Spacer()
                    Image(systemName: "person.2.slash")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(DS.Colors.textTertiary)
                    Text("Chưa có người dùng nào trong mạng")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                    Text("Đợi người khác mở ứng dụng và ở gần bạn")
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textTertiary)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else if filteredUsers.isEmpty {
                VStack(spacing: DS.Spacing.md) {
                    Spacer()
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(DS.Colors.textTertiary)
                    Text("Không tìm thấy kết quả")
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.textSecondary)
                    Spacer()
                }
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredUsers) { user in
                            UserRow(user: user) {
                                selectedUser = user
                                showDirectChat = true
                            }
                            EditorialDivider()
                        }
                    }
                    .padding(.horizontal, DS.Spacing.md)
                }
            }
        }
        .background(DS.Colors.background)
        .sheet(item: $selectedUser) { user in
            DirectChatView(bridgefyManager: bridgefyManager, recipient: user)
        }
        .onTapGesture { isSearchFocused = false }
    }
}

struct UserRow: View {
    let user: User
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DS.Spacing.sm) {
                // Sharp square avatar
                ZStack {
                    Rectangle()
                        .fill(DS.Colors.accent.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Text(user.name.prefix(1).uppercased())
                        .font(.system(size: 18, weight: .black))
                        .foregroundColor(DS.Colors.accent)
                }
                .overlay(Rectangle().stroke(DS.Colors.border, lineWidth: DS.Border.thin))

                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name)
                        .font(DS.Typography.headline)
                        .foregroundColor(DS.Colors.text)
                    Text(user.phoneNumber)
                        .font(DS.Typography.caption)
                        .foregroundColor(DS.Colors.textSecondary)
                }

                Spacer()

                Rectangle()
                    .fill(user.isOnline ? DS.Colors.success : DS.Colors.textTertiary)
                    .frame(width: 8, height: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(DS.Colors.textTertiary)
            }
            .padding(.vertical, DS.Spacing.sm)
        }
    }
}
