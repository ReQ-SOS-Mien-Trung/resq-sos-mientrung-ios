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
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 6) {
                    Text("Người Dùng")
                        .font(.system(size: 34, weight: .heavy, design: .rounded))
                        .foregroundStyle(.white)
                    
                    HStack(spacing: 6) {
                        Circle()
                            .fill(bridgefyManager.connectedUsersList.isEmpty ? .gray : .green)
                            .frame(width: 10, height: 10)
                        Text("\(bridgefyManager.connectedUsersList.count) người trong mạng")
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.subheadline)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.6))
                    
                    TextField("Tìm kiếm theo tên hoặc số điện thoại...", text: $searchText)
                        .foregroundColor(.white)
                }
                .padding(12)
                .background(Color.white.opacity(0.15))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.bottom, 12)
                
                // Users List
                if bridgefyManager.connectedUsersList.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("Chưa có người dùng nào trong mạng")
                            .foregroundStyle(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                        
                        Text("Đợi người khác mở app và ở gần bạn")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                } else if filteredUsers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 60))
                            .foregroundColor(.white.opacity(0.3))
                        
                        Text("Không tìm thấy kết quả")
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .padding()
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(filteredUsers) { user in
                                UserRow(user: user) {
                                    selectedUser = user
                                    showDirectChat = true
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
        }
        .sheet(item: $selectedUser) { user in
            DirectChatView(
                bridgefyManager: bridgefyManager,
                recipient: user
            )
        }
    }
}

struct UserRow: View {
    let user: User
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.3))
                        .frame(width: 50, height: 50)
                    
                    Text(user.name.prefix(1).uppercased())
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)
                }
                
                // User info
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.name)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(user.phoneNumber)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.6))
                }
                
                Spacer()
                
                // Online status
                Circle()
                    .fill(user.isOnline ? .green : .gray)
                    .frame(width: 12, height: 12)
                
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding()
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
        }
    }
}
