import AppKit
import ObjectiveC.runtime
import SwiftUI

// MARK: - Main View

struct RepositoryPanelView: View {
    private let collapsedPanelWidth: CGFloat = 340
    private let expandedPanelHeight: CGFloat = 704
    private let expandedRightColumnWidth: CGFloat = 420

    private let panelHorizontalInset: CGFloat = 2
    private let panelVerticalInset: CGFloat = 6
    private let windowEdgePaddingX: CGFloat = 10
    private let windowEdgePaddingY: CGFloat = 12

    @ObservedObject var viewModel: RepositoryViewModel

    @State private var hostWindow: NSWindow?
    @State private var localActionAlertState: LocalActionAlertState?

    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var systemColorScheme

    private var filteredRepos: [RepoItem] { viewModel.filteredRepos }
    private var selectedRepo: RepoItem? { viewModel.selectedRepo }
    private var isDetailsVisible: Bool { viewModel.isDetailsVisible }
    private var selectedDetailDestination: RepoDetailDestination? { viewModel.selectedDetailDestination }

    private enum PendingLocalAction: String {
        case finder
        case terminal
    }

    private struct PendingCloneRequest: Identifiable {
        let repoID: String
        let repoName: String
        let expectedPath: String
        let action: PendingLocalAction

        var id: String {
            "\(repoID)-\(action.rawValue)"
        }
    }

    private struct LocalActionAlertState: Identifiable {
        enum Kind {
            case rootNotConfigured
            case cloneRequired(PendingCloneRequest)
            case failed(String)
        }

