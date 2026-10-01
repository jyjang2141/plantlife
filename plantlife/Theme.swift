//
//  Theme.swift
//  plantlife
//
//


import SwiftUI

// Pulled out into its own file so it stays available to plantResult.swift
// regardless of which top-level UI is currently in use.
enum Theme {
    static let leaf  = Color(red: 0.15, green: 0.47, blue: 0.25)
    static let sun   = Color(red: 0.80, green: 0.55, blue: 0.05)
    static let water = Color(red: 0.15, green: 0.45, blue: 0.75)
    static let alert = Color(red: 0.78, green: 0.30, blue: 0.20)

    static let background = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.06, green: 0.10, blue: 0.08, alpha: 1)
            : UIColor(red: 0.93, green: 0.97, blue: 0.94, alpha: 1)
    })

    static let card = Color(UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.12, green: 0.17, blue: 0.14, alpha: 1)
            : UIColor.white
    })

    static let cardShape = RoundedRectangle(cornerRadius: 22, style: .continuous)
}
