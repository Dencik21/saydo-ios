import SwiftUI
import MapKit
import CoreLocation

struct TaskRow: View {

    let task: TaskModel

    var onToggleDone: ((TaskModel) -> Void)? = nil
    var onOpen: ((TaskModel) -> Void)? = nil

    /// ✅ сюда родитель передаст “как кешировать координаты”
    var onCacheCoordinate: ((TaskModel, CLLocationCoordinate2D) -> Void)? = nil

    @StateObject private var vm = TaskRowViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {

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
                .onTapGesture { onOpen?(task) }

                // RIGHT ZONE (buttons only)
                if hasAddressOrCoord {
                    HStack(spacing: 10) {
                        mapToggleButton
                        routeButton
                    }
                    .padding(.top, 2)
                }
            }

            if vm.isMapExpanded {
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
            vm.setInitialCoordinateIfNeeded(coordinateFromModel)
        }
    }

    // MARK: - Derived

    private var addressTrimmed: String {
        (task.address ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasAddress: Bool { !addressTrimmed.isEmpty }

    private var hasAddressOrCoord: Bool {
        coordinateFromModel != nil || hasAddress
    }

    private var coordinateFromModel: CLLocationCoordinate2D? {
        guard let lat = task.locationLat, let lon = task.locationLon else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    private var effectiveCoordinate: CLLocationCoordinate2D? {
        coordinateFromModel ?? vm.resolvedCoord
    }

    private func cache(_ coord: CLLocationCoordinate2D) {
        onCacheCoordinate?(task, coord)
    }

    // MARK: - UI Parts

    private var doneButton: some View {
        Button {
            if let onToggleDone {
                onToggleDone(task)
            } else {
                task.isDone.toggle()
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
        HStack(alignment: .firstTextBaseline, spacing: 8) {

            if let icon = priorityIconName {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(priorityIconStyle)
                    .padding(.top, 1)
                    .accessibilityLabel(task.priorityRaw == 2 ? "Срочно" : "Важно")
            }

            Text(task.title)
                .font(.body)
                .lineLimit(2)
                .foregroundStyle(.primary)

            Spacer(minLength: 0)
        }
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
            vm.toggleMap(
                hasAddress: hasAddress,
                effectiveCoordinate: effectiveCoordinate,
                address: addressTrimmed,
                onResolved: { cache($0) }
            )
        } label: {
            if vm.isResolving {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: vm.isMapExpanded ? "chevron.up.circle.fill" : "chevron.down.circle.fill")
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
            Task {
                await vm.openInMapsSmart(
                    title: task.title,
                    address: addressTrimmed,
                    effectiveCoordinate: effectiveCoordinate,
                    onResolved: { cache($0) }
                )
            }
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

            Text(vm.resolveError ? "Не получилось найти адрес" : "Ищу адрес на карте…")
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            if vm.resolveError {
                Button("Повторить") {
                    Task {
                        await vm.resolveCoordinateIfNeeded(
                            address: addressTrimmed,
                            effectiveCoordinate: effectiveCoordinate,
                            force: true,
                            onResolved: { cache($0) }
                        )
                    }
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
            if effectiveCoordinate == nil, hasAddress, vm.isResolving == false {
                Task {
                    await vm.resolveCoordinateIfNeeded(
                        address: addressTrimmed,
                        effectiveCoordinate: effectiveCoordinate,
                        onResolved: { cache($0) }
                    )
                }
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
        .onTapGesture {
            Task {
                await vm.openInMapsSmart(
                    title: task.title,
                    address: addressTrimmed,
                    effectiveCoordinate: effectiveCoordinate,
                    onResolved: { cache($0) }
                )
            }
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .fill(.background)
            .shadow(radius: 6, y: 2)
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
    
    // MARK: - Derived
    private var priorityIconName: String? {
        switch task.priorityRaw {
        case 2: return "exclamationmark.triangle.fill" // urgent
        case 1: return "star.fill"                      // important
        default: return nil
        }
    }

    private var priorityIconStyle: some ShapeStyle {
        if task.priorityRaw == 2 { return AnyShapeStyle(.orange) }
        if task.priorityRaw == 1 { return AnyShapeStyle(.yellow) }
        return AnyShapeStyle(.secondary)
    }
}
// MARK: - Preview

