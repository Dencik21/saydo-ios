//
//  TaskRowViewModel.swift
//  SayDo
//
//  Created by Denys Ilchenko on 28.02.26.
//

import Foundation
import CoreLocation
import Combine
import SwiftUI

@MainActor
final class TaskRowViewModel: ObservableObject {

    @Published var isMapExpanded: Bool = false
    @Published var resolvedCoord: CLLocationCoordinate2D? = nil
    @Published var isResolving: Bool = false
    @Published var resolveError: Bool = false

    private let geocoder: GeocodingService

    init(geocoder: GeocodingService = .shared) {
        self.geocoder = geocoder
    }

    func setInitialCoordinateIfNeeded(_ coord: CLLocationCoordinate2D?) {
        guard resolvedCoord == nil else { return }
        resolvedCoord = coord
    }

    func toggleMap(hasAddress: Bool, effectiveCoordinate: CLLocationCoordinate2D?, address: String, onResolved: @escaping (CLLocationCoordinate2D) -> Void) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
            isMapExpanded.toggle()
        }

        if isMapExpanded, effectiveCoordinate == nil, hasAddress {
            Task { await resolveCoordinateIfNeeded(address: address, effectiveCoordinate: effectiveCoordinate, onResolved: onResolved) }
        }
    }

    func resolveCoordinateIfNeeded(
        address: String,
        effectiveCoordinate: CLLocationCoordinate2D?,
        force: Bool = false,
        onResolved: @escaping (CLLocationCoordinate2D) -> Void
    ) async {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if effectiveCoordinate != nil, force == false { return }
        if isResolving { return }

        isResolving = true
        resolveError = false
        defer { isResolving = false }

        do {
            let coord = try await geocoder.coordinate(for: trimmed)
            resolvedCoord = coord
            onResolved(coord)
        } catch {
            resolveError = true
        }
    }

    func openInMapsSmart(
        title: String,
        address: String,
        effectiveCoordinate: CLLocationCoordinate2D?,
        onResolved: @escaping (CLLocationCoordinate2D) -> Void
    ) async {
        if let coord = effectiveCoordinate {
            MapsOpener.openByCoordinate(coord, name: title)
            return
        }

        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        await resolveCoordinateIfNeeded(address: trimmed, effectiveCoordinate: effectiveCoordinate, onResolved: onResolved)

        if let coord = effectiveCoordinate ?? resolvedCoord {
            MapsOpener.openByCoordinate(coord, name: title)
        } else {
            MapsOpener.openByQuery(trimmed)
        }
    }
}
