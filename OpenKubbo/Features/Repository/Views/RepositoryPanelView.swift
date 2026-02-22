import AppKit
import ObjectiveC.runtime
import SwiftUI

// MARK: - Data Model

private struct RepoItem: Identifiable, Equatable {
    let id: String
    let name: String
    let issues: Int
    let prs: Int
    let stars: Int
    let branch: String
    let updatedAgo: String
    let isPinned: Bool
    let isWork: Bool
    let releases: Int
    let ciRuns: Int
    let discussions: Int
    let tags: Int
    let branches: Int
    let contributors: Int
    let openCommits: Int
}

private struct RepoMetric: Identifiable {
    let id: String
    let icon: String
    let title: String
    let value: Int?
}

// MARK: - Main View

struct RepositoryPanelView: View {
    private let collapsedPanelWidth: CGFloat = 340
    private let expandedPanelHeight: CGFloat = 704
    private let expandedRightColumnWidth: CGFloat = 420

    private let panelHorizontalInset: CGFloat = 2
    private let panelVerticalInset: CGFloat = 6
    private let windowEdgePaddingX: CGFloat = 10
    private let windowEdgePaddingY: CGFloat = 12

    @State private var hostWindow: NSWindow?
    @State private var selectedFilter: RepoFilter = .all
    @State private var selectedRepoID: String?
    @EnvironmentObject private var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var systemColorScheme

    private enum RepoFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case pinned = "Pinned"
        case work = "Work"

