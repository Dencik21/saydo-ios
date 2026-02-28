//
//  GeocodingService.swift
//  SayDo
//
//  Created by Denys Ilchenko on 28.02.26.
//

import Foundation
import MapKit
import CoreLocation

actor GeocodingService {
    static let shared = GeocodingService()
    private init() {}

    func coordinate(for address: String) async throws -> CLLocationCoordinate2D {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = address

        let search = MKLocalSearch(request: request)
        let response = try await search.start()

        guard let item = response.mapItems.first else {
            throw NSError(
                domain: "Geocoder",
                code: 0,
                userInfo: [NSLocalizedDescriptionKey: "No location found for address"]
            )
        }

        return item.placemark.coordinate
    }
}
