/// The widget extension can't change shifts itself; Live Activity buttons run
/// ToggleErrandIntent inside the app, which has the real ShiftControl.
@MainActor
enum ShiftControl {
    static func toggleErrand() {}
}
