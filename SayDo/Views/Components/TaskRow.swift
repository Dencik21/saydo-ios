import SwiftUI
import SwiftData
import MapKit
import CoreLocation
import UIKit

struct TaskRow: View {
    @Environment(\.modelContext) private var context
    let task: TaskModel

    // ✅ внешний обработчик (из Upcoming)
    var onToggleDone: ((TaskModel) -> Void)? = nil

    // ✅ открыть редактор (UpcomingView задаёт selectedTask)
    var onOpen: ((TaskModel) -> Void)? = nil

    @State private var isMapExpanded: Bool = false

    // ✅ Геокодинг состояния
    @State private var resolvedCoord: CLLocationCoordinate2D? = nil
    @State private var isResolving: Bool = false
    @State private var resolveError: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

            // ✅ ВАЖНО: делим строку на 2 зоны
            // 1) левая зона (done + текст) — открывает редактор
            // 2) правая зона (кнопки) — НЕ открывает редактор
            HStack(alignment: .top, spacing: 12) {

                // LEFT TAP ZONE (opens editor)
                HStack(alignment: .top, spacing: 12) {
                    doneButton

                    VStack(alignment: .leading, spacing: 6) {
                        titleLine
                        metaLine
                        addressLine
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    onOpen?(task)
                }

                // RIGHT ZONE (buttons only)
                if hasAddressOrCoord {
                    HStack(spacing: 10) {
                        mapToggleButton
                        routeButton
                    }
                    .padding(.top, 2)
                }
            }

            // ✅ Mini map / resolving placeholder
            if isMapExpanded {
                if let coord = effectiveCoordinate {
                    miniMap(coord)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                } else if hasAddress {
                    resolvingView
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(cardBackground)
        .id(task.id.uuidString)
        .task {
            // ✅ если координаты уже есть в модели — используем их
            if let c = coordinateFromModel {
                resolvedCoord = c
            }
        }
    }

    // MARK: - Derived

    private var addressTrimmed: String {
        (task.address ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasAddress: Bool {
        !addressTrimmed.isEmpty
    }

    private var hasAddressOrCoord: Bool {
        coordinateFromModel != nil || hasAddress
    }

    private var coordinateFromModel: CLLocationCoordinate2D? {
        guard let lat = task.locationLat, let lon = task.locationLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    /// ✅ Координата, которую используем для карты/маршрута:
    /// 1) из модели (кеш)
    /// 2) из resolvedCoord (только что геокоднули)
    private var effectiveCoordinate: CLLocationCoordinate2D? {
        coordinateFromModel ?? resolvedCoord
    }

    // MARK: - UI Parts

    private var doneButton: some View {
        Button {
            if let onToggleDone {
                onToggleDone(task)              // ✅ удалит event из календаря при done (если ты так сделал)
            } else {
                task.isDone.toggle()
                try? context.save()
            }
        } label: {
            Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(task.isDone ? .green : .secondary)
        }
        .buttonStyle(.borderless)
        .padding(.top, 1)
    }

    private var titleLine: some View {
        Text(task.title)
            .font(.body)
            .lineLimit(2)
            .foregroundStyle(.primary)
    }

    private var metaLine: some View {
        HStack(spacing: 8) {
            if let due = task.dueDate {
                Label(russianDate(due), systemImage: "calendar")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if task.reminderEnabled && task.isDone == false {
                Image(systemName: "alarm")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var addressLine: some View {
        if hasAddress {
            HStack(spacing: 6) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(addressTrimmed)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.top, 2)
        }
    }

    private var mapToggleButton: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) {
                isMapExpanded.toggle()
            }

            // ✅ если раскрыли, а координат ещё нет — запускаем геокодинг
            if isMapExpanded, effectiveCoordinate == nil, hasAddress {
                Task { await resolveCoordinateIfNeeded() }
            }
        } label: {
            if isResolving {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: isMapExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
                    .font(.subheadline)
            }
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.blue)
        .disabled(!hasAddressOrCoord)
        .accessibilityLabel("Показать карту")
    }

    private var routeButton: some View {
        Button {
            Task { await openInMapsSmart() }
        } label: {
            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.subheadline)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(.blue)
        .disabled(!hasAddressOrCoord)
        .accessibilityLabel("Открыть маршрут")
    }

    private var resolvingView: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            Text(resolveError ? "Не получилось найти адрес" : "Ищу адрес на карте…")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if resolveError {
                Button("Повторить") {
                    Task { await resolveCoordinateIfNeeded(force: true) }
                }
                .font(.caption)
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.separator.opacity(0.2), lineWidth: 1)
        )
        .onAppear {
            if effectiveCoordinate == nil, hasAddress, isResolving == false {
                Task { await resolveCoordinateIfNeeded() }
            }
        }
    }

    private func miniMap(_ coord: CLLocationCoordinate2D) -> some View {
        let region = MKCoordinateRegion(
            center: coord,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )

        return Map(initialPosition: .region(region)) {
            Marker(task.title, coordinate: coord)
        }
        .frame(height: 140)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.separator.opacity(0.2), lineWidth: 1)
        )
        // ✅ тап по карте открывает Maps, но НЕ редактор (редактор только слева)
        .onTapGesture {
            Task { await openInMapsSmart() }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.background)
            .shadow(radius: 6, y: 2)
    }

    // MARK: - Geocoding

    @MainActor
    private func resolveCoordinateIfNeeded(force: Bool = false) async {
        guard hasAddress else { return }
        if effectiveCoordinate != nil, force == false { return }
        if isResolving { return }

        isResolving = true
        resolveError = false
        defer { isResolving = false }

        do {
            let coord = try await Geocoder.shared.coordinate(for: addressTrimmed)

            // ✅ кешируем координаты в модель (юзер этого не видит)
            task.locationLat = coord.latitude
            task.locationLon = coord.longitude
            try? context.save()

            resolvedCoord = coord
        } catch {
            resolveError = true
        }
    }

    // MARK: - Maps

    private func openInMapsByCoordinate(_ coord: CLLocationCoordinate2D) {
        let placemark = MKPlacemark(coordinate: coord)
        let item = MKMapItem(placemark: placemark)
        item.name = task.title
        item.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    private func openInMapsByQuery(_ query: String) {
        let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        if let url = URL(string: "http://maps.apple.com/?q=\(encoded)") {
            UIApplication.shared.open(url)
        }
    }

    /// ✅ умное открытие:
    /// 1) если есть координаты — открываем точно
    /// 2) если нет — пробуем геокоднуть
    /// 3) если геокодинг не удался — открываем по query
    private func openInMapsSmart() async {
        if let coord = effectiveCoordinate {
            openInMapsByCoordinate(coord)
            return
        }

        if hasAddress {
            await resolveCoordinateIfNeeded()

            if let coord = effectiveCoordinate {
                openInMapsByCoordinate(coord)
            } else {
                openInMapsByQuery(addressTrimmed)
            }
        }
    }

    // MARK: - Date

    private static let ruFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "ru_RU")
        df.calendar = Calendar(identifier: .gregorian)
        df.dateFormat = "d MMMM yyyy"
        return df
    }()

