import SwiftUI

// MARK: - Watch Colors

extension Color {
    /// Primary accent color - matches iOS app
    static let watchAccent = Color(red: 220/255, green: 36/255, blue: 67/255) // #DC2443

    /// Secondary accent for less prominent elements
    static let watchAccentSecondary = Color.watchAccent.opacity(0.7)

    /// Success color for PR celebrations
    static let watchSuccess = Color.green

    /// Warning color for rest timer
    static let watchWarning = Color.orange
}

// MARK: - Watch Fonts

extension Font {
    /// Large numbers for weight/reps display
    static let watchLargeNumber = Font.system(size: 42, weight: .bold, design: .rounded)

    /// Medium numbers for inputs
    static let watchMediumNumber = Font.system(size: 28, weight: .semibold, design: .rounded)

    /// Title for section headers
    static let watchTitle = Font.headline.weight(.semibold)

    /// Body text
    static let watchBody = Font.body

    /// Caption for secondary information
    static let watchCaption = Font.caption2
}

// MARK: - Watch Spacing

enum WatchSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
}

// MARK: - Watch Components

struct WatchButton: View {
    let title: String
    let action: () -> Void
    var isDestructive: Bool = false

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.watchBody)
                .foregroundColor(isDestructive ? .red : .watchAccent)
        }
    }
}

struct WatchPrimaryButton: View {
    let title: String
    let action: () -> Void
    var isLoading: Bool = false

    var body: some View {
        Button(action: action) {
            HStack {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.watchBody.weight(.semibold))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, WatchSpacing.sm)
        }
        .buttonStyle(.borderedProminent)
        .tint(.watchAccent)
        .disabled(isLoading)
    }
}

struct WatchStepperRow: View {
    let label: String
    @Binding var value: Double
    let step: Double
    let range: ClosedRange<Double>
    var format: String = "%.1f"

    var body: some View {
        VStack(spacing: WatchSpacing.xs) {
            Text(label)
                .font(.watchCaption)
                .foregroundColor(.secondary)

            HStack {
                Button {
                    if value - step >= range.lowerBound {
                        value -= step
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.watchAccent)
                }
                .buttonStyle(.plain)

                Text(String(format: format, value))
                    .font(.watchMediumNumber)
                    .frame(minWidth: 60)

                Button {
                    if value + step <= range.upperBound {
                        value += step
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.watchAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct WatchIntStepperRow: View {
    let label: String
    @Binding var value: Int
    let step: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(spacing: WatchSpacing.xs) {
            Text(label)
                .font(.watchCaption)
                .foregroundColor(.secondary)

            HStack {
                Button {
                    if value - step >= range.lowerBound {
                        value -= step
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.watchAccent)
                }
                .buttonStyle(.plain)

                Text("\(value)")
                    .font(.watchMediumNumber)
                    .frame(minWidth: 50)

                Button {
                    if value + step <= range.upperBound {
                        value += step
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundColor(.watchAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - PR Celebration

struct PRCelebrationView: View {
    let prTypes: [String]

    var body: some View {
        VStack(spacing: WatchSpacing.sm) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 40))
                .foregroundColor(.yellow)

            Text("NEW PR!")
                .font(.watchTitle)
                .foregroundColor(.watchSuccess)

            ForEach(prTypes, id: \.self) { prType in
                Text(prType)
                    .font(.watchCaption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}

// MARK: - Watch Number Pad

struct WatchNumberPad: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    @Environment(\.dismiss) private var dismiss

    @State private var inputString: String = ""
    @State private var hasDecimal: Bool = false

    init(value: Binding<Double>, range: ClosedRange<Double>) {
        self._value = value
        self.range = range
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 2) {
                    // Number pad grid
                    VStack(spacing: 2) {
                        HStack(spacing: 2) {
                            numberButton("1")
                            numberButton("2")
                            numberButton("3")
                        }
                        HStack(spacing: 2) {
                            numberButton("4")
                            numberButton("5")
                            numberButton("6")
                        }
                        HStack(spacing: 2) {
                            numberButton("7")
                            numberButton("8")
                            numberButton("9")
                        }
                        HStack(spacing: 2) {
                            numberButton(".")
                            numberButton("0")
                            backspaceButton
                        }
                    }

                    // Confirm button
                    Button {
                        confirmValue()
                    } label: {
                        Text("Done")
                            .font(.watchBody.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.watchAccent)
                    .padding(.top, WatchSpacing.xs)
                }
                .padding(.horizontal, WatchSpacing.xs)
            }
            .navigationTitle("\(inputString.isEmpty ? "0" : inputString) kg")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
            }
        }
        .onAppear {
            // Initialize with current value
            if value > 0 {
                if value.truncatingRemainder(dividingBy: 1) == 0 {
                    inputString = String(format: "%.0f", value)
                } else {
                    inputString = String(format: "%.1f", value)
                }
                hasDecimal = inputString.contains(".")
            }
        }
    }

    private func numberButton(_ digit: String) -> some View {
        Button {
            appendDigit(digit)
        } label: {
            Text(digit)
                .font(.system(size: 22, weight: .medium, design: .rounded))
                .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }

    private var backspaceButton: some View {
        Button {
            deleteLastDigit()
        } label: {
            Image(systemName: "delete.left")
                .font(.system(size: 18))
                .frame(maxWidth: .infinity, minHeight: 38)
        }
        .buttonStyle(.bordered)
        .tint(.secondary)
    }

    private func appendDigit(_ digit: String) {
        if digit == "." {
            guard !hasDecimal else { return }
            if inputString.isEmpty {
                inputString = "0."
            } else {
                inputString += "."
            }
            hasDecimal = true
        } else {
            // Limit decimal places to 1
            if hasDecimal {
                let parts = inputString.split(separator: ".")
                if parts.count > 1 && parts[1].count >= 1 {
                    return
                }
            }
            // Limit total length
            if inputString.count >= 5 { return }
            inputString += digit
        }
    }

    private func deleteLastDigit() {
        guard !inputString.isEmpty else { return }
        let removed = inputString.removeLast()
        if removed == "." {
            hasDecimal = false
        }
    }

    private func confirmValue() {
        let newValue = Double(inputString) ?? 0
        let clampedValue = min(max(newValue, range.lowerBound), range.upperBound)
        value = clampedValue
        dismiss()
    }
}