        var id: String { rawValue }
    }

    private let repos: [RepoItem] = [
        RepoItem(
            id: "tarikvillalobos/postme",
            name: "tarikvillalobos/postme",
            issues: 2,
            prs: 1,
            stars: 124,
            branch: "main",
            updatedAgo: "1 min. ago",
            isPinned: true,
            isWork: false,
            releases: 12,
            ciRuns: 1232,
            discussions: 0,
            tags: 13,
            branches: 1,
            contributors: 3,
            openCommits: 24
        ),
        RepoItem(
            id: "tarikvillalobos/rentify",
            name: "tarikvillalobos/rentify",
            issues: 4,
            prs: 5,
            stars: 892,
            branch: "main",
            updatedAgo: "14 min. ago",
            isPinned: true,
            isWork: true,
            releases: 9,
            ciRuns: 761,
            discussions: 3,
            tags: 18,
            branches: 4,
            contributors: 6,
            openCommits: 42
        ),
        RepoItem(
            id: "tarikvillalobos/time-zones",
            name: "tarikvillalobos/time-zones",
            issues: 1,
            prs: 0,
            stars: 340,
            branch: "dev",
            updatedAgo: "13 min. ago",
            isPinned: false,
            isWork: false,
            releases: 4,
            ciRuns: 188,
            discussions: 1,
            tags: 7,
            branches: 3,
            contributors: 2,
            openCommits: 11
        ),
        RepoItem(
            id: "tarikvillalobos/squaddy",
            name: "tarikvillalobos/squaddy",
            issues: 0,
            prs: 2,
            stars: 56,
            branch: "master",
            updatedAgo: "1 hr. ago",
            isPinned: false,
            isWork: true,
            releases: 2,
            ciRuns: 43,
            discussions: 0,
            tags: 3,
            branches: 2,
            contributors: 2,
            openCommits: 7
        ),
        RepoItem(
            id: "tarikvillalobos/api-kit",
            name: "tarikvillalobos/api-kit",
            issues: 3,
            prs: 1,
            stars: 1205,
            branch: "feature/v2",
            updatedAgo: "30 min. ago",
            isPinned: true,
            isWork: true,
            releases: 21,
            ciRuns: 3011,
            discussions: 7,
            tags: 25,
            branches: 8,
            contributors: 11,
            openCommits: 63
        ),
        RepoItem(
            id: "tarikvillalobos/mnemonic",
            name: "tarikvillalobos/mnemonic",
            issues: 0,
            prs: 0,
            stars: 78,
            branch: "main",
            updatedAgo: "2 hr. ago",
            isPinned: false,
            isWork: false,
            releases: 1,
            ciRuns: 17,
            discussions: 0,
            tags: 1,
            branches: 1,
            contributors: 1,
            openCommits: 4
        ),
        RepoItem(
            id: "tarikvillalobos/open-tasks",
            name: "tarikvillalobos/open-tasks",
            issues: 5,
            prs: 3,
            stars: 412,
            branch: "main",
            updatedAgo: "4 min. ago",
            isPinned: true,
            isWork: true,
            releases: 14,
            ciRuns: 942,
            discussions: 5,
            tags: 16,
            branches: 5,
            contributors: 8,
            openCommits: 38
        )
    ]

    private var filteredRepos: [RepoItem] {
        switch selectedFilter {
        case .all:
            return repos
        case .pinned:
            return repos.filter { $0.isPinned }
        case .work:
            return repos.filter { $0.isWork }
        }
    }

    private var selectedRepo: RepoItem? {
        guard let selectedRepoID else { return nil }
        return filteredRepos.first { $0.id == selectedRepoID }
    }

    private var isDetailsVisible: Bool {
        selectedRepo != nil
    }

    // MARK: - Theme colors

    private var isDarkTheme: Bool {
        themeStore.resolvedColorScheme(systemColorScheme: systemColorScheme) == .dark
    }

    private var panelFillColor: Color {
        isDarkTheme ? Color(red: 0.12, green: 0.13, blue: 0.16) : Color(red: 0.97, green: 0.97, blue: 0.98)
    }

    private var panelStrokeColor: Color {
        isDarkTheme ? .white.opacity(0.14) : .black.opacity(0.08)
    }

    private var cardFillColor: Color {
        isDarkTheme ? Color(red: 0.16, green: 0.17, blue: 0.20) : .white
    }

    private var cardStrokeColor: Color {
        isDarkTheme ? .white.opacity(0.10) : .black.opacity(0.08)
    }

    private var primaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.90) : .black.opacity(0.82)
    }

    private var secondaryTextColor: Color {
        isDarkTheme ? .white.opacity(0.55) : .black.opacity(0.48)
    }

    private var dividerColor: Color {
        isDarkTheme ? .white.opacity(0.10) : .black.opacity(0.07)
    }

    private var accentColor: Color {
        Color(red: 0.39, green: 0.44, blue: 0.99)
    }

    private var actionCardFillColor: Color {
        isDarkTheme ? Color(red: 0.18, green: 0.19, blue: 0.23) : .white
    }

    private var actionCardStrokeColor: Color {
        isDarkTheme ? .white.opacity(0.13) : .black.opacity(0.10)
    }

    // MARK: - Dynamic Size

    private var repoListHeight: CGFloat {
        let rowHeight: CGFloat = 72
        let count = CGFloat(min(filteredRepos.count, 5))
        return count * rowHeight
    }

    private var basePanelHeight: CGFloat {
        // header + heatmap + filters + list + footer + vertical paddings
        56 + 158 + 44 + repoListHeight + 46 + 40
    }

    private var panelHeight: CGFloat {
        isDetailsVisible ? max(basePanelHeight, expandedPanelHeight) : basePanelHeight
    }

    private var panelWidth: CGFloat {
        if isDetailsVisible {
            return collapsedContentWidth + 16 + 1 + expandedRightColumnWidth + horizontalContentPadding
        }
        return collapsedPanelWidth
    }

    private var horizontalContentPadding: CGFloat {
        (18 + panelHorizontalInset) * 2
    }

    private var collapsedContentWidth: CGFloat {
        collapsedPanelWidth - horizontalContentPadding
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .fill(panelFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .strokeBorder(panelStrokeColor, lineWidth: 1)
                )
                .padding(.horizontal, panelHorizontalInset)
                .padding(.vertical, panelVerticalInset)

            HStack(alignment: .top, spacing: 16) {
                leftColumn
                    .frame(width: collapsedContentWidth)

                if let selectedRepo {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(width: 1)
                        .padding(.vertical, 8)

                    detailsColumn(for: selectedRepo)
                        .frame(width: expandedRightColumnWidth)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 20)
            .padding(.bottom, 14)
            .padding(.horizontal, panelHorizontalInset)
            .padding(.vertical, panelVerticalInset)
            .overlay(alignment: .top) {
                RepoWindowDragRegion()
                    .frame(maxWidth: .infinity)
                    .frame(height: 12)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: isDetailsVisible)
        .frame(width: panelWidth, height: panelHeight)
        .padding(.horizontal, windowEdgePaddingX)
        .padding(.vertical, windowEdgePaddingY)
        .background(
            RepoWindowConfigurator(
                targetSize: CGSize(
                    width: panelWidth + (windowEdgePaddingX * 2),
                    height: panelHeight + (windowEdgePaddingY * 2)
                )
            ) { window in
                if hostWindow !== window {
                    hostWindow = window
                }
            }
        )
        .onChange(of: selectedFilter, initial: false) { _, _ in
            synchronizeSelectedRepo()
        }
    }

    // MARK: - Left Column

    private var leftColumn: some View {
        VStack(spacing: 0) {
            header
                .padding(.bottom, 14)

            heatmapSection
                .padding(.bottom, 14)

            filterTabs
                .padding(.bottom, 10)

            repoList

            Spacer(minLength: 0)

            footerBar
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center) {
            HStack(spacing: 0) {
                Text("Contributions")
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .frame(height: 36, alignment: .center)

                Spacer()
            }
            .frame(height: 36)
            .background(RepoWindowDragRegion())

            Button(action: closeWindow) {
                RepoHeaderIcon(symbol: "xmark", isDarkTheme: isDarkTheme)
            }
            .buttonStyle(.plain)
            .repoCursorOnHover()
        }
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ContributionHeatmap(isDarkTheme: isDarkTheme)
                .frame(maxWidth: .infinity)
                .frame(height: 116)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    // MARK: - Filter Tabs

    private var filterTabs: some View {
        HStack(spacing: 6) {
            ForEach(RepoFilter.allCases) { filter in
                filterTab(filter)
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    private func filterTab(_ filter: RepoFilter) -> some View {
        let isActive = selectedFilter == filter
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                selectedFilter = filter
            }
        } label: {
            Text(filter.rawValue)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(isActive ? primaryTextColor : secondaryTextColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isActive ? accentColor.opacity(isDarkTheme ? 0.28 : 0.14) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(
                                    isActive ? accentColor.opacity(0.40) : Color.clear,
                                    lineWidth: 1
                                )
                        )
                )
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    // MARK: - Repo List

    private var repoList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredRepos.enumerated()), id: \.element.id) { index, repo in
                    RepoRow(
                        repo: repo,
                        isDarkTheme: isDarkTheme,
                        primaryColor: primaryTextColor,
                        secondaryColor: secondaryTextColor,
                        accentColor: accentColor,
                        dividerColor: dividerColor,
                        isSelected: selectedRepoID == repo.id,
                        showDivider: index < filteredRepos.count - 1
                    ) {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedRepoID = repo.id
                        }
                    }
                }
            }
        }
        .frame(height: repoListHeight)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    // MARK: - Footer

    private var footerBar: some View {
        VStack(spacing: 10) {
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            HStack {
                Text("\(filteredRepos.count) repositories")
                Spacer()
                Text("GitHub")
            }
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(secondaryTextColor)
        }
    }

    // MARK: - Details Column

    private func detailsColumn(for repo: RepoItem) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 12) {
                detailActionSection(for: repo)

                branchStatusSection(for: repo)

                detailNavigationRow(icon: "arrow.left.arrow.right", title: "Switch Worktree") {}

                metricsSection(for: repo)
            }
            .padding(.top, 4)
            .padding(.bottom, 4)
        }
    }

    private func detailActionSection(for repo: RepoItem) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            detailNavigationRow(
                icon: "arrow.up.right.square",
                title: "Open \(repo.name) in GitHub"
            ) {
                openRepositoryOnGitHub(repo)
            }

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            detailNavigationRow(icon: "folder", title: "Open in Finder") {}
            detailNavigationRow(icon: "terminal", title: "Open in Terminal") {}
            detailNavigationRow(icon: "wand.and.stars", title: "Open TARS Agent", isAccent: true) {}
        }
    }

    private func branchStatusSection(for repo: RepoItem) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryTextColor)

                Text(repo.branch)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)

                Text("Up to date")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
            }

            Text("Upstream origin/\(repo.branch) - Fetched 1 min. ago")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryTextColor)

            HStack(spacing: 12) {
                secondaryPillButton(icon: "arrow.clockwise", title: "Sync") {}
                secondaryPillButton(icon: "arrow.triangle.branch", title: "Rebase") {}
                secondaryPillButton(icon: "arrow.uturn.backward", title: "Reset") {}
            }
        }
    }

    private func metricsSection(for repo: RepoItem) -> some View {
        let metrics = [
            RepoMetric(id: "issues", icon: "exclamationmark.circle", title: "Issues", value: repo.issues),
            RepoMetric(id: "prs", icon: "arrow.triangle.pull", title: "Pull Requests", value: repo.prs),
            RepoMetric(id: "releases", icon: "shippingbox", title: "Releases", value: repo.releases),
            RepoMetric(id: "ci", icon: "bolt", title: "CI Runs", value: repo.ciRuns),
            RepoMetric(id: "discussions", icon: "bubble.left", title: "Discussions", value: repo.discussions),
            RepoMetric(id: "tags", icon: "tag", title: "Tags", value: repo.tags),
            RepoMetric(id: "branches", icon: "arrow.triangle.branch", title: "Branches", value: repo.branches),
            RepoMetric(id: "contributors", icon: "person.2", title: "Contributors", value: repo.contributors),
            RepoMetric(id: "commits", icon: "clock.arrow.circlepath", title: "Open Commits", value: repo.openCommits)
        ]

        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)
                .padding(.bottom, 6)

            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                HStack(spacing: 10) {
                    Image(systemName: metric.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(secondaryTextColor)
                        .frame(width: 18, alignment: .center)

                    Text(metric.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)
                        .lineLimit(1)

                    Spacer()

                    if let value = metric.value {
                        Text(formatBadgeValue(value))
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(actionCardFillColor)
                                    .overlay(
                                        Capsule()
                                            .stroke(actionCardStrokeColor, lineWidth: 1)
                                    )
                            )
                    }
                }
                .padding(.vertical, 7)

                if index < metrics.count - 1 {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }
            }
        }
    }

    private func detailNavigationRow(
        icon: String,
        title: String,
        isAccent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isAccent ? accentColor : secondaryTextColor)
                    .frame(width: 20, alignment: .center)

                Text(title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(isAccent ? accentColor : primaryTextColor)
                    .lineLimit(1)

                Spacer(minLength: 10)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
            }
            .padding(.vertical, 1)
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    private func secondaryPillButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                Text(title)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(primaryTextColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(actionCardFillColor)
                    .overlay(
                        Capsule()
                            .stroke(actionCardStrokeColor, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    // MARK: - Actions

    private func closeWindow() {
        hostWindow?.close()
    }

    private func synchronizeSelectedRepo() {
        guard let selectedRepoID else { return }
        if !filteredRepos.contains(where: { $0.id == selectedRepoID }) {
            withAnimation(.easeInOut(duration: 0.18)) {
                self.selectedRepoID = nil
            }
        }
    }

    private func openRepositoryOnGitHub(_ repo: RepoItem) {
        guard let repositoryURL = URL(string: "https://github.com/\(repo.name)") else { return }
        NSWorkspace.shared.open(repositoryURL)
    }

    private func formatBadgeValue(_ value: Int) -> String {
        if value >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        }
        return "\(value)"
    }
}

// MARK: - Contribution Heatmap

private struct ContributionHeatmap: View {
    var isDarkTheme: Bool

    static let weeks = 28
    static let days = 7
    static let dateRange: (start: Date, end: Date) = {
        let calendar = Calendar(identifier: .gregorian)
        let today = calendar.startOfDay(for: Date())
        let weekday = calendar.component(.weekday, from: today)
        let daysSinceSunday = weekday - 1
        let thisWeekStart = calendar.date(byAdding: .day, value: -daysSinceSunday, to: today) ?? today
        let firstWeekStart = calendar.date(byAdding: .day, value: -((weeks - 1) * 7), to: thisWeekStart) ?? thisWeekStart
        return (start: firstWeekStart, end: today)
    }()

    private let calendar = Calendar(identifier: .gregorian)

    private var weeks: Int { Self.weeks }
    private var days: Int { Self.days }
    private var firstDate: Date { Self.dateRange.start }
    private var lastDate: Date { Self.dateRange.end }
    private let monthFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM"
        return formatter
    }()

    private let lightPalette: [Color] = [
        Color(red: 0.92, green: 0.93, blue: 0.94),
        Color(red: 0.61, green: 0.91, blue: 0.66),
        Color(red: 0.25, green: 0.77, blue: 0.39),
        Color(red: 0.19, green: 0.63, blue: 0.31),
        Color(red: 0.13, green: 0.43, blue: 0.22)
    ]

    private let darkPalette: [Color] = [
        Color(red: 0.09, green: 0.11, blue: 0.13),
        Color(red: 0.05, green: 0.27, blue: 0.16),
        Color(red: 0.00, green: 0.43, blue: 0.20),
        Color(red: 0.15, green: 0.65, blue: 0.25),
        Color(red: 0.22, green: 0.83, blue: 0.33)
    ]

    private struct MonthMarker: Identifiable {
        let id: Int
        let week: Int
        let label: String
    }

    private func dateFor(week: Int, day: Int) -> Date {
        let offset = (week * 7) + day
        return calendar.date(byAdding: .day, value: offset, to: firstDate) ?? firstDate
    }

    private func contributionCount(for date: Date) -> Int {
        if date > lastDate {
            return 0
        }

        let weekday = calendar.component(.weekday, from: date)
        let month = calendar.component(.month, from: date)
        let weekOfYear = calendar.component(.weekOfYear, from: date)
        let ordinal = calendar.ordinality(of: .day, in: .era, for: date) ?? 0

        let weekdayWeight: [Double] = [0.45, 0.92, 1.0, 1.0, 0.95, 0.82, 0.52] // Sun...Sat
        let monthWeight: [Int: Double] = [
            1: 0.82, 2: 0.86, 3: 0.95, 4: 1.03, 5: 1.08, 6: 1.0,
            7: 0.92, 8: 0.88, 9: 1.0, 10: 1.06, 11: 0.98, 12: 0.84
        ]

        var seed = UInt64(truncatingIfNeeded: (ordinal * 110_351_524 + weekOfYear * 97) &+ 12_345)
        func randomUnit() -> Double {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            return Double((seed >> 33) % 1000) / 1000.0
        }

        let weekdayIndex = max(0, min(6, weekday - 1))
        let base = weekdayWeight[weekdayIndex] * (monthWeight[month] ?? 1.0)
        var activity = base * (0.48 + randomUnit() * 0.82)

        if weekOfYear % 7 == 3 {
            activity += 0.28
        }
        if weekOfYear % 11 == 6 {
            activity += 0.38
        }

        if randomUnit() < 0.34 {
            return 0
        }

        var count = Int((activity * 9.0).rounded())

        if randomUnit() > 0.93 {
            count += Int(6 + randomUnit() * 12)
        }

        return max(0, min(count, 24))
    }

    private func level(for count: Int) -> Int {
        switch count {
        case 0:
            return 0
        case 1...2:
            return 1
        case 3...5:
            return 2
        case 6...9:
            return 3
        default:
            return 4
        }
    }

    private func cellColor(level: Int) -> Color {
        let palette = isDarkTheme ? darkPalette : lightPalette
        let safeIndex = max(0, min(palette.count - 1, level))
        return palette[safeIndex]
    }

    private var monthMarkers: [MonthMarker] {
        var markers: [MonthMarker] = []
        var previousMonth: Int?
        var lastWeekPlaced = -10

        for week in 0..<weeks {
            let date = dateFor(week: week, day: 0)
            let month = calendar.component(.month, from: date)
            if month != previousMonth {
                if week - lastWeekPlaced >= 4 {
                    markers.append(
                        MonthMarker(
                            id: week,
                            week: week,
                            label: monthFormatter.string(from: date)
                        )
                    )
                    lastWeekPlaced = week
                }
                previousMonth = month
            }
        }

        return markers
    }

    private func squareCellSize(for size: CGSize, gap: CGFloat) -> CGFloat {
        let widthBased = (size.width - CGFloat(weeks - 1) * gap) / CGFloat(weeks)
        let heightBased = (size.height - CGFloat(days - 1) * gap) / CGFloat(days)
        return max(0, min(widthBased, heightBased))
    }

    private func offsetX(forWeek week: Int, size: CGSize, gap: CGFloat) -> CGFloat {
        let cellSize = squareCellSize(for: size, gap: gap)
        let proposed = CGFloat(week) * (cellSize + gap)
        return min(max(0, proposed), max(0, size.width - 22))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                let monthGap: CGFloat = 2
                ZStack(alignment: .leading) {
                    ForEach(monthMarkers) { marker in
                        Text(marker.label)
                            .font(.system(size: 10, weight: .medium, design: .rounded))
                            .foregroundStyle(isDarkTheme ? .white.opacity(0.56) : .black.opacity(0.48))
                            .offset(x: offsetX(forWeek: marker.week, size: geometry.size, gap: monthGap))
                    }
                }
            }
            .frame(height: 13)

            GeometryReader { geometry in
                let gap: CGFloat = 2
                let cellSize = squareCellSize(for: geometry.size, gap: gap)
                let gridWidth = (cellSize * CGFloat(weeks)) + (CGFloat(weeks - 1) * gap)
                let gridHeight = (cellSize * CGFloat(days)) + (CGFloat(days - 1) * gap)
                let originX: CGFloat = 0
                let originY = max(0, (geometry.size.height - gridHeight) / 2)

                Canvas { context, _ in
                    for week in 0..<weeks {
                        for day in 0..<days {
                            let date = dateFor(week: week, day: day)
                            let count = contributionCount(for: date)
                            let color = cellColor(level: level(for: count))
                            let x = originX + CGFloat(week) * (cellSize + gap)
                            let y = originY + CGFloat(day) * (cellSize + gap)
                            let rect = CGRect(
                                x: x,
                                y: y,
                                width: cellSize,
                                height: cellSize
                            )
                            let path = Path(roundedRect: rect, cornerRadius: 2)
                            context.fill(path, with: .color(color))
                        }
                    }
                }
                .frame(width: gridWidth, height: geometry.size.height, alignment: .leading)
            }
            .frame(height: 74)

            HStack(spacing: 6) {
                Spacer()

                Text("Less")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isDarkTheme ? .white.opacity(0.56) : .black.opacity(0.48))

                ForEach(0..<5, id: \.self) { level in
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(cellColor(level: level))
                        .frame(width: 12, height: 12)
                }

                Text("More")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isDarkTheme ? .white.opacity(0.56) : .black.opacity(0.48))
            }
        }
    }
}

