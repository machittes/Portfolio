// StudentExpenseTracker/Core/Data/Sync/Services/NetworkMonitor.swift
import Network
import Foundation

/**
 * NetworkMonitor provides real-time network connectivity monitoring for sync operations.
 *
 * This service uses iOS 14+ Network framework to efficiently track network state changes
 * and provides connection type information to optimize sync strategies.
 *
 * Usage:
 * ```swift
 * let monitor = NetworkMonitor.shared
 * if monitor.isConnected && monitor.connectionType == .wifi {
 *     // Perform large sync operations
 * }
 * ```
 */
@Observable
class NetworkMonitor {
    /// Shared singleton instance for app-wide network monitoring
    static let shared = NetworkMonitor()
    
    // MARK: - Private Properties
    
    /// NWPathMonitor instance for network path monitoring
    private let monitor = NWPathMonitor()
    
    /// Dedicated queue for network monitoring operations to avoid main thread blocking
    private let queue = DispatchQueue(label: "NetworkMonitor", qos: .utility)
    
    // MARK: - Public Observable Properties
    
    /// Current network connectivity status
    /// Updates automatically when network state changes
    var isConnected = false
    
    /// Type of active network connection
    /// Used to optimize sync behavior (e.g., large uploads only on WiFi)
    var connectionType: ConnectionType = .unknown
    
    // MARK: - Connection Types
    
    /// Enumeration of supported connection types for sync optimization
    enum ConnectionType {
        case wifi        // High bandwidth, typically unmetered
        case cellular    // Limited bandwidth, potentially metered
        case ethernet    // High bandwidth, typically unmetered (iPad Pro, Mac)
        case unknown     // Fallback for unsupported connection types
        
        /// Whether this connection type is suitable for large data transfers
        var isHighBandwidth: Bool {
            switch self {
            case .wifi, .ethernet: return true
            case .cellular, .unknown: return false
            }
        }
        
        /// Whether this connection is typically metered/has data limits
        var isMetered: Bool {
            switch self {
            case .cellular: return true
            case .wifi, .ethernet, .unknown: return false
            }
        }
    }
    
    // MARK: - Initialization
    
    /// Private initializer to enforce singleton pattern
    /// Automatically starts network monitoring upon creation
    private init() {
        startMonitoring()
    }
    
    // MARK: - Private Methods
    
    /**
     * Begins monitoring network path changes
     *
     * Sets up the NWPathMonitor to receive updates when network conditions change.
     * Updates are processed on a background queue and UI updates are dispatched to main actor.
     */
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            // Process network updates on main actor to ensure Observable updates work correctly
            Task { @MainActor in
                self?.handlePathUpdate(path)
            }
        }
        
        // Start monitoring on background queue to avoid blocking main thread
        monitor.start(queue: queue)
    }
    
    /**
     * Handles network path updates from NWPathMonitor
     *
     * - Parameter path: The current network path containing connectivity and interface information
     *
     * This method updates the observable properties that sync services can react to.
     * Changes trigger SwiftUI view updates and sync strategy adjustments.
     */
    @MainActor
    private func handlePathUpdate(_ path: NWPath) {
        // Update connectivity status
        let wasConnected = isConnected
        isConnected = path.status == .satisfied
        
        // Update connection type for sync optimization
        updateConnectionType(path)
        
        // Log connectivity changes for debugging
        if wasConnected != isConnected {
            Logger.log("Network connectivity changed: \(isConnected ? "connected" : "disconnected") via \(connectionType)", level: .info)
        }
    }
    
    /**
     * Determines the connection type based on available network interfaces
     *
     * - Parameter path: The network path to analyze
     *
     * Priority order: WiFi > Ethernet > Cellular > Unknown
     * This helps optimize sync behavior based on connection characteristics.
     */
    private func updateConnectionType(_ path: NWPath) {
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else {
            connectionType = .unknown
        }
    }
    
    // MARK: - Public Methods
    
    /**
     * Manually checks if network is available for sync operations
     *
     * - Returns: True if network is connected and suitable for sync
     *
     * This method can be used for one-time checks before initiating sync operations.
     */
    func isNetworkAvailableForSync() -> Bool {
        return isConnected
    }
    
    /**
     * Determines if current connection supports large data transfers
     *
     * - Returns: True for WiFi/Ethernet, false for cellular/unknown
     *
     * Use this to decide whether to sync large files or defer until better connection.
     */
    func supportsLargeTransfers() -> Bool {
        return isConnected && connectionType.isHighBandwidth
    }
    
    // MARK: - Cleanup
    
    /// Stops network monitoring when instance is deallocated
    /// Ensures proper cleanup of system resources
    deinit {
        monitor.cancel()
        Logger.log("NetworkMonitor deallocated", level: .debug)
    }
}

// MARK: - Extensions

extension NetworkMonitor.ConnectionType: CustomStringConvertible {
    var description: String {
        switch self {
        case .wifi: return "WiFi"
        case .cellular: return "Cellular"
        case .ethernet: return "Ethernet"
        case .unknown: return "Unknown"
        }
    }
}
