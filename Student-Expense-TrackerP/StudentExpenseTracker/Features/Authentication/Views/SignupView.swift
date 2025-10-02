import SwiftUI

struct SignupView: View {
    @Bindable var authVM: AuthViewModel

    @State private var fullName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var phoneNumber = ""
    @State private var dateOfBirth = Date()

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.verticalPadding) {
                Text("Sign Up")
                    .font(AppFonts.title)
                    .foregroundColor(AppColors.textPrimary)

                Group {
                    TextField("Full Name", text: $fullName)
                        .font(AppFonts.body)

                    TextField("Email", text: $email)
                        .keyboardType(.emailAddress)
                        .font(AppFonts.body)

                    SecureField("Password", text: $password)
                        .font(AppFonts.body)

                    SecureField("Confirm Password", text: $confirmPassword)
                        .font(AppFonts.body)

                    TextField("Phone Number", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .font(AppFonts.body)
                }
                .padding()
                .frame(height: AppSpacing.fieldHeight)
                .background(AppColors.cardBackground)
                .cornerRadius(AppSpacing.cornerRadius)
                .foregroundColor(AppColors.textPrimary)

                DatePicker("Date of Birth", selection: $dateOfBirth, displayedComponents: .date)
                    .padding()
                    .background(AppColors.cardBackground)
                    .cornerRadius(AppSpacing.cornerRadius)
                    .font(AppFonts.body)

                Button("Create Account") {
                    signUp()
                }
                .frame(maxWidth: .infinity)
                .frame(height: AppSpacing.fieldHeight)
                .background(AppColors.primary)
                .foregroundColor(.white)
                .cornerRadius(AppSpacing.cornerRadius)
                .font(AppFonts.body)

                if let error = authVM.errorMessage {
                    Text(error)
                        .foregroundColor(AppColors.error)
                        .font(AppFonts.small)
                }
            }
            .padding(AppSpacing.horizontalPadding)
        }
        .background(AppColors.backgroundDefault.ignoresSafeArea())
        .cornerRadius(AppSpacing.cornerRadius)
    }

    func signUp() {
        authVM.errorMessage = nil

        guard !fullName.isEmpty,
              !email.isEmpty,
              !password.isEmpty,
              !confirmPassword.isEmpty else {
            authVM.errorMessage = "Please fill in all fields."
            return
        }

        guard isValidEmail(email) else {
            authVM.errorMessage = "Please enter a valid email address."
            return
        }

        guard password.count >= 6 else {
            authVM.errorMessage = "Password must be at least 6 characters."
            return
        }

        guard password == confirmPassword else {
            authVM.errorMessage = "Passwords do not match."
            return
        }

        authVM.signup(email: email, password: password) {
            authVM.saveUserProfile(
                fullName: fullName,
                phoneNumber: phoneNumber,
                dateOfBirth: dateOfBirth
            )
        }
    }

    func isValidEmail(_ email: String) -> Bool {
        let emailRegEx = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}"
        return NSPredicate(format: "SELF MATCHES %@", emailRegEx).evaluate(with: email)
    }
}
