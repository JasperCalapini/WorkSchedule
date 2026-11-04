import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Platform.sortOrder) private var platforms: [Platform]
    @Query(sort: \MileageRate.effectiveFrom, order: .reverse) private var rates: [MileageRate]

    @AppStorage(SettingsKey.setAsidePercent) private var setAsidePercent = Defaults.setAsidePercent
    @AppStorage(SettingsKey.recordRoute) private var recordRoute = true
    @AppStorage(SettingsKey.weeklyGoal) private var weeklyGoal = 0.0
    @AppStorage(SettingsKey.requireFaceID) private var requireFaceID = false

    @State private var goalText = ""
    @State private var newPlatform = ""
    @State private var newRateDate = Date.now
    @State private var newRate = ""
    @State private var message: String?

    // Backup
    @State private var creatingBackup = false
    @State private var backupURL: URL?
    @State private var working = false
    @State private var importing = false
    @State private var importedData: Data?
    @State private var restorePassword = ""
    @State private var askingRestorePassword = false
    @State private var pendingRestore: Backup?

    var body: some View {
        NavigationStack {
            List {
                taxesSection
                goalsSection
                gpsSection
                backupSection
                platformsSection
                ratesSection
                aboutSection
            }
            .navigationTitle("Settings")
            .toolbar { EditButton() }
            .onAppear { goalText = weeklyGoal.fieldText }
            .sheet(isPresented: $creatingBackup) {
                BackupPasswordView { password in createBackup(password: password) }
            }
            .fileImporter(isPresented: $importing, allowedContentTypes: [.data]) { result in
                handleImport(result)
            }
            .alert("Backup password", isPresented: $askingRestorePassword) {
                SecureField("Password", text: $restorePassword)
                Button("Cancel", role: .cancel) { importedData = nil; restorePassword = "" }
                Button("Open") { decodeImport(password: restorePassword) }
            } message: {
                Text("Enter the password you chose when you made this backup.")
            }
            .confirmationDialog("Replace all data?", isPresented: Binding(
                get: { pendingRestore != nil }, set: { if !$0 { pendingRestore = nil } }
            ), titleVisibility: .visible) {
                Button("Replace with backup", role: .destructive, action: restore)
            } message: {
                if let backup = pendingRestore {
                    Text("Backup from \(backup.created.formatted(date: .abbreviated, time: .shortened)) with \(backup.shifts.count) shifts and \(backup.expenses.count) expenses. Everything currently in the app will be replaced.")
                }
            }
            .alert(message ?? "", isPresented: Binding(
                get: { message != nil }, set: { if !$0 { message = nil } }
            )) {}
            .overlay {
                if working {
                    ProgressView("Working…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                }
            }
        }
    }

    // MARK: - Sections

    private var taxesSection: some View {
        Section {
            Stepper(value: $setAsidePercent, in: 0...50, step: 1) {
                LabeledContent("Set aside", value: "\(setAsidePercent)%")
            }
        } header: {
            Text("Taxes")
        } footer: {
            Text("Profit × this % = what the Taxes tab tells you to save. 25–30% is typical.")
        }
    }

    private var goalsSection: some View {
        Section {
            LabeledContent("Weekly earnings goal") {
                TextField("Off", text: $goalText)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .onChange(of: goalText) { weeklyGoal = max(0, parseNumber(goalText) ?? 0) }
            }
            Toggle("Require Face ID", isOn: Binding(get: { requireFaceID }, set: setFaceID))
        } header: {
            Text("Goals & privacy")
        } footer: {
            Text("Leave the goal empty to hide the progress bar. Face ID keeps your earnings and routes private; the app is always hidden in the app switcher.")
        }
    }

    private var gpsSection: some View {
        Section {
            Toggle("Save route map", isOn: $recordRoute)
        } header: {
            Text("GPS")
        } footer: {
            Text("Saves where you drove during GPS-tracked shifts so you can review it on a map. Stored only on this iPhone, about 100–300 KB per shift.")
        }
    }

    private var backupSection: some View {
        Section {
            if let backupURL {
                ShareLink(item: backupURL) {
                    Label("Save backup file…", systemImage: "square.and.arrow.up")
                }
            } else {
                Button("Create backup", systemImage: "lock.doc") { creatingBackup = true }
            }
            Button("Restore from backup…", systemImage: "arrow.counterclockwise") { importing = true }
        } header: {
            Text("Backup")
        } footer: {
            Text("Saves everything (shifts, routes, photos, expenses) to one file, encrypted with a password you choose. Keep it in Files, iCloud Drive or email it to yourself, then restore it on a new phone.")
        }
    }

    private var platformsSection: some View {
        Section("Platforms") {
            ForEach(platforms) { Text($0.name) }
                .onDelete { offsets in for i in offsets { context.delete(platforms[i]) } }
                .onMove(perform: movePlatforms)
            HStack {
                TextField("Add platform (e.g. Shipt)", text: $newPlatform)
                Button("Add", action: addPlatform)
                    .disabled(newPlatform.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    private var ratesSection: some View {
        Section {
            ForEach(rates) { r in
                LabeledContent("From \(r.effectiveFrom.formatted(date: .abbreviated, time: .omitted))",
                               value: "$\(r.rate.formatted()) / mi")
            }
            .onDelete { offsets in for i in offsets { context.delete(rates[i]) } }
            DatePicker("Effective from", selection: $newRateDate, displayedComponents: .date)
            HStack {
                TextField("Rate (e.g. 0.70)", text: $newRate).keyboardType(.decimalPad)
                Button("Set", action: setRate)
                    .disabled((parseNumber(newRate) ?? 0) <= 0)
            }
        } header: {
            Text("IRS mileage rate")
        } footer: {
            Text("IRS standard mileage rate per mile. Check irs.gov each year; the IRS sometimes changes it mid-year.")
        }
    }

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: AppInfo.versionDescription)
            Text("Not tax advice. Your data stays on this iPhone.")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    // MARK: - Face ID

    private func setFaceID(_ on: Bool) {
        guard on else {
            requireFaceID = false
            return
        }
        guard AppLock.isAvailable else {
            message = "Set up Face ID or a passcode in iPhone Settings first."
            return
        }
        AppLock.shared.confirmOwner(reason: "Turn on Face ID lock") { success in
            requireFaceID = success
        }
    }

    // MARK: - Backup

    private func createBackup(password: String) {
        let backup: Backup
        do {
            // A separate context: reading every photo and route here would otherwise keep
            // them all cached in the main context (often 100+ MB) until the app restarts.
            let snapshot = ModelContext(context.container)
            backup = try Backup(context: snapshot)
        } catch {
            message = "Couldn't read your data for the backup: \(error.localizedDescription)"
            return
        }
        working = true
        Task {
            // Encoding, key derivation and encryption are slow; keep them off the main thread.
            let result = await Task.detached(priority: .userInitiated) {
                try ExportFiles.write(backup.encrypted(password: password), named: backup.fileName)
            }.result
            working = false
            switch result {
            case .success(let url): backupURL = url
            case .failure(let error): message = "Couldn't create the backup: \(error.localizedDescription)"
            }
        }
    }

    private func handleImport(_ result: Result<URL, Error>) {
        do {
            let data = try Backup.readFile(at: result.get())
            if BackupCrypto.isEncrypted(data) {
                importedData = data
                restorePassword = ""
                askingRestorePassword = true
            } else {
                pendingRestore = try Backup.decode(data, password: nil)
            }
        } catch {
            message = error.localizedDescription
        }
    }

    private func decodeImport(password: String) {
        guard let data = importedData else { return }
        importedData = nil
        restorePassword = ""
        working = true
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                try Backup.decode(data, password: password)
            }.result
            working = false
            switch result {
            case .success(let backup): pendingRestore = backup
            case .failure(let error): message = error.localizedDescription
            }
        }
    }

    private func restore() {
        guard let backup = pendingRestore else { return }
        pendingRestore = nil
        LocationTracker.shared.stop()
        LiveActivityController.end()
        do {
            try backup.restore(into: context)
            backupURL = nil
            ShiftControl.resumeIfNeeded()
            message = "Backup restored."
        } catch {
            message = "Restore failed, and your current data was kept: \(error.localizedDescription)"
            ShiftControl.resumeIfNeeded()
        }
    }

    // MARK: - Platforms and rates

    private func addPlatform() {
        let name = newPlatform.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty,
              !platforms.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return }
        context.insert(Platform(name: name, sortOrder: (platforms.map(\.sortOrder).max() ?? -1) + 1))
        newPlatform = ""
    }

    private func movePlatforms(from source: IndexSet, to destination: Int) {
        var ordered = platforms
        ordered.move(fromOffsets: source, toOffset: destination)
        for (i, p) in ordered.enumerated() { p.sortOrder = i }
    }

    private func setRate() {
        guard let rate = parseNumber(newRate), rate > 0 else { return }
        let day = Calendar.current.startOfDay(for: newRateDate)
        if let existing = rates.first(where: { $0.effectiveFrom == day }) {
            existing.rate = rate
        } else {
            context.insert(MileageRate(effectiveFrom: day, rate: rate))
        }
        newRate = ""
    }
}

/// Asks for the password that will encrypt a new backup.
struct BackupPasswordView: View {
    let onCreate: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var password = ""
    @State private var confirmation = ""

    private var problem: String? {
        if password.count < BackupCrypto.minimumPasswordLength {
            return "Use at least \(BackupCrypto.minimumPasswordLength) characters."
        }
        if password != confirmation { return "The passwords don't match." }
        return nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    SecureField("Password", text: $password)
                        .textContentType(.newPassword)
                    SecureField("Confirm password", text: $confirmation)
                        .textContentType(.newPassword)
                } footer: {
                    VStack(alignment: .leading, spacing: 6) {
                        if let problem, !password.isEmpty { Text(problem).foregroundStyle(.red) }
                        Text("You'll need this password to restore. If you forget it, the backup can't be opened — not even by the developer.")
                    }
                }
            }
            .navigationTitle("Protect backup")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        onCreate(password)
                        dismiss()
                    }
                    .disabled(problem != nil)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

/// Version and build number from the app bundle.
enum AppInfo {
    static var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
    static var build: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }
    static var versionDescription: String { "\(version) (\(build))" }
}