        let id = UUID()
        let kind: Kind
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
        if filteredRepos.isEmpty {
            return 150
        }

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
        .task {
            await viewModel.reloadRepositories()
        }
        .alert(item: $localActionAlertState) { alertState in
            switch alertState.kind {
            case .rootNotConfigured:
                return Alert(
                    title: Text("Local Repositories Folder Not Configured"),
                    message: Text("Configure a local repositories folder in Settings > GitHub to use this action."),
                    primaryButton: .default(Text("Open Settings")) {
                        openWindow(id: "settings")
                        NSApp.activate(ignoringOtherApps: true)
                    },
                    secondaryButton: .cancel()
                )
            case .cloneRequired(let request):
                return Alert(
                    title: Text("Repository not found locally"),
                    message: Text("Expected path:\n\(request.expectedPath)\n\nDo you want to clone this repository now?"),
                    primaryButton: .default(Text("Clone")) {
                        cloneMissingRepository(request)
                    },
                    secondaryButton: .cancel()
                )
            case .failed(let message):
                return Alert(
                    title: Text("Action failed"),
                    message: Text(message),
                    dismissButton: .default(Text("OK"))
                )
            }
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
        let isActive = viewModel.selectedFilter == filter
        return Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                viewModel.selectFilter(filter)
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
        Group {
            if viewModel.isLoadingRepositories && filteredRepos.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)

                    Text("Loading repositories...")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
            } else if filteredRepos.isEmpty {
                VStack(spacing: 8) {
                    Text(viewModel.repositoryLoadErrorMessage ?? "No repositories found.")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 12)
            } else {
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
                                isPinned: viewModel.isRepoPinned(repo),
                                isSelected: viewModel.selectedRepoID == repo.id,
                                showDivider: index < filteredRepos.count - 1
                            ) {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    viewModel.selectRepository(repo)
                                }
                            } onTogglePinned: {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    viewModel.togglePinned(repo)
                                }
                            }
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
        ZStack(alignment: .topLeading) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 12) {
                    detailActionSection(for: repo)

                    branchStatusSection(for: repo)

                    detailNavigationRow(icon: "arrow.left.arrow.right", title: "Switch Worktree") {
                        openDetailPanel(.switchWorktree)
                    }

                    metricsSection(for: repo)
                }
                .padding(.top, 4)
                .padding(.bottom, 4)
            }
            .allowsHitTesting(selectedDetailDestination == nil)

            if let destination = selectedDetailDestination {
                detailOverlayPanel(for: repo, destination: destination)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: selectedDetailDestination)
    }

    private func detailActionSection(for repo: RepoItem) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            detailRepoHeaderRow(for: repo)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            detailNavigationRow(icon: "arrow.up.right.square", title: "Open in GitHub") {
                openRepositoryOnGitHub(repo)
            }
            detailNavigationRow(icon: "folder", title: "Open in Finder") {
                handleLocalAction(for: repo, action: .finder)
            }
            detailNavigationRow(icon: "terminal", title: "Open in Terminal") {
                handleLocalAction(for: repo, action: .terminal)
            }
            detailNavigationRow(icon: "wand.and.stars", title: "Open TARS Agent", isAccent: true) {}
        }
    }

    private func detailRepoHeaderRow(for repo: RepoItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "shippingbox")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(secondaryTextColor)
                .frame(width: 20, alignment: .center)

            Text(repo.name)
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)

            Spacer(minLength: 10)

            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    viewModel.closeRepositorySelection()
                }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .repoCursorOnHover()
        }
        .padding(.vertical, 1)
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
            RepoMetric(id: "issues", icon: "exclamationmark.circle", title: "Issues", value: repo.issues, destination: .issues),
            RepoMetric(id: "prs", icon: "arrow.triangle.pull", title: "Pull Requests", value: repo.prs, destination: .pullRequests),
            RepoMetric(id: "releases", icon: "shippingbox", title: "Releases", value: repo.releases, destination: .releases),
            RepoMetric(id: "ci", icon: "bolt", title: "CI Runs", value: repo.ciRuns, destination: .ciRuns),
            RepoMetric(id: "discussions", icon: "bubble.left", title: "Discussions", value: repo.discussions, destination: .discussions),
            RepoMetric(id: "tags", icon: "tag", title: "Tags", value: repo.tags, destination: .tags),
            RepoMetric(id: "branches", icon: "arrow.triangle.branch", title: "Branches", value: repo.branches, destination: .branches),
            RepoMetric(id: "contributors", icon: "person.2", title: "Contributors", value: repo.contributors, destination: .contributors),
            RepoMetric(id: "commits", icon: "clock.arrow.circlepath", title: "Open Commits", value: repo.openCommits, destination: .openCommits)
        ]

        return VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)
                .padding(.bottom, 6)

            ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                Button {
                    openDetailPanel(metric.destination)
                } label: {
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
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .repoCursorOnHover()

                if index < metrics.count - 1 {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }
            }
        }
    }

    @ViewBuilder
    private func detailOverlayPanel(for repo: RepoItem, destination: RepoDetailDestination) -> some View {
        switch destination {
        case .issues:
            issuesOverlayPanel(for: repo)
        default:
            genericDetailOverlayPanel(for: repo, destination: destination)
        }
    }

    private func issuesOverlayPanel(for repo: RepoItem) -> some View {
        let issues = viewModel.filteredIssues(for: repo)

        return VStack(spacing: 0) {
            overlayTopBar(title: "Open Issues")

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            HStack(spacing: 10) {
                ForEach(RepoIssuesScope.allCases) { scope in
                    issuesFilterPill(scope)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if issues.isEmpty {
                        Text("No issues for this filter.")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                    } else {
                        ForEach(Array(issues.enumerated()), id: \.element.id) { index, issue in
                            issueRow(issue, showDivider: index < issues.count - 1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    private func genericDetailOverlayPanel(for repo: RepoItem, destination: RepoDetailDestination) -> some View {
        let entries = destination.mockEntries(repoName: repo.name, branch: repo.branch)

        return VStack(spacing: 0) {
            overlayTopBar(title: "Open \(destination.title)")

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    ForEach(Array(entries.enumerated()), id: \.offset) { index, entry in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(accentColor)
                                .frame(width: 6, height: 6)

                            Text(entry)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(primaryTextColor)
                                .lineLimit(1)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(secondaryTextColor)
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)

                        if index < entries.count - 1 {
                            Rectangle()
                                .fill(dividerColor)
                                .frame(height: 1)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    private func overlayTopBar(title: String) -> some View {
        HStack(spacing: 10) {
            Button(action: closeDetailPanel) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(secondaryTextColor)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(actionCardFillColor)
                            .overlay(
                                Circle()
                                    .stroke(actionCardStrokeColor, lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)
            .repoCursorOnHover()

            Text(title)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(primaryTextColor)
                .lineLimit(1)

            Spacer()

            overlayHeaderIconButton(symbol: "line.3.horizontal.decrease")
            overlayHeaderIconButton(symbol: "arrow.clockwise")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func overlayHeaderIconButton(symbol: String) -> some View {
        Button {} label: {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(secondaryTextColor)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(actionCardFillColor)
                        .overlay(
                            Circle()
                                .stroke(actionCardStrokeColor, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    private func issuesFilterPill(_ scope: RepoIssuesScope) -> some View {
        let isActive = viewModel.selectedIssuesScope == scope

        return Button {
            withAnimation(.easeInOut(duration: 0.14)) {
                viewModel.selectIssuesScope(scope)
            }
        } label: {
            Text(scope.rawValue)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(isActive ? .white : secondaryTextColor)
                .padding(.horizontal, 13)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(isActive ? accentColor : .clear)
                        .overlay(
                            Capsule()
                                .stroke(isActive ? accentColor.opacity(0.65) : actionCardStrokeColor, lineWidth: 1)
                        )
                )
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    private func issueRow(_ issue: RepoIssueItem, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: issue.isOpen ? "exclamationmark.circle" : "checkmark.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 18, alignment: .center)

                    Text(issue.title)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    if issue.comments > 0 {
                        HStack(spacing: 4) {
                            Image(systemName: "bubble.left")
                                .font(.system(size: 11, weight: .medium))
                            Text("\(issue.comments)")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(secondaryTextColor)
                    }
                }

                HStack(spacing: 8) {
                    ForEach(issue.labels) { label in
                        issueLabelPill(label)
                    }
                }

                Text("#\(issue.number) \(issue.author) \(issue.updatedAgo)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)

            if showDivider {
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
            }
        }
    }

    private func issueLabelPill(_ label: RepoIssueLabel) -> some View {
        Text(label.title)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(issueLabelTextColor(label.kind))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(issueLabelBackgroundColor(label.kind))
            )
    }

    private func issueLabelBackgroundColor(_ kind: RepoIssueLabelKind) -> Color {
        switch kind {
        case .bug:
            return isDarkTheme ? Color.red.opacity(0.20) : Color.red.opacity(0.17)
        case .enhancement:
            return isDarkTheme ? Color.blue.opacity(0.23) : Color.blue.opacity(0.18)
        case .helpWanted:
            return isDarkTheme ? Color.green.opacity(0.20) : Color.green.opacity(0.16)
        case .goodFirstIssue:
            return isDarkTheme ? Color.purple.opacity(0.20) : Color.purple.opacity(0.16)
        }
    }

    private func issueLabelTextColor(_ kind: RepoIssueLabelKind) -> Color {
        switch kind {
        case .bug:
            return isDarkTheme ? Color(red: 1.0, green: 0.74, blue: 0.74) : Color(red: 0.79, green: 0.21, blue: 0.21)
        case .enhancement:
            return isDarkTheme ? Color(red: 0.72, green: 0.84, blue: 1.0) : Color(red: 0.19, green: 0.45, blue: 0.89)
        case .helpWanted:
            return isDarkTheme ? Color(red: 0.72, green: 0.92, blue: 0.74) : Color(red: 0.15, green: 0.55, blue: 0.20)
        case .goodFirstIssue:
            return isDarkTheme ? Color(red: 0.87, green: 0.79, blue: 1.0) : Color(red: 0.50, green: 0.30, blue: 0.78)
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

    private func openDetailPanel(_ destination: RepoDetailDestination) {
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.openDetailPanel(destination)
        }
    }

    private func closeDetailPanel() {
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.closeDetailPanel()
        }
    }

    private func openRepositoryOnGitHub(_ repo: RepoItem) {
        guard let repositoryURL = URL(string: "https://github.com/\(repo.name)") else { return }
        NSWorkspace.shared.open(repositoryURL)
    }

    private func handleLocalAction(for repo: RepoItem, action: PendingLocalAction) {
        let result: RepositoryLocalActionResult

        switch action {
        case .finder:
            result = viewModel.openInFinder(for: repo)
        case .terminal:
            result = viewModel.openInTerminal(for: repo)
        }

        handleLocalActionResult(result, for: repo, action: action)
    }

    private func handleLocalActionResult(
        _ result: RepositoryLocalActionResult,
        for repo: RepoItem,
        action: PendingLocalAction
    ) {
        switch result {
        case .opened:
            return
        case .cloned:
            handleLocalAction(for: repo, action: action)
        case .rootNotConfigured:
            localActionAlertState = LocalActionAlertState(kind: .rootNotConfigured)
        case .cloneRequired(let expectedPath):
            localActionAlertState = LocalActionAlertState(
                kind: .cloneRequired(
                    PendingCloneRequest(
                        repoID: repo.id,
                        repoName: repo.name,
                        expectedPath: expectedPath,
                        action: action
                    )
                )
            )
        case .failed(let message):
            localActionAlertState = LocalActionAlertState(kind: .failed(message))
        }
    }

    private func cloneMissingRepository(_ request: PendingCloneRequest) {
        Task {
            guard let repo = viewModel.repository(withID: request.repoID) else {
                return
            }

            let result = await viewModel.cloneLocalRepository(for: repo)
            handleLocalActionResult(result, for: repo, action: request.action)
        }
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

    private func squareCellSize(for size: CGSize, gap: CGFloat) -> CGFloat {
        let widthBased = (size.width - CGFloat(weeks - 1) * gap) / CGFloat(weeks)
        let heightBased = (size.height - CGFloat(days - 1) * gap) / CGFloat(days)
        return max(0, min(widthBased, heightBased))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Spacer()
                Text("last 12 months")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(isDarkTheme ? .white.opacity(0.56) : .black.opacity(0.48))
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
    var isPinned: Bool
    var isSelected: Bool
    var showDivider: Bool
    var onTap: () -> Void
    var onTogglePinned: () -> Void

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
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 8) {
                Button(action: onTap) {
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

                            repoVisibilityTag()

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
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .repoCursorOnHover()

                Button(action: onTogglePinned) {
                    Image(systemName: isPinned ? "pin.fill" : "pin")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isPinned ? accentColor : secondaryColor)
                        .frame(width: 24, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                .fill(
                                    isPinned
                                        ? accentColor.opacity(isDarkTheme ? 0.20 : 0.14)
                                        : Color.clear
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                                        .stroke(
                                            isPinned
                                                ? accentColor.opacity(0.45)
                                                : Color.clear,
                                            lineWidth: 1
                                        )
                                )
                        )
                }
                .buttonStyle(.plain)
                .repoCursorOnHover()
                .accessibilityLabel(isPinned ? "Unpin repository" : "Pin repository")
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

    private func repoVisibilityTag() -> some View {
        HStack(spacing: 5) {
            Image(systemName: repo.visibility.icon)
                .font(.system(size: 9, weight: .semibold))
            Text(repo.visibility.label)
                .font(.system(size: 10, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(secondaryColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(
                    isDarkTheme
                        ? Color.white.opacity(0.06)
                        : Color.black.opacity(0.05)
                )
        )
        .overlay(
            Capsule()
                .stroke(
                    isDarkTheme
                        ? Color.white.opacity(0.10)
                        : Color.black.opacity(0.08),
                    lineWidth: 1
                )
        )
        .frame(maxWidth: .infinity, alignment: .leading)
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
