import SwiftUI
import AuthenticationServices

struct LoginView: View {
    @Bindable var authVM: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false

    private let appleSignInCoordinator = SignInWithAppleCoordinator()

    var body: some View {
        VStack(spacing: AppSpacing.verticalPadding) {
      
            TextField("Email", text: $email)
                .padding()
                .frame(height: AppSpacing.fieldHeight)
                .background(AppColors.cardBackground)
                .cornerRadius(AppSpacing.cornerRadius)
                .foregroundColor(AppColors.textPrimary)
                .autocapitalization(.none)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .font(AppFonts.body)

            SecureField("Password", text: $password)
                .padding()
                .frame(height: AppSpacing.fieldHeight)
                .background(AppColors.cardBackground)
                .cornerRadius(AppSpacing.cornerRadius)
                .foregroundColor(AppColors.textPrimary)
                .font(AppFonts.body)

            Toggle(isOn: $rememberMe) {
                Text("Remember Me")
                    .font(AppFonts.body)
                    .foregroundColor(AppColors.textPrimary)
            }
            .toggleStyle(SwitchToggleStyle(tint: AppColors.primary))
            .padding(.top, 8)

            Button("Login") {
                if rememberMe {
                    UserDefaults.standard.set(email, forKey: "savedEmail")
                    UserDefaults.standard.set(password, forKey: "savedPassword")
                    UserDefaults.standard.set(true, forKey: "rememberMe")
                } else {
                    UserDefaults.standard.removeObject(forKey: "savedEmail")
                    UserDefaults.standard.removeObject(forKey: "savedPassword")
                    UserDefaults.standard.set(false, forKey: "rememberMe")
                }
                authVM.login(email: email, password: password)
            }
            .frame(maxWidth: .infinity)
            .frame(height: AppSpacing.fieldHeight)
            .background(AppColors.primary)
            .foregroundColor(.white)
            .cornerRadius(AppSpacing.cornerRadius)
            .font(AppFonts.body)

            SignInWithAppleButton()
                .frame(height: 44)
                .padding(.top, 12)
                .onTapGesture {
                    appleSignInCoordinator.startSignInWithAppleFlow()
                }

            if let error = authVM.errorMessage {
                Text(error)
                    .foregroundColor(AppColors.error)
                    .font(AppFonts.small)
            }
        }
        .padding(AppSpacing.horizontalPadding)
        .background(AppColors.backgroundDefault.ignoresSafeArea())
        .cornerRadius(AppSpacing.cornerRadius)
        .onAppear {
            let savedRememberMe = UserDefaults.standard.bool(forKey: "rememberMe")
            rememberMe = savedRememberMe
            if savedRememberMe {
                email = UserDefaults.standard.string(forKey: "savedEmail") ?? ""
                password = UserDefaults.standard.string(forKey: "savedPassword") ?? ""
            }
        }
    }
}
