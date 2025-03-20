enum PropertyType: String, Codable, CaseIterable {
    case apartment = "Apartment Unit"
    case condo = "Condominium"
}

enum BuildingAmenity: String, Codable, CaseIterable, Identifiable, CustomStringConvertible {
    var id: String { rawValue }
    case fitnessCentre = "Fitness Centre"
    case elevator = "Elevator"
    case parking = "Parking"
    case saunaSpa = "Sauna/Spa"
    case swimmingPool = "Swimming Pool"
    case laundry = "Laundry"

    var description: String {
        return self.rawValue // Use the rawValue for description
    }
}

enum UnitFeature: String, Codable, CaseIterable, Identifiable, CustomStringConvertible {
    var id: String { rawValue }
    case parquet = "Parquet"
    case rangeHood = "Range Hood"
    case stoveOven = "Stove/Oven"
    case refrigerator = "Refrigerator"
    case gasRangeStove = "Gas Range/Stove"
    case plentyOfClosetSpace = "Plenty of Closet Space"
    case newlyRenovated = "Newly Renovated"
    case balcony = "Balcony"
    case brightAndSpaciousSuites = "Bright and Spacious Suites"
    case dishwasher = "Dishwasher"
    case ceramicBacksplash = "Ceramic Backsplash"
    case freshlyPainted = "Freshly Painted"
    case patio = "Patio"
    case fantasticViews = "Fantastic Views"
    case fullKitchen = "Full Kitchen"
    case hardwood = "Hardwood"
    case airConditioning = "Air Conditioning"
    case laminate = "Laminate"
    case microwave = "Microwave"
    case ceramicTile = "Ceramic Tile"
    case stoneCountertop = "Stone Countertop"

    var description: String {
        return self.rawValue // Use the rawValue for description
    }
}


import Foundation
import FirebaseFirestore


struct Property: Codable, Hashable, Identifiable {
    @DocumentID var id: String?
    var desc: String
    var address: String
    var city: String
    var lat: Double
    var lng: Double
    var propertyType: PropertyType
    var imageUrl: URL
    var numberOfBedrooms: Int
    var numberOfBathrooms: Int
    var buildingAmenities: [BuildingAmenity] = []
    var unitFeatures: [UnitFeature] = []
    var sqft: Int
    var monthlyRentalPrice: Decimal
    var isAvailable: Bool
    var landlord: String
    var listingDate: Date
    var availabilityDate: Date
   
    
    init(desc: String,
         address: String,
         city: String,
         lat: Double,
         lng: Double,
         propertyType: PropertyType,
         imageUrl: URL,
         numberOfBedrooms: Int,
         numberOfBathrooms: Int,
         buildingAmenities: [BuildingAmenity] = [],
         unitFeatures: [UnitFeature] = [],
         sqft: Int,
         monthlyRentalPrice: Decimal,
         isAvailable: Bool,
         landlord: String,
         listingDate: Date,
         availabilityDate: Date) {
        
        self.desc = desc
        self.address = address
        self.city = city
        self.lat = lat
        self.lng = lng
        self.propertyType = propertyType
        self.imageUrl = imageUrl
        self.numberOfBedrooms = numberOfBedrooms
        self.numberOfBathrooms = numberOfBathrooms
        self.buildingAmenities = buildingAmenities
        self.unitFeatures = unitFeatures
        self.sqft = sqft
        self.monthlyRentalPrice = monthlyRentalPrice
        self.isAvailable = isAvailable
        self.landlord = landlord
        self.listingDate = listingDate
        self.availabilityDate = availabilityDate
    }
}