    private func russianDate(_ date: Date) -> String {
        Self.ruFormatter.string(from: date)
    }
}

// MARK: - Geocoder helper

private actor Geocoder {
    static let shared = Geocoder()
    private let geocoder = CLGeocoder()

    func coordinate(for address: String) async throws -> CLLocationCoordinate2D {
        let placemarks = try await geocoder.geocodeAddressString(address)
        guard let loc = placemarks.first?.location else {
            throw NSError(domain: "Geocoder", code: 0, userInfo: [NSLocalizedDescriptionKey: "No location"])
        }
        return loc.coordinate
    }
}

// MARK: - Preview

#Preview("TaskRow — Address only, no coords") {
    let container = try! ModelContainer(
        for: TaskModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = container.mainContext

    let cal = Calendar.current
    let now = Date()

    let t1 = TaskModel(title: "Пойти в спортзал", dueDate: cal.date(byAdding: .day, value: 1, to: now)!)
    t1.reminderEnabled = true

    let t2 = TaskModel(title: "Купить молоко завтра утром", dueDate: cal.date(byAdding: .day, value: 2, to: now)!)
    t2.isDone = true

    // ✅ только адрес — координаты появятся после геокодинга (в превью может быть нестабильно)
    let t3 = TaskModel(title: "Встреча в кафе", dueDate: cal.date(byAdding: .day, value: 4, to: now)!)
    t3.address = "Hauptstraße 10, Köln"

    let t4 = TaskModel(title: "Стоматолог", dueDate: cal.date(byAdding: .day, value: 6, to: now)!)
    t4.address = "Berliner Allee 5, Düsseldorf"
    t4.reminderEnabled = true

    context.insert(t1)
    context.insert(t2)
    context.insert(t3)
    context.insert(t4)

    return List {
        TaskRow(task: t1, onOpen: { _ in })
        TaskRow(task: t2, onOpen: { _ in })
        TaskRow(task: t3, onOpen: { _ in })
        TaskRow(task: t4, onOpen: { _ in })
    }
    .listStyle(.plain)
    .modelContainer(container)
}
