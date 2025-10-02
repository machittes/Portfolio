// SyncError.swift
import Foundation

enum SyncError: LocalizedError {
    case firebaseNotConfigured
    case userNotAuthenticated
    case networkUnavailable
    case firestoreError(Error)
    case dataCorruption(String)
    case conflictResolution(String)
    case quotaExceeded
    case permissionDenied
    
    var errorDescription: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Firebase is not properly configured"
        case .userNotAuthenticated:
            return "User authentication required"
        case .networkUnavailable:
            return "Network connection unavailable"
        case .firestoreError(let error):
            return "Firestore error: \(error.localizedDescription)"
        case .dataCorruption(let details):
            return "Data corruption detected: \(details)"
        case .conflictResolution(let details):
            return "Sync conflict: \(details)"
        case .quotaExceeded:
            return "Sync quota exceeded"
        case .permissionDenied:
            return "Permission denied"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .firebaseNotConfigured:
            return "Please restart the app or contact support"
        case .userNotAuthenticated:
            return "Please sign in again"
        case .networkUnavailable:
            return "Check your internet connection"
        case .firestoreError:
            return "Try again later"
        case .dataCorruption:
            return "Data will be restored from cloud backup"
        case .conflictResolution:
            return "Conflicts will be resolved automatically"
        case .quotaExceeded:
            return "Sync will resume within 24 hours"
        case .permissionDenied:
            return "Check your account permissions"
        }
    }
}
