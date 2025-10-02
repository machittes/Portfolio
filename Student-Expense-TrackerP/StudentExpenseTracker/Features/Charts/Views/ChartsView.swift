//
//  ChartsView.swift
//  StudentExpenseTracker
//
//  Created by Hasan Rahmeh on 2025-05-28.
//

import SwiftUI

struct ChartsView: View {
    var body: some View {
        VStack {
            Text("Charts")
                .font(AppFonts.title)
                .foregroundColor(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.backgroundDefault.ignoresSafeArea())
        .navigationTitle("Charts") 
        .navigationBarTitleDisplayMode(.inline)
    }
}
