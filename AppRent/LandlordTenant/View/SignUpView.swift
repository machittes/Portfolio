import SwiftUI

struct SignUpView: View {
    
    @EnvironmentObject var fireAuthHelper: FireAuthHelper
    
    @Binding var rootScreen: RootView
    
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var address: String = ""
    @State private var phoneNumber: String = ""
    @State private var typeOfUser: String = "Tenant"
    @State private var creditCard: String = ""

    private let userTypes = ["Landlord", "Tenant"]

    var body: some View {
        VStack(spacing: 20) {
            
            // Back Button
            HStack {
                Button(action: {
                    rootScreen = .Login
                }) {
                    Image(systemName: "arrow.left")
                        .font(.title)
                        .foregroundColor(.blue)
                        .padding()
                }
                Spacer()
            }
            
            Text("Create an Account")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, -30)
            
            Form {
                TextField("Full Name", text: $name)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)

                TextField("Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Confirm Password", text: $confirmPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Address", text: $address)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                TextField("Phone Number", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)

                Picker("User Type", selection: $typeOfUser) {
                    ForEach(userTypes, id: \.self) { type in
                        Text(type)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())

                TextField("Credit Card (Optional)", text: $creditCard)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

            } // Form End
            .padding(.horizontal, 20)

            // Sign Up Button
            Button(action: signUp) {
                Text("Create Account")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            .disabled(password != confirmPassword || email.isEmpty || password.isEmpty || confirmPassword.isEmpty)
            .alert("SignUp Success", isPresented: $fireAuthHelper.isSuccess) {
                Button("Ok") {
                    fireAuthHelper.isSuccess = false
                    rootScreen = (typeOfUser == "Landlord") ? .PropertyListLandlord : .PropertyListTenant
                   // rootScreen = .PropertyListTenant
                }
            }

            Spacer()
        }
        .padding()
        .navigationTitle("Registration")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func signUp() {
        let user = UserModel(name: name, email: email, address: address, phoneNumber: phoneNumber, typeOfUser: typeOfUser, creditCard: creditCard.isEmpty ? nil : creditCard)
        fireAuthHelper.signUp(email: email, password: password, user: user)
    }
}

