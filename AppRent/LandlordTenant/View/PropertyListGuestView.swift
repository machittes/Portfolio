import SwiftUI

struct PropertyListGuestView: View {
    @EnvironmentObject var fireAuthHelper: FireAuthHelper
    @EnvironmentObject var fireDBHelper: FireDBHelper

    @State private var searchText = ""
    @State private var showDetailView = false
    @StateObject private var selectedPropertyWrapper = SelectedPropertyWrapper()
    @State private var showingCreatePropertyView = false
    @State private var filterByLandLord = false
    @State private var isLandlord = false
    
    @State private var landlordId = ""

    @Binding var rootScreen: RootView

    var filteredProperties: [Property] {
        if filterByLandLord {
            return fireDBHelper.propertyList.filter { property in
                property.landlord == landlordId
            }
        } else if searchText.isEmpty {
            return fireDBHelper.propertyList
        } else {
            return fireDBHelper.propertyList.filter { property in
                property.city.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        TabView {
            // PROPERTIES TAB
            NavigationStack {
                ZStack {
                    VStack {
                        // header with search bar
                        ZStack {
                            RoundedRectangle(cornerRadius: 0)
                                .fill(Color(uiColor: .systemTeal))
                                .frame(height: 50)
                                .frame(maxWidth: .infinity)

                            HStack {
                                Image(systemName: "sun.max")
                                    .padding(.leading, 5)
                                    .foregroundColor(Color.white)

                                Text("Rentals.ca")
                                    .padding(.trailing, 5)
                                    .foregroundColor(Color.white)

                                Spacer()

                                TextField("Search by City", text: $searchText)
                                    .padding(7)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .padding(.trailing, 5)
                                    .frame(maxWidth: .infinity)
                            }
                            .frame(height: 50)
                            .padding(.horizontal, 10)
                        }

                        // Property list
                        List {
                            ForEach(filteredProperties.enumerated().map({ $0 }), id: \.element.id) { _, currentProperty in
                                NavigationLink {
                                    PropertyDetailsView(property: currentProperty, isNew: false)
                                        .environmentObject(fireAuthHelper)
                                        .environmentObject(fireDBHelper)
                                        .environmentObject(selectedPropertyWrapper)
                                        .onAppear {
                                            print("Presenting DetailView for: \(currentProperty.id ?? "no id")")
                                        }
                                } label: {
                                    PropertyRowGuest(property: currentProperty)
                                        .buttonStyle(.plain)
                                }
                            }
                        }
                        .listStyle(.plain)
                        .onAppear {
                            fireDBHelper.propertyList = []
                            fireDBHelper.getAllListings()
                        }
                    }

                    // Floating Action Buttons (FABs)
                    VStack {
                        Spacer()
                        HStack {
                            if isLandlord {
                                Button(action: {
                                    filterByLandLord.toggle()
                                    searchText = ""
                                    print("Filter by Land Lord!")

                                }) {
                                    Image(systemName: "line.3.horizontal.decrease")
                                        .resizable()
                                        .frame(width: 24, height: 24)
                                        .padding()
                                        //.background(Color.gray)
                                        .background(filterByLandLord ? Color.orange : Color.gray)
                                        .foregroundColor(.white)
                                        .clipShape(Circle())
                                        .shadow(radius: 4)
                                }
                                .padding()
                            }

                            Spacer()
                        }
                    }
                }
                .navigationTitle("Properties")
                .sheet(isPresented: $showingCreatePropertyView) {
                    CreatePropertyView()
                        .environmentObject(fireDBHelper)
                }
            }
            .tabItem {
                Label("Properties", systemImage: "building.2.fill")
            }

            // LOGOUT TAB
            Button("Logout") {
                fireAuthHelper.signOut()
                rootScreen = .Login
            }
            .tabItem {
                Label("Logout", systemImage: "arrow.backward.circle.fill")
            }
        }
        .onAppear {
            if let user = fireAuthHelper.user {
                print("Current user: \(user.name), typeOfUser: \(user.typeOfUser)")

                if user.typeOfUser.lowercased() == "landlord" {
                    isLandlord = true
                    landlordId = user.id!
                } else {
                    isLandlord = false
                    landlordId = ""
                }
            } else {
                print("No user logged in")
                isLandlord = false // Ensure it's set to false if there's no user
            }
        }
    }
}

struct PropertyRowGuest: View {
    let property: Property
    @State private var isFavorite: Bool = false
    @State private var isRequest: Bool = false  // Track if the property is requested
    @EnvironmentObject var fireAuthHelper: FireAuthHelper

    var body: some View {
        HStack(alignment: .top) {
            AsyncImage(url: property.imageUrl) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                ProgressView()
            }
            .frame(width: 100, height: 100)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.trailing, 20)

            VStack(alignment: .leading) {
                Text(property.monthlyRentalPrice, format: .currency(code: Locale.current.currency?.identifier ?? "CAN"))
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)

                HStack {
                    Text("\(property.numberOfBedrooms) Beds")
                    Text("|")
                    Text("\(property.numberOfBathrooms) Baths")
                }
                .font(.callout)
                .foregroundColor(Color.gray)

                Text(property.address)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundColor(Color.green)

                Text(property.city)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .onAppear {
            if let user = fireAuthHelper.user {
                isFavorite = user.propertyIDs.contains(property.id ?? "")
                // Optionally initialize the request state based on the user data
                isRequest = user.requestpropertyIDs.contains(property.id ?? "")
            }
        }
    }
}

class SelectedPropertyWrapper: ObservableObject {
    @Published var selectedProperty: Property? = nil
}
