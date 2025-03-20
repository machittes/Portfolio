//
//  PropertyDetailsView.swift
//  LandlordTenandt
//
//  Created by Henrique Machitte on 02/03/25.
//

import SwiftUI

struct PropertyDetailsView: View {
    @EnvironmentObject var fireAuthHelper: FireAuthHelper
    @EnvironmentObject var fireDBHelper: FireDBHelper
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var selectedPropertyWrapper: SelectedPropertyWrapper

    @State var property: Property?
    var isNew: Bool

    @State private var desc: String = ""
    @State private var address: String = ""
    @State private var city: String = ""
    @State private var monthlyRentalPrice: Decimal = 0.0
    @State private var availabilityDate: Date
    @State private var numberOfBedrooms: Int = 0
    @State private var numberOfBathrooms: Int = 0
    @State private var isAvailable: Bool = false
    @State private var propertyType: PropertyType = .apartment // Default value
    @State private var buildingAmenities: Set<BuildingAmenity> = []
    @State private var unitFeatures: Set<UnitFeature> = []

    @State private var isLandlord = false
    @State private var landlordId = ""
    
    init(property: Property?, isNew: Bool) {
        self.property = property
        self.isNew = isNew
        _desc = State(initialValue: property?.desc ?? "")
        _address = State(initialValue: property?.address ?? "")
        _city = State(initialValue: property?.city ?? "")
        _monthlyRentalPrice = State(initialValue: property?.monthlyRentalPrice ?? 0.0)
        _availabilityDate = State(initialValue: property?.availabilityDate ?? Date())
        _numberOfBedrooms = State(initialValue: property?.numberOfBedrooms ?? 0)
        _numberOfBathrooms = State(initialValue: property?.numberOfBathrooms ?? 0)
        _isAvailable = State(initialValue: property?.isAvailable ?? false)
        _propertyType = State(initialValue: property?.propertyType ?? .apartment)
        _buildingAmenities = State(initialValue: Set(property?.buildingAmenities ?? []))
        _unitFeatures = State(initialValue: Set(property?.unitFeatures ?? []))
    }

    var body: some View {
        VStack {
            if property != nil {
                Form {
                    TextField("Description", text: $desc)
                        .disabled(!isLandlord)

                    TextField("Address", text: $address)
                        .disabled(!isLandlord)

                    TextField("City", text: $city)
                        .disabled(!isLandlord)

                    TextField("Rent Amount", value: $monthlyRentalPrice, format: .currency(code: Locale.current.currency?.identifier ?? "CAN"))
                        .disabled(!isLandlord)

                    Stepper("Number of Bedrooms: \(numberOfBedrooms)", value: $numberOfBedrooms, in: 0...10)
                        .disabled(!isLandlord)

                    Stepper("Number of Bathrooms: \(numberOfBathrooms)", value: $numberOfBathrooms, in: 0...10)
                        .disabled(!isLandlord)

                    DatePicker("Select Availability Date", selection: $availabilityDate, displayedComponents: .date)
                        .disabled(!isLandlord)

                    Toggle("Available", isOn: $isAvailable)
                        .disabled(!isLandlord)

                    Picker("Property Type", selection: $propertyType) {
                        ForEach(PropertyType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .disabled(!isLandlord)

                    Collapsible(label: {
                        Text("Building Amenities")
                            .font(.headline)
                            .fontWeight(.bold)
                    }, content: {
                        MultiSelectionView(options: BuildingAmenity.allCases, selected: $buildingAmenities)
                            .disabled(!isLandlord) // Disable MultiSelectionView
                    })

                    Collapsible(label: {
                        Text("Unit Features")
                            .font(.headline)
                            .fontWeight(.bold)
                    }, content: {
                        MultiSelectionView(options: UnitFeature.allCases, selected: $unitFeatures)
                            .disabled(!isLandlord) // Disable MultiSelectionView
                    })
                }
                //.disabled(!isLandlord) // Disable the entire form if not landlord EXCEPT Collapsibles

                Button(action: {
                    updateProperty()
                }) {
                    Text("Update Property")
                }
                .disabled(!isLandlord) // Disable the button if not landlord

            } else {
                Text("Loading property data...")
            }
            Spacer()
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
        
        
        
        .navigationTitle(Text("Detail View"))
        .onChange(of: fireDBHelper.isUpdateComplete) { _ in
            if fireDBHelper.isUpdateComplete {
                dismiss()
            }
        }
    }

    private func updateProperty() {
        if monthlyRentalPrice == 0.0 {
            print("Please provide all the fields")
        } else {
            if var propertyToUpdate = property {
                propertyToUpdate.desc = desc
                propertyToUpdate.address = address
                propertyToUpdate.city = city
                propertyToUpdate.monthlyRentalPrice = monthlyRentalPrice
                propertyToUpdate.availabilityDate = availabilityDate
                propertyToUpdate.numberOfBedrooms = numberOfBedrooms
                propertyToUpdate.numberOfBathrooms = numberOfBathrooms
                propertyToUpdate.isAvailable = isAvailable
                propertyToUpdate.propertyType = propertyType
                propertyToUpdate.buildingAmenities = Array(buildingAmenities)
                propertyToUpdate.unitFeatures = Array(unitFeatures)

                print("Before Update: Desc: \(propertyToUpdate.desc), Address: \(propertyToUpdate.address), City: \(propertyToUpdate.city), Price: \(propertyToUpdate.monthlyRentalPrice), Bedrooms: \(propertyToUpdate.numberOfBedrooms), Bathrooms: \(propertyToUpdate.numberOfBathrooms), isAvailable: \(propertyToUpdate.isAvailable), propertyType: \(propertyToUpdate.propertyType), buildingAmenities: \(propertyToUpdate.buildingAmenities), unitFeatures: \(propertyToUpdate.unitFeatures)")

                fireDBHelper.updateProperty(propertyToUpdate: propertyToUpdate)

                print("After Update Call (Check dismiss): Desc: \(propertyToUpdate.desc), Address: \(propertyToUpdate.address), City: \(propertyToUpdate.city), Price: \(propertyToUpdate.monthlyRentalPrice), Bedrooms: \(propertyToUpdate.numberOfBedrooms), Bathrooms: \(propertyToUpdate.numberOfBathrooms), isAvailable: \(propertyToUpdate.isAvailable), propertyType: \(propertyToUpdate.propertyType), buildingAmenities: \(propertyToUpdate.buildingAmenities), unitFeatures: \(propertyToUpdate.unitFeatures)")

            } else {
                print("Property is nil, cannot update.")
            }
        }
    }
}
