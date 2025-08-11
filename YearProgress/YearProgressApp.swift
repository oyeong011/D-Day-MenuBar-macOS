import SwiftUI

// MARK: - Main App Entry Point
@main
struct YearProgressApp: App {
    // Use NSApplicationDelegateAdaptor to integrate AppDelegate for app-level configurations.
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = ProgressViewModel()

    var body: some Scene {
        MenuBarExtra {
            ContentView(viewModel: viewModel)
        } label: {
            LabelView(viewModel: viewModel)
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - AppDelegate
// Manages app-level behavior, such as hiding the Dock icon.
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set the app's activation policy to .accessory to hide it from the Dock.
        NSApp.setActivationPolicy(.accessory)
    }
}


// MARK: - ViewModel
// Handles all business logic, data management, and state for the views.
class ProgressViewModel: ObservableObject {
    // MARK: - Published Properties
    // These properties will trigger UI updates when their values change.
    @Published var currentDate = Date()
    @Published var yearProgress: Double = 0.0
    @Published var quarterProgress: Double = 0.0
    @Published var weekOfYearText: String = ""
    @Published var dayOfYearText: String = ""
    @Published var dDayText: String = "D-Day"
    @Published var remainingTimeText: String = ""
    @Published var currentAnimationFrame: Int = 0

    // MARK: - AppStorage Properties
    // These properties are persisted in UserDefaults.
    @AppStorage("displayStyle") var displayStyle: DisplayStyle = .showPercent
    @AppStorage("iconStyle") var iconStyle: IconAnimationStyle = .fillingPie
    
    @Published var customColor: Color {
        didSet { saveColor(customColor) }
    }
    @Published var targetDate: Date {
        didSet {
            UserDefaults.standard.set(targetDate, forKey: "targetDate")
            updateData() // Recalculate all data whenever the target date changes.
        }
    }

    // MARK: - Private Properties
    private var timer: Timer?
    private var animationTimer: Timer?
    private let calendar = Calendar.current

