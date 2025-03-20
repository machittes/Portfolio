//
//  RequestView.swift
//  LandlordTenant
//
//  Created by Juan Wang on 2025/3/13.
//

import SwiftUI

struct RequestView: View {
    @EnvironmentObject var fireAuthHelper: FireAuthHelper
    @State private var myProperties: [Property] = []

    var body: some View {
        NavigationView {
            List {
                // Get current user's requested property IDs
                let userRequestedPropertyIDs = fireAuthHelper.user?.propertyIDs ?? []
                
                // Filter the propertyRequestMap to include only properties requested by the current user
                let filteredPropertyRequestMap = fireAuthHelper.propertyRequestMap.filter { (propertyId, _) in
                    userRequestedPropertyIDs.contains(propertyId)
                }
                
                // Loop through the filtered propertyRequestMap
                let propertyKeys = filteredPropertyRequestMap.keys.sorted()
                ForEach(propertyKeys, id: \.self) { propertyId in
                    Section(header: Text("Property: \(fireAuthHelper.propertyAddresses[propertyId] ?? "Unknown Address")").font(.headline)) {
                        let userIds = filteredPropertyRequestMap[propertyId] ?? []
                        ForEach(userIds, id: \.self) { userId in
                            let userName = fireAuthHelper.userNames[userId] ?? "Unknown"
                            
                            HStack {
                                Text("User: \(userName)")
                                    .padding(.leading, 10)
                                
                                Spacer()
                                
                                // Accept Button
                                Button(action: {
                                    // Add Accept action here (not implemented)
                                }) {
                                    Text("Accept")
                                        .foregroundColor(.green)
                                        .padding(6)
                                        .background(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.green))
                                }
                                
                                // Decline Button
                                Button(action: {
                                    // Add Decline action here (not implemented)
                                }) {
                                    Text("Decline")
                                        .foregroundColor(.red)
                                        .padding(6)
                                        .background(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.red))
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Property Requests")
            .onAppear {
                // Fetch property requests (user to propertyId mapping) and property addresses
                fireAuthHelper.fetchPropertyRequestMap()
                fireAuthHelper.fetchPropertyAddresses()
            }
        }
    }
}


