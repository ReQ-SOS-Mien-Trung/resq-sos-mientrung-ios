//
//  SetupProfileView.swift
//  SosMienTrung
//
//  Màn hình setup profile lần đầu
//

import SwiftUI

struct SetupProfileView: View {
    @ObservedObject var userProfile = UserProfile.shared
    @State private var name = ""
    @State private var phoneNumber = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @Binding var isSetupComplete: Bool
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.blue)
                    
                    Text("Thiết Lập Thông Tin")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    
                    Text("Để người khác có thể nhận diện bạn trong mạng")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // Form
                VStack(spacing: 20) {
                    // Name field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tên của bạn")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            
                            TextField("Nhập tên...", text: $name)
                                .textContentType(.name)
                                .autocapitalization(.words)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // Phone field
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Số điện thoại")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                        
                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.green)
                                .frame(width: 20)
                            
                            TextField("Nhập số điện thoại...", text: $phoneNumber)
                                .textContentType(.telephoneNumber)
                                .keyboardType(.phonePad)
                                .foregroundColor(.white)
                        }
                        .padding()
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                
                Spacer()
                
                // Save button
                Button {
                    saveProfile()
                } label: {
                    Text("Bắt Đầu")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            isFormValid ? Color.blue : Color.gray
                        )
                        .cornerRadius(12)
                }
                .disabled(!isFormValid)
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .alert("Lỗi", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !phoneNumber.trimmingCharacters(in: .whitespaces).isEmpty &&
        phoneNumber.count >= 9
    }
    
    private func saveProfile() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedPhone = phoneNumber.trimmingCharacters(in: .whitespaces)
        
        guard !trimmedName.isEmpty else {
            errorMessage = "Vui lòng nhập tên"
            showError = true
            return
        }
        
        guard trimmedPhone.count >= 9 else {
            errorMessage = "Số điện thoại không hợp lệ"
            showError = true
            return
        }
        
        userProfile.saveUser(name: trimmedName, phoneNumber: trimmedPhone)
        isSetupComplete = true
    }
}