    // MARK: - Initializer
    init() {
        // Load saved settings from UserDefaults.
        self.customColor = ProgressViewModel.loadColor()
        if let savedDate = UserDefaults.standard.object(forKey: "targetDate") as? Date {
            self.targetDate = savedDate
        } else {
            // Set default target date to the end of the current year.
            let startOfYear = calendar.date(from: calendar.dateComponents([.year], from: Date()))!
            self.targetDate = calendar.date(byAdding: DateComponents(year: 1, day: -1), to: startOfYear)!
        }
        
        updateData()

        // Setup timers for periodic updates.
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.updateData()
        }
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            self?.updateAnimation()
        }
    }

    // MARK: - Data Calculation
    /// Calculates all date-related values and statistics.
    func updateData() {
        currentDate = Date()
        
        // Calculate D-Day
        let dDayComponents = calendar.dateComponents([.day], from: calendar.startOfDay(for: currentDate), to: calendar.startOfDay(for: targetDate))
        let days = dDayComponents.day ?? 0
        if days == 0 {
            dDayText = NSLocalizedString("dday_today", comment: "Label for the target day")
        } else if days > 0 {
            dDayText = String.localizedStringWithFormat(NSLocalizedString("dday_future", comment: "Label for days remaining"), days)
        } else {
            dDayText = String.localizedStringWithFormat(NSLocalizedString("dday_past", comment: "Label for days passed"), -days)
        }

        // Calculate detailed remaining time (months, days, hours)
        let timeComponents = calendar.dateComponents([.month, .day, .hour], from: currentDate, to: targetDate)
        var remainingParts: [String] = []
        if let month = timeComponents.month, month > 0 {
            remainingParts.append(String.localizedStringWithFormat(NSLocalizedString("time_unit_month", comment: "Time unit for month"), month))
        }
        if let day = timeComponents.day, day > 0 {
            remainingParts.append(String.localizedStringWithFormat(NSLocalizedString("time_unit_day", comment: "Time unit for day"), day))
        }
        if let hour = timeComponents.hour, hour >= 0 {
             remainingParts.append(String.localizedStringWithFormat(NSLocalizedString("time_unit_hour", comment: "Time unit for hour"), hour))
        }
        remainingTimeText = remainingParts.joined(separator: " ")

        // Calculate year progress
        guard let yearInterval = calendar.dateInterval(of: .year, for: currentDate) else { return }
        yearProgress = currentDate.timeIntervalSince(yearInterval.start) / yearInterval.duration
        
        // Generate yearly statistics text
        let totalDaysInYear = calendar.dateComponents([.day], from: yearInterval.start, to: yearInterval.end).day ?? 365
        let dayOfYear = calendar.ordinality(of: .day, in: .year, for: currentDate) ?? 0
        dayOfYearText = String.localizedStringWithFormat(NSLocalizedString("stats_day_of_year_format", comment: "Format for day of year"), dayOfYear, totalDaysInYear)
        
        let weekOfYear = calendar.component(.weekOfYear, from: currentDate)
        weekOfYearText = String.localizedStringWithFormat(NSLocalizedString("stats_week_of_year_format", comment: "Format for week of year"), weekOfYear)
        
        // Calculate quarter progress
        guard let quarterInterval = calendar.dateInterval(of: .quarter, for: currentDate) else { return }
        quarterProgress = currentDate.timeIntervalSince(quarterInterval.start) / quarterInterval.duration
    }
    
    // MARK: - Animation
    /// Updates the current frame for the animated icon.
    func updateAnimation() {
        let totalFrames = iconStyle.frames.count
        currentAnimationFrame = (currentAnimationFrame + 1) % totalFrames
    }

    /// Provides the current icon name based on progress and animation cycle.
    var currentIconName: String {
        let frames = iconStyle.frames
        let frameIndexBasedOnProgress = Int(yearProgress * Double(frames.count - 1))
        let finalIndex = (frameIndexBasedOnProgress + currentAnimationFrame) % frames.count
        return frames[finalIndex]
    }
    
    // MARK: - Computed Properties & Helpers
    /// Returns the localized title for the current quarter.
    var quarterText: String {
        let quarter = calendar.component(.quarter, from: currentDate)
        return String.localizedStringWithFormat(NSLocalizedString("stats_quarter_progress_title_format", comment: "Title for quarter progress"), quarter)
    }
    
    /// Returns the year progress as a formatted percentage string.
    var yearProgressText: String {
        return String(format: "%.0f%%", yearProgress * 100)
    }
    
    // MARK: - Persistence
    private func saveColor(_ color: Color) {
        if let data = try? NSKeyedArchiver.archivedData(withRootObject: NSColor(color), requiringSecureCoding: false) {
            UserDefaults.standard.set(data, forKey: "progressColor")
        }
    }
    
    private static func loadColor() -> Color {
        guard let data = UserDefaults.standard.data(forKey: "progressColor"),
              let nsColor = try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: data) else {
            return .accentColor
        }
        return Color(nsColor)
    }
    
    // MARK: - Enums for Settings
    enum DisplayStyle: String, CaseIterable, Identifiable {
        case showPercent
        case showDDay
        
        var id: Self { self }
        
        var title: String {
            switch self {
            case .showPercent: return NSLocalizedString("style_show_percent", comment: "Picker option to show percentage")
            case .showDDay: return NSLocalizedString("style_show_dday", comment: "Picker option to show D-Day")
            }
        }
    }
    
    enum IconAnimationStyle: String, CaseIterable, Identifiable {
        case fillingPie
        case clock
        case battery
        case hourglass
        case moon
        
        var id: Self { self }
        
        var title: String {
            switch self {
            case .fillingPie: return NSLocalizedString("icon_style_pie", comment: "Icon style name")
            case .clock: return NSLocalizedString("icon_style_clock", comment: "Icon style name")
            case .battery: return NSLocalizedString("icon_style_battery", comment: "Icon style name")
            case .hourglass: return NSLocalizedString("icon_style_hourglass", comment: "Icon style name")
            case .moon: return NSLocalizedString("icon_style_moon", comment: "Icon style name")
            }
        }
        
        var frames: [String] {
            switch self {
            case .fillingPie:
                return ["circle.dotted", "circle.lefthalf.filled", "circle.filled", "circle.righthalf.filled"]
            case .clock:
                return ["clock", "clock.fill"]
            case .battery:
                return ["battery.0", "battery.25", "battery.50", "battery.75", "battery.100"]
            case .hourglass:
                return ["hourglass.bottomhalf.filled", "hourglass", "hourglass.tophalf.filled"]
            case .moon:
                return ["moon.new", "moon.waxing.crescent", "moon.first.quarter", "moon.waxing.gibbous", "moon.full", "moon.waning.gibbous", "moon.last.quarter", "moon.waning.crescent"]
            }
        }
    }
}

