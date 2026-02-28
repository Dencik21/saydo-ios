//
//  LocationService.swift
//  SayDo
//
//  Created by Denys Ilchenko on 27.02.26.
//

import Foundation
import CoreLocation
import MapKit

actor LocationService {
    static let shared = LocationService()

    // cache: "address" -> coordinate
    private var cache: [String: CLLocationCoordinate2D] = [:]

    // fallback (iOS 25 and below)
    private let clGeocoder = CLGeocoder()

    func geocode(_ address: String) async -> CLLocationCoordinate2D? {
        let key = address
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        guard !key.isEmpty else { return nil }
        if let cached = cache[key] { return cached }

        // iOS 26+: MapKit forward geocoding
        if #available(iOS 26.0, *) {
            do {
                let request = MKGeocodingRequest(addressString: address)
                let mapItem = try await request?.mapItems.first
                let coord = mapItem?.placemark.coordinate

                if let coord {
                    cache[key] = coord
                }
                return coord
            } catch {
                return nil
            }
        }

        // iOS <= 25: CoreLocation geocoding (deprecated only on newer SDKs)
        do {
            let placemarks = try await clGeocoder.geocodeAddressString(address)
            let coord = placemarks.first?.location?.coordinate
            if let coord {
                cache[key] = coord
            }
            return coord
        } catch {
            return nil
        }
    }
}
