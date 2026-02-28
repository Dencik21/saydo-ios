//
//  MapsOpener.swift
//  SayDo
//
//  Created by Denys Ilchenko on 28.02.26.
//

import CoreLocation
import UIKit

enum MapsOpener {

    /// Открыть маршрут (driving) к координатам
    static func openByCoordinate(_ coord: CLLocationCoordinate2D, name: String) {
        let lat = coord.latitude
        let lon = coord.longitude

        let encodedName = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name

        // daddr = destination, dirflg=d (driving)
        let urlString = "http://maps.apple.com/?daddr=\(lat),\(lon)&dirflg=d&q=\(encodedName)"
        guard let url = URL(string: urlString) else { return }

        UIApplication.shared.open(url)
    }

    /// Открыть Apple Maps по текстовому запросу
    static func openByQuery(_ query: String) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        guard let url = URL(string: "http://maps.apple.com/?q=\(encoded)") else { return }
        UIApplication.shared.open(url)
    }
}
