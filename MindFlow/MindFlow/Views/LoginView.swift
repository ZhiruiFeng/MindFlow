//
//  LoginView.swift
//  MindFlow
//
//  Created on 2025-10-12.
//

import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authService: SupabaseAuthService
    @ObservedObject private var settings = Settings.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            // App Logo
            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 140, height: 140)
                .shadow(radius: 8)

            // Welcome Text
            VStack(spacing: 8) {
                Text("Welcome to MindFlow")
                    .font(.title)
                    .bold()
                Text("Sign in to sync your data with ZephyrOS")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Login Buttons
            VStack(spacing: 16) {
                // Google Sign In Button
                Button(action: {
                    handleGoogleSignIn()
                }) {
                    HStack {
                        Image(systemName: "g.circle.fill")
                            .font(.title3)
                        Text("Sign in with Google")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white)
                    .foregroundColor(.black)
                    .cornerRadius(10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Skip Button
                Button(action: {
                    skipLogin()
                }) {
                    Text("Continue as Guest")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()
                }
                .buttonStyle(.plain)
                .disabled(isLoading)

                // Error Message
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 40)

            Spacer()

            // Privacy Note
            Text("By signing in, you agree to our Terms of Service and Privacy Policy")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
        }
        .frame(width: 400, height: 500)
        .onChange(of: authService.isAuthenticated) { isAuthenticated in
            if isAuthenticated {
                settings.hasCompletedLoginFlow = true
                dismiss()
            }
        }
        .onAppear {
            Task {
                await authService.restoreSession()
                if authService.isAuthenticated {
                    settings.hasCompletedLoginFlow = true
                    dismiss()
                }
            }
        }
    }

    // MARK: - Helper Methods

    private func handleGoogleSignIn() {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                try await authService.signIn()
                await MainActor.run {
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    isLoading = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func skipLogin() {
        settings.hasCompletedLoginFlow = true
        dismiss()
    }
}

// MARK: - Preview

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
    }
}
