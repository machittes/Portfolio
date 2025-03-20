import SwiftUI

struct SignInView: View {
    
    @EnvironmentObject var fireAuthHelper: FireAuthHelper
    
    @Binding var rootScreen: RootView
    
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var rememberMe: Bool = false
    
    init(rootScreen: Binding<RootView>) {
        self._rootScreen = rootScreen
        let (isRemembered, savedEmail, savedPassword) = UserDefaultsHelper.getRememberMeState()
        _rememberMe = State(initialValue: isRemembered)
        _email = State(initialValue: savedEmail ?? "")
        _password = State(initialValue: savedPassword ?? "")
    }
    
    var body: some View {
        VStack(spacing: 20) {
            
            Text("Welcome to Rent.ca")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding(.top, 50)
            
            Form {
                TextField("Enter Email", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .autocapitalization(.none)
                
                SecureField("Enter Password", text: $password)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Toggle("Remember Me", isOn: $rememberMe)
            }
            .padding(.horizontal, 20)

            
            Button(action: {
                fireAuthHelper.signIn(email: email, password: password) { success in
                    if success {
                        fireAuthHelper.fetchUserType(email: email) { userType in
                            if let userType = userType {
                                rootScreen = (userType == "Landlord") ? .PropertyListLandlord : .PropertyListTenant
                            }
                        }
                        UserDefaultsHelper.saveRememberMeState(rememberMe, email: email, password: password)
                    }
                }
            }) {
                Text("Sign In")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }

            
            // Sign Up Section
            Text("Are you not registered?")
                .foregroundColor(.gray)
            
            Button(action: {
                rootScreen = .SignUp
            }) {
                Text("Sign Up")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)
            
            // Guest User Section
            Text("Just browsing?")
                .foregroundColor(.gray)
            
            Button(action: {
                rootScreen = .PropertyListGuest
            }) {
                Text("Guest User")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundColor(.white)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, 20)

            Spacer()
        }
        .padding()
        .navigationTitle("Login")
        .navigationBarTitleDisplayMode(.inline)
    }
}

