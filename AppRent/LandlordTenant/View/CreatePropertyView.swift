import SwiftUI

struct CreatePropertyView: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var fireAuthHelper: FireAuthHelper
    @EnvironmentObject var fireDBHelper: FireDBHelper

    @State private var desc: String = ""
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var monthlyRentalPrice: Decimal = 0.0
    @State private var availabilityDate: Date = Date()
    @State private var numberOfBedrooms: Int = 0
    @State private var numberOfBathrooms: Int = 0
    @State private var isAvailable: Bool = false
    @State private var propertyType: PropertyType = .apartment
    @State private var buildingAmenities: Set<BuildingAmenity> = []
    @State private var unitFeatures: Set<UnitFeature> = []

    @State private var lat: Double = 0.0
    @State private var lng: Double = 0.0
    @State private var imageUrl: String = "https://plus.unsplash.com/premium_photo-1669704844087-33fcf284709b?q=80&w=1976&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
    @State private var sqft: Int = 0
    @State private var landlord: String = ""
    @State private var listingDate: Date = Date()
    @State private var contactPhone: String = ""
    @State private var contactEmail: String = ""

    @State private var sqftString: String = ""
    
    @State private var isLandlord = false
    @State private var landlordId = ""

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("General Information")) {
                    FloatingLabelTextField(placeholder: "Description", text: $desc)
                    FloatingLabelTextField(placeholder: "Address", text: $address)
                    FloatingLabelTextField(placeholder: "City", text: $city)
                    Picker("Property Type", selection: $propertyType) {
                        ForEach(PropertyType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                }

                Section(header: Text("Price and Availability")) {
                    TextField("Rent Amount", value: $monthlyRentalPrice, format: .currency(code: Locale.current.currency?.identifier ?? "CAN"))
                    Toggle("Available", isOn: $isAvailable)
                    DatePicker("Select Availability Date", selection: $availabilityDate, displayedComponents: .date)
                }

                Section(header: Text("Size")) {
                    Stepper("Number of Bedrooms: \(numberOfBedrooms)", value: $numberOfBedrooms, in: 0...10)
                    Stepper("Number of Bathrooms: \(numberOfBathrooms)", value: $numberOfBathrooms, in: 0...10)
                    FloatingLabelTextField(placeholder: "SqFt", text: $sqftString)
                        .keyboardType(.numberPad)
                        .onChange(of: sqftString) { newValue in
                            if let intValue = Int(newValue) {
                                sqft = intValue
                            } else {
                                sqft = 0
                            }
                        }
                }


                Section(header: Text("Listing Details")) {
//                    DatePicker("Listing Date", selection: $listingDate, displayedComponents: .date)
                    FloatingLabelTextField(placeholder: "Image URL", text: $imageUrl)
                }

                Collapsible(label: { Text("Building Amenities").font(.headline).fontWeight(.bold) }, content: { MultiSelectionView(options: BuildingAmenity.allCases, selected: $buildingAmenities) })

                Collapsible(label: { Text("Unit Features").font(.headline).fontWeight(.bold) }, content: { MultiSelectionView(options: UnitFeature.allCases, selected: $unitFeatures) })
            }
            .navigationTitle("New Property")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        let newProperty = Property(desc: desc, address: address, city: city, lat: lat, lng: lng, propertyType: propertyType, imageUrl: URL(string: imageUrl)!, numberOfBedrooms: numberOfBedrooms, numberOfBathrooms: numberOfBathrooms, buildingAmenities: Array(buildingAmenities), unitFeatures: Array(unitFeatures), sqft: sqft, monthlyRentalPrice: monthlyRentalPrice, isAvailable: isAvailable, landlord: landlordId, listingDate: listingDate, availabilityDate: availabilityDate)

                        fireDBHelper.insertListing(newProperty: newProperty)

                        // Dismiss the view
                        dismiss()
                    }
                }
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

struct FloatingLabelTextField: View {
    let placeholder: String
    @Binding var text: String
    @State private var isEditing: Bool = false

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.horizontal, 4)
                    .offset(y: isEditing ? -20 : 0)
                    .scaleEffect(isEditing ? 0.8 : 1, anchor: .leading)
            }

            TextField("", text: $text, onEditingChanged: { editing in
                withAnimation {
                    isEditing = editing
                }
            })
            .padding(.top, isEditing ? 15 : 0)
        }
        .padding(.horizontal)
    }
}
