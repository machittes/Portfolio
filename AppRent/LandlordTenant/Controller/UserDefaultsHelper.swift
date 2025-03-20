import Foundation

class UserDefaultsHelper {
    
    private static let rememberMeKey = "rememberMe"
    private static let savedEmailKey = "savedEmail"
    private static let savedPasswordKey = "savedPassword"
    
    static func saveRememberMeState(_ isOn: Bool, email: String?, password: String?) {
        UserDefaults.standard.set(isOn, forKey: rememberMeKey)
        if isOn {
            UserDefaults.standard.set(email, forKey: savedEmailKey)
            UserDefaults.standard.set(password, forKey: savedPasswordKey)
        } else {
            UserDefaults.standard.removeObject(forKey: savedEmailKey)
            UserDefaults.standard.removeObject(forKey: savedPasswordKey)
        }
    }
    
    static func getRememberMeState() -> (Bool, String?, String?) {
        let isRemembered = UserDefaults.standard.bool(forKey: rememberMeKey)
        let savedEmail = UserDefaults.standard.string(forKey: savedEmailKey)
        let savedPassword = UserDefaults.standard.string(forKey: savedPasswordKey)
        return (isRemembered, savedEmail, savedPassword)
    }
}