// MARK: - Repo Row

private struct RepoRow: View {
    let repo: RepoItem
    var isDarkTheme: Bool
    var primaryColor: Color
    var secondaryColor: Color
    var accentColor: Color
    var dividerColor: Color
    var isSelected: Bool
    var showDivider: Bool
    var onTap: () -> Void

    @State private var isHovered = false

    private var rowFillColor: Color {
        if isSelected {
            return isDarkTheme
                ? accentColor.opacity(0.30)
                : accentColor.opacity(0.16)
        }
        if isHovered {
            return isDarkTheme
                ? Color.white.opacity(0.05)
                : Color.black.opacity(0.03)
        }
        return .clear
    }

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(repo.name)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(primaryColor)
                                .lineLimit(1)

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.right")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(isSelected ? primaryColor : secondaryColor)
                        }

                        HStack(spacing: 8) {
                            repoStat(icon: "exclamationmark.circle", value: "\(repo.issues) Issues")
                            repoStat(icon: "arrow.triangle.pull", value: "\(repo.prs) PRs")
                            repoStat(icon: "star", value: "\(starsFormatted(repo.stars)) Stars")
                        }

                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(secondaryColor)

                            Text(repo.branch)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(secondaryColor)

                            Spacer()

                            Text(repo.updatedAgo)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(secondaryColor)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(rowFillColor)

                if showDivider {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                        .padding(.horizontal, 12)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
            if hovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }

    private func repoStat(icon: String, value: String) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
            Text(value)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(secondaryColor)
    }

    private func starsFormatted(_ count: Int) -> String {
        count >= 1000 ? String(format: "%.1fk", Double(count) / 1000.0) : "\(count)"
    }
}

