import SwiftUI
import Firebase
import FirebaseFirestore

struct MyPropertyView: View {
    @EnvironmentObject var fireAuthHelper: FireAuthHelper
    @State private var favoriteProperties: [Property] = []
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil
    
    var body: some View {
        NavigationStack {
            VStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding()
                } else if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .font(.title2)
                        .foregroundColor(.red)
                } else if favoriteProperties.isEmpty {
                    Text("No favorites yet!")
                        .font(.title2)
                        .foregroundColor(.gray)
                } else {
                    List(favoriteProperties) { property in
                        PropertyRowLandlord(property: property)
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Favorites")
            .onAppear {
                fetchFavoriteProperties()
            }
        }
    }
    

    private func fetchFavoriteProperties() {
        guard let user = fireAuthHelper.user else {
            errorMessage = "No user logged in"
            isLoading = false
            return
        }

        let propertyIDs = user.propertyIDs ?? []
        guard !propertyIDs.isEmpty else {
            errorMessage = "Property list is empty, skipping query."
            favoriteProperties = []
            isLoading = false
            return
        }

        let db = Firestore.firestore()
        
        var fetchedProperties: [Property] = []
        let dispatchGroup = DispatchGroup()  // Used to wait for all the async calls to complete

        // Fetch each property document by its document ID
        for propertyID in propertyIDs {
            dispatchGroup.enter()  // Enter the dispatch group before starting an async task
            db.collection("Properties").document(propertyID).getDocument { document, error in
                if let error = error {
                    errorMessage = "Error fetching property with ID \(propertyID): \(error.localizedDescription)"
                } else if let document = document, document.exists {
                    if let property = try? document.data(as: Property.self) {
                        fetchedProperties.append(property)
                    } else {
                        errorMessage = "Failed to convert document to Property for ID \(propertyID)"
                    }
                } else {
                    errorMessage = "No document found for property with ID \(propertyID)"
                }
                dispatchGroup.leave()  // Leave the dispatch group after the task is completed
            }
        }

        // Wait for all fetch requests to complete
        dispatchGroup.notify(queue: .main) {
            if fetchedProperties.isEmpty {
                errorMessage = "No properties found."
            }
            self.favoriteProperties = fetchedProperties
            self.isLoading = false
        }
    }
}
