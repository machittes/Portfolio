import SwiftUI

struct ProfileView: View {
    
    @EnvironmentObject var fireAuthHelper: FireAuthHelper
    
    @State private var name: String
    @State private var email: String
    @State private var address: String
    @State private var phoneNumber: String
    @State private var creditCard: String
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    
    @State private var isModified = false // check for modification
    @State private var showSuccessMessage = false // show success alert
    
    private let userType: String

    init() {
        let user = FireAuthHelper.getInstance().user ?? UserModel(id: "", name: "", email: "", address: "", phoneNumber: "", typeOfUser: "", creditCard: nil)
        
        _name = State(initialValue: user.name)
        _email = State(initialValue: user.email)
        _address = State(initialValue: user.address)
        _phoneNumber = State(initialValue: user.phoneNumber)
        _creditCard = State(initialValue: user.creditCard ?? "")
        userType = user.typeOfUser // Valor fixo
    }
    
    var body: some View {
        VStack(spacing: 20) {
            
            Text("User Profile")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, -30)
            
            Form {
                TextField("Full Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: name) { _ in checkForChanges() }

                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                    .onChange(of: email) { _ in checkForChanges() }

                TextField("Address", text: $address)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: address) { _ in checkForChanges() }

                TextField("Phone Number", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)
                    .onChange(of: phoneNumber) { _ in checkForChanges() }
                
                TextField("Credit Card (Optional)", text: $creditCard)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: creditCard) { _ in checkForChanges() }
                
                // User Type (Fixed)
                HStack {
                    Text("User Type:")
                        .fontWeight(.bold)
                    Spacer()
                    Text(userType)
                        .foregroundColor(.gray)
                }
                
                // Password Fields
                SecureField("New Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: password) { _ in checkForChanges() }

                SecureField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: confirmPassword) { _ in checkForChanges() }
            }
            .padding(.horizontal, 20)

            // Save Button
            Button(action: saveChanges) {
                Text("Save Changes")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isModified ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .disabled(!isModified) // only if modified
            .alert("Success", isPresented: $showSuccessMessage, actions: {
                Button("OK", role: .cancel) {}
            }, message: {
                Text("Your changes have been saved successfully!")
            })

            Spacer()
        }
        .padding()
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
    }

    // Check for any changes
    private func checkForChanges() {
        let user = FireAuthHelper.getInstance().user
        isModified = (
            name != user?.name ||
            email != user?.email ||
            address != user?.address ||
            phoneNumber != user?.phoneNumber ||
            creditCard != (user?.creditCard ?? "") ||
            (!password.isEmpty && password == confirmPassword)
        )
    }

    private func saveChanges() {
        guard let user = fireAuthHelper.user else {
            print("No user found in fireAuthHelper!")
            return
        }
        
        if !password.isEmpty && password != confirmPassword {
            print("Passwords do not match!")
            return
        }

        let updatedUser = UserModel(
            id: user.id, 
            name: name,
            email: email,
            address: address,
            phoneNumber: phoneNumber,
            typeOfUser: userType,
            creditCard: creditCard.isEmpty ? nil : creditCard
        )

        print("Updating user: \(updatedUser)")
        fireAuthHelper.updateUser(updatedUser, newPassword: password.isEmpty ? nil : password)
        isModified = false
        showSuccessMessage = true
    }
}