// MARK: - Header Icon

private struct RepoHeaderIcon: View {
    let symbol: String
    var isDarkTheme: Bool = false

    private var symbolColor: Color {
        isDarkTheme ? .white.opacity(0.62) : .black.opacity(0.56)
    }

    private var fillColor: Color {
        isDarkTheme ? Color(red: 0.20, green: 0.21, blue: 0.25) : .white
    }

    private var strokeColor: Color {
        isDarkTheme ? .white.opacity(0.14) : .black.opacity(0.10)
    }

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(symbolColor)
            .frame(width: 36, height: 36)
            .background(
                Circle()
                    .fill(fillColor)
                    .overlay(
                        Circle()
                            .stroke(strokeColor, lineWidth: 1)
                    )
            )
    }
}

// MARK: - Cursor modifier

private struct RepoCursorOnHover: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { isHovering in
            if isHovering {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private extension View {
    func repoCursorOnHover() -> some View {
        modifier(RepoCursorOnHover())
    }
}

// MARK: - Window Infrastructure

private struct RepoWindowDragRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        RepoDragView()
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class RepoDragView: NSView {
        override func resetCursorRects() {
            super.resetCursorRects()
            discardCursorRects()
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            NSCursor.closedHand.push()
            defer { NSCursor.pop() }
            window?.performDrag(with: event)
        }
    }
}

private struct RepoWindowConfigurator: NSViewRepresentable {
    let targetSize: CGSize
    let onResolve: (NSWindow) -> Void

