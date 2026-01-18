import SwiftUI
import Charts
@preconcurrency import Auth

struct ChartsView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var chartService = ChartService()

    // Selection state
    @State private var selectedExerciseId: UUID?
    @State private var selectedMetric: ChartMetric = .heaviestWeight
    @State private var selectedTimeRange: ChartTimeRange = .threeMonths

    // UI state
    @State private var showingExercisePicker = false
    @State private var selectedDataPoint: ChartDataPoint?
    @State private var selectedDate: Date?

    private var selectedExercise: Exercise? {
        guard let id = selectedExerciseId else { return nil }
        return chartService.exercise(for: id)
    }

    private var chartData: [ChartDataPoint] {
        chartService.getChartData(for: selectedMetric)
    }

    var body: some View {
        List {
            // Exercise Selector
            Section {
                exercisePickerButton
            } header: {
                Text("Exercise")
            }

            // Filters
            Section {
                // Metric picker
                Picker("Metric", selection: $selectedMetric) {
                    ForEach(ChartMetric.allCases) { metric in
                        Text(metric.rawValue).tag(metric)
                    }
                }

                // Time range picker
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(ChartTimeRange.allCases) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Filters")
            }

            // Chart
            Section {
                if selectedExerciseId == nil {
                    emptyState
                } else if chartService.isLoading {
                    loadingState
                } else if chartData.isEmpty {
                    noDataState
                } else {
                    chartView
                }
            } header: {
                Text("Progression")
            }

            // Stats summary
            if !chartData.isEmpty {
                Section {
                    statsSummary
                } header: {
                    Text("Summary")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Charts")
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerSheet(
                exercises: chartService.exercises,
                selectedId: $selectedExerciseId
            )
        }
        .onChange(of: selectedExerciseId) {
            Task { await fetchChartData() }
        }
        .onChange(of: selectedTimeRange) {
            Task { await fetchChartData() }
        }
        .task {
            await chartService.fetchExercises()
        }
    }

    // MARK: - Subviews

    private var exercisePickerButton: some View {
        Button {
            showingExercisePicker = true
        } label: {
            HStack {
                Text(selectedExercise?.name ?? "Select Exercise")
                    .foregroundStyle(selectedExercise == nil ? .secondary : .primary)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(.primary)
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("Select an exercise")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("Choose an exercise above to view your progression")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .listRowBackground(Color.clear)
    }

    private var loadingState: some View {
        VStack {
            ProgressView()
            Text("Loading data...")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
    }

    private var noDataState: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No data available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("No sets recorded for this exercise in the selected time range")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .listRowBackground(Color.clear)
    }

    private var chartView: some View {
        Chart(chartData) { dataPoint in
            LineMark(
                x: .value("Date", dataPoint.date, unit: .day),
                y: .value(selectedMetric.rawValue, dataPoint.value)
            )
            .foregroundStyle(Color.appAccent)
            .interpolationMethod(.catmullRom)

            AreaMark(
                x: .value("Date", dataPoint.date, unit: .day),
                y: .value(selectedMetric.rawValue, dataPoint.value)
            )
            .foregroundStyle(
                LinearGradient(
                    colors: [Color.appAccent.opacity(0.3), Color.appAccent.opacity(0.0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.catmullRom)

            PointMark(
                x: .value("Date", dataPoint.date, unit: .day),
                y: .value(selectedMetric.rawValue, dataPoint.value)
            )
            .foregroundStyle(Color.appAccent)
            .symbolSize(selectedDataPoint?.date == dataPoint.date ? 60 : 30)

            // Vertical rule for selected point
            if let selected = selectedDataPoint, selected.date == dataPoint.date {
                RuleMark(x: .value("Date", dataPoint.date, unit: .day))
                    .foregroundStyle(Color.appAccent.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 3]))
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: xAxisStride)) { value in
                AxisGridLine()
                AxisValueLabel(format: xAxisFormat)
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine()
                AxisValueLabel()
            }
        }
        .chartYScale(domain: yAxisDomain)
        .chartXSelection(value: $selectedDate)
        .onChange(of: selectedDate) { _, newDate in
            if let date = newDate {
                selectedDataPoint = chartData.min(by: {
                    abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
                })
            } else {
                selectedDataPoint = nil
            }
        }
        .frame(height: 220)
        .padding(.vertical, AppSpacing.sm)
        .overlay(alignment: .top) {
            if let dataPoint = selectedDataPoint {
                tooltipView(for: dataPoint)
                    .padding(.top, 4)
            }
        }
    }

    private func tooltipView(for dataPoint: ChartDataPoint) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(dataPoint.date, format: .dateTime.day().month(.abbreviated))
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text("\(formatValue(dataPoint.value)) \(selectedMetric.unit)")
                .font(.caption)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(UIColor.secondarySystemBackground))
                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
        )
    }

    private var statsSummary: some View {
        Group {
            if let minValue = chartData.map({ $0.value }).min(),
               let maxValue = chartData.map({ $0.value }).max(),
               let firstValue = chartData.first?.value,
               let lastValue = chartData.last?.value {

                HStack {
                    Text("Min")
                    Spacer()
                    Text("\(formatValue(minValue)) \(selectedMetric.unit)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Max")
                    Spacer()
                    Text("\(formatValue(maxValue)) \(selectedMetric.unit)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Change")
                    Spacer()
                    let change = lastValue - firstValue
                    let percentChange = firstValue > 0 ? (change / firstValue) * 100 : 0
                    HStack(spacing: 4) {
                        Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        Text("\(formatValue(abs(change))) \(selectedMetric.unit) (\(String(format: "%.1f", abs(percentChange)))%)")
                    }
                    .foregroundStyle(change >= 0 ? .green : .red)
                }
            }
        }
    }

    // MARK: - Helpers

    private var yAxisDomain: ClosedRange<Double> {
        let values = chartData.map { $0.value }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100

        // Add some padding to the range
        let padding = (maxValue - minValue) * 0.15
        let lowerBound = max(0, minValue - padding)
        let upperBound = maxValue + padding

        return lowerBound...upperBound
    }

    private var xAxisStride: Calendar.Component {
        switch selectedTimeRange {
        case .oneMonth:
            return .weekOfYear
        case .threeMonths:
            return .month
        case .sixMonths:
            return .month
        case .oneYear:
            return .month
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedTimeRange {
        case .oneMonth:
            return .dateTime.day().month(.abbreviated)
        case .threeMonths, .sixMonths, .oneYear:
            return .dateTime.month(.abbreviated)
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.0f", value)
        } else if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }

    private func fetchChartData() async {
        guard let userId = authManager.currentUser?.id,
              let exerciseId = selectedExerciseId else { return }

        await chartService.fetchSets(
            exerciseId: exerciseId,
            userId: userId,
            since: selectedTimeRange.startDate
        )
    }
}

#Preview {
    NavigationStack {
        ChartsView()
            .environment(AuthManager())
    }
}