// MARK: - SwiftUI Views

/// The view displayed in the menu bar.
struct LabelView: View {
    @ObservedObject var viewModel: ProgressViewModel

    var body: some View {
        let displayFont = Font.system(size: 13, design: .rounded).weight(.bold)
        
        HStack(spacing: 4) {
            Image(systemName: viewModel.currentIconName)

            switch viewModel.displayStyle {
            case .showPercent:
                Text(viewModel.yearProgressText)
                    .font(displayFont)
            case .showDDay:
                Text(viewModel.dDayText)
                    .font(displayFont)
            }
        }
        .foregroundColor(viewModel.customColor)
    }
}

/// The main content view shown when the menu bar item is clicked.
struct ContentView: View {
    @ObservedObject var viewModel: ProgressViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header Section
            VStack {
                Text(viewModel.targetDate.formatted(date: .long, time: .omitted))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(viewModel.dDayText)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundColor(viewModel.customColor)
            }
            .padding()

            Divider()
            
            // Statistics Section
            VStack(spacing: 12) {
                InfoRowView(icon: "timer", title: NSLocalizedString("stats_remaining_time_title", comment: ""), value: viewModel.remainingTimeText)
                InfoRowView(icon: "calendar", title: NSLocalizedString("stats_day_of_year_title", comment: ""), value: viewModel.dayOfYearText)
                InfoRowView(icon: "7.square.fill", title: NSLocalizedString("stats_week_of_year_title", comment: ""), value: viewModel.weekOfYearText)
                
                VStack(spacing: 4) {
                    InfoRowView(icon: "chart.pie.fill", title: viewModel.quarterText, value: String(format: "%.1f%%", viewModel.quarterProgress * 100))
                    ProgressBar(value: viewModel.quarterProgress, color: .green, height: 5)
                }
            }
            .padding()

            Divider()

            // Settings Section
            VStack(alignment: .leading, spacing: 12) {
                Text(NSLocalizedString("settings_title", comment: "")).font(.headline).padding(.horizontal)
                
                DatePicker(NSLocalizedString("settings_dday_datepicker", comment: ""), selection: $viewModel.targetDate, displayedComponents: .date)
                    .padding(.horizontal)
                
                Picker(NSLocalizedString("settings_menubar_text_style", comment: ""), selection: $viewModel.displayStyle) {
                    ForEach(ProgressViewModel.DisplayStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Text(NSLocalizedString("settings_icon_style", comment: ""))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(ProgressViewModel.IconAnimationStyle.allCases) { style in
                            Button(action: {
                                viewModel.iconStyle = style
                            }) {
                                HStack {
                                    Image(systemName: style.frames.first ?? "questionmark")
                                        .frame(width: 20)
                                    Text(style.title)
                                    Spacer()
                                    if viewModel.iconStyle == style {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(viewModel.customColor)
                                    }
                                }
                                .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12))
                                .background(viewModel.iconStyle == style ? Color.accentColor.opacity(0.15) : Color.clear)
                                .cornerRadius(8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: 120)
                .padding(.horizontal)
                
                ColorPicker(NSLocalizedString("settings_theme_color", comment: ""), selection: $viewModel.customColor, supportsOpacity: false)
                    .padding(.horizontal)
            }
            .padding(.vertical)
            
            // Footer Section
            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text(NSLocalizedString("button_quit", comment: ""))
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(.quaternary)
        }
        .frame(width: 320)
    }
}

/// A reusable view for displaying a row of information with an icon, title, and value.
struct InfoRowView: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Image(systemName: icon)
                .font(.body)
                .frame(width: 20)
                .foregroundColor(.secondary)
            
            Text(title)
                .font(.callout)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.system(.body, design: .rounded).weight(.semibold))
        }
    }
}

/// A customizable progress bar view.
struct ProgressBar: View {
    let value: Double
    let color: Color
    var height: CGFloat = 8
    var width: CGFloat? = nil

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(Color.gray.opacity(0.2))
                Rectangle()
                    .foregroundColor(color)
                    .frame(width: geometry.size.width * value)
            }
        }
        .frame(width: width, height: height)
        .cornerRadius(height / 2)
        .animation(.easeOut, value: value)
    }
}