    private static var patchedClasses: Set<ObjectIdentifier> = []

    init(targetSize: CGSize, onResolve: @escaping (NSWindow) -> Void) {
        self.targetSize = targetSize
        self.onResolve = onResolve
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            configure(window)
            onResolve(window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            guard let window = nsView.window else { return }
            let size = NSSize(width: targetSize.width, height: targetSize.height)
            if window.frame.size != size {
                window.setContentSize(size)
            }
        }
    }

    private func configure(_ window: NSWindow) {
        window.styleMask = [.borderless, .fullSizeContentView]
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        let size = NSSize(width: targetSize.width, height: targetSize.height)
        window.setContentSize(size)
        window.center()
        ensureKeyable(window)
    }

    private func ensureKeyable(_ window: NSWindow) {
        guard let windowClass = object_getClass(window) else { return }
        let classID = ObjectIdentifier(windowClass)
        guard !Self.patchedClasses.contains(classID) else { return }

        let canKey: @convention(block) (AnyObject) -> Bool = { _ in true }
        let canMain: @convention(block) (AnyObject) -> Bool = { _ in true }

        class_addMethod(
            windowClass,
            #selector(getter: NSWindow.canBecomeKey),
            imp_implementationWithBlock(canKey),
            "B@:"
        )
        class_addMethod(
            windowClass,
            #selector(getter: NSWindow.canBecomeMain),
            imp_implementationWithBlock(canMain),
            "B@:"
        )

        let canMove: @convention(block) (AnyObject) -> Bool = { _ in false }
        if let method = class_getInstanceMethod(windowClass, NSSelectorFromString("isMovable")) {
            method_setImplementation(method, imp_implementationWithBlock(canMove))
        }

        Self.patchedClasses.insert(classID)
    }
}
