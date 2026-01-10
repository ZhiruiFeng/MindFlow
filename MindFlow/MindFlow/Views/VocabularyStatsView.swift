//
//  VocabularyStatsView.swift
//  MindFlow
//
//  Statistics view for vocabulary learning progress
//

import SwiftUI
import Charts

/// View displaying vocabulary learning statistics
struct VocabularyStatsView: View {
    @State private var weeklyStats: [LearningStats] = []
    @State private var masteryLevelCounts: [VocabularyEntry.MasteryLevel: Int] = [:]
    @State private var totalWords: Int = 0
    @State private var totalReviews: Int = 0
    @State private var currentStreak: Int32 = 0
    @State private var overallAccuracy: Double = 0

    private let storage = VocabularyStorage.shared

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overview cards
                overviewSection

                // Mastery level breakdown
                masteryBreakdownSection

                // Weekly activity chart
                weeklyActivitySection

                // Recent sessions
                recentSessionsSection
            }
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .task {
            await loadStats()
        }
    }

    // MARK: - Overview Section

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Overview")
                .font(.headline)

            HStack(spacing: 16) {
                overviewCard(
                    title: "Total Words",
                    value: "\(totalWords)",
                    icon: "book.fill",
                    color: .blue
                )

                overviewCard(
                    title: "Mastered",
                    value: "\(masteryLevelCounts[.mastered] ?? 0)",
                    icon: "checkmark.seal.fill",
                    color: .green
                )

                overviewCard(
                    title: "Current Streak",
                    value: "\(currentStreak) days",
                    icon: "flame.fill",
                    color: .orange
                )

                overviewCard(
                    title: "Accuracy",
                    value: "\(Int(overallAccuracy))%",
                    icon: "target",
                    color: overallAccuracy >= 80 ? .green : (overallAccuracy >= 60 ? .orange : .red)
                )
            }
        }
    }

    private func overviewCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }

            Text(value)
                .font(.title)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Mastery Breakdown Section

    private var masteryBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Mastery Breakdown")
                .font(.headline)

            HStack(spacing: 24) {
                // Pie chart - use bar chart as fallback for older macOS
                masteryChart
                    .frame(width: 200, height: 200)

                // Legend
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(VocabularyEntry.MasteryLevel.allCases, id: \.self) { level in
                        HStack {
                            Circle()
                                .fill(masteryColor(level))
                                .frame(width: 12, height: 12)

                            Text(level.displayName)
                                .font(.callout)

                            Spacer()

                            Text("\(masteryLevelCounts[level] ?? 0)")
                                .font(.callout)
                                .fontWeight(.medium)
                        }
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(12)
        }
    }

    @ViewBuilder
    private var masteryChart: some View {
        if #available(macOS 14.0, *) {
            Chart(VocabularyEntry.MasteryLevel.allCases, id: \.self) { level in
                SectorMark(
                    angle: .value("Count", masteryLevelCounts[level] ?? 0),
                    innerRadius: .ratio(0.5),
                    angularInset: 1.5
                )
                .foregroundStyle(masteryColor(level))
                .cornerRadius(4)
            }
        } else {
            // Fallback bar chart for older macOS
            Chart(VocabularyEntry.MasteryLevel.allCases, id: \.self) { level in
                BarMark(
                    x: .value("Level", level.displayName),
                    y: .value("Count", masteryLevelCounts[level] ?? 0)
                )
                .foregroundStyle(masteryColor(level))
            }
        }
    }

    private func masteryColor(_ level: VocabularyEntry.MasteryLevel) -> Color {
        switch level {
        case .new: return .gray
        case .learning: return .red
        case .reviewing: return .orange
        case .familiar: return .blue
        case .mastered: return .green
        }
    }

    // MARK: - Weekly Activity Section

    private var weeklyActivitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("This Week's Activity")
                .font(.headline)

            if weeklyStats.isEmpty {
                Text("No activity this week")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 32)
            } else {
                Chart(weeklyStats) { stat in
                    BarMark(
                        x: .value("Day", stat.date, unit: .day),
                        y: .value("Words Added", stat.wordsAdded)
                    )
                    .foregroundStyle(Color.blue.gradient)

                    BarMark(
                        x: .value("Day", stat.date, unit: .day),
                        y: .value("Words Reviewed", stat.wordsReviewed)
                    )
                    .foregroundStyle(Color.green.gradient)
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day)) { value in
                        AxisValueLabel(format: .dateTime.weekday(.abbreviated))
                    }
                }
                .chartLegend(position: .bottom, alignment: .center) {
                    HStack(spacing: 16) {
                        Label("Added", systemImage: "circle.fill")
                            .foregroundColor(.blue)
                            .font(.caption)

                        Label("Reviewed", systemImage: "circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    // MARK: - Recent Sessions Section

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Review Sessions")
                .font(.headline)

            let sessions = storage.fetchRecentSessions(limit: 5)

            if sessions.isEmpty {
                Text("No review sessions yet")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                ForEach(sessions) { session in
                    sessionRow(session)
                }
            }
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }

    private func sessionRow(_ session: ReviewSession) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.startedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.callout)

                HStack(spacing: 8) {
                    Text("\(session.totalWords) words")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(session.reviewModeEnum.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                HStack(spacing: 8) {
                    Label("\(session.correctCount)", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)

                    Label("\(session.incorrectCount)", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
                .font(.caption)

                Text("\(Int(session.accuracy))% accuracy")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }

    // MARK: - Load Data

    private func loadStats() async {
        // Load mastery counts
        masteryLevelCounts = storage.getCountsByMasteryLevel()

        // Load total word count
        totalWords = storage.getWordCount()

        // Load weekly stats
        let calendar = Calendar.current
        let endDate = Date()
        let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
        weeklyStats = storage.fetchStats(from: startDate, to: endDate)

        // Calculate current streak
        currentStreak = storage.calculateStreak()

        // Calculate overall accuracy
        let allWords = storage.fetchAllWords()
        let totalReviewCount = allWords.reduce(0) { $0 + Int($1.reviewCount) }
        let totalCorrectCount = allWords.reduce(0) { $0 + Int($1.correctCount) }
        overallAccuracy = totalReviewCount > 0 ? Double(totalCorrectCount) / Double(totalReviewCount) * 100 : 0
        totalReviews = totalReviewCount
    }
}

// MARK: - Preview

struct VocabularyStatsView_Previews: PreviewProvider {
    static var previews: some View {
        VocabularyStatsView()
    }
}
