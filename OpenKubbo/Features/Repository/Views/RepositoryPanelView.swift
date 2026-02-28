import AppKit
import ObjectiveC.runtime
import SwiftUI

// MARK: - Main View

struct RepositoryPanelView: View {
    private let collapsedPanelWidth: CGFloat = 340
    private let expandedPanelHeight: CGFloat = 704
    private let expandedRightColumnWidth: CGFloat = 420
    private let isAppUpdateEnabled = false

    private let panelHorizontalInset: CGFloat = 2
    private let panelVerticalInset: CGFloat = 6
    private let windowEdgePaddingX: CGFloat = 10
    private let windowEdgePaddingY: CGFloat = 12

    @ObservedObject var viewModel: RepositoryViewModel

    @State private var hostWindow: NSWindow?
    @State private var localActionAlertState: LocalActionAlertState?
    @State private var newWorktreeBranchName = ""

    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var themeStore: AppThemeStore
    @Environment(\.colorScheme) private var systemColorScheme

    private var filteredRepos: [RepoItem] { viewModel.filteredRepos }
    private var selectedRepo: RepoItem? { viewModel.selectedRepo }
    private var isDetailsVisible: Bool { viewModel.isDetailsVisible }
    private var selectedDetailDestination: RepoDetailDestination? { viewModel.selectedDetailDestination }

    private enum PendingLocalAction {
        case finder
        case terminal
        case checkout(branchName: String)
        case terminalOnBranch(branchName: String)

        var key: String {
            switch self {
            case .finder:
                return "finder"
            case .terminal:
                return "terminal"
            case .checkout(let branchName):
                return "checkout-\(Self.sanitized(branchName))"
            case .terminalOnBranch(let branchName):
                return "terminal-\(Self.sanitized(branchName))"
            }
        }

        private static func sanitized(_ value: String) -> String {
            let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
            let mappedScalars = value.unicodeScalars.map { scalar in
                allowed.contains(scalar) ? Character(scalar) : "-"
            }
            return String(mappedScalars)
                .replacingOccurrences(of: "-+", with: "-", options: .regularExpression)
                .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        }
    }

    private struct PendingCloneRequest: Identifiable {
        let repoID: String
        let repoName: String
        let expectedPath: String
        let action: PendingLocalAction

        var id: String {
            "\(repoID)-\(action.key)"
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
            await viewModel.reloadPanelData()
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

            HStack(spacing: 8) {
                Button(action: openSettingsWindow) {
                    RepoHeaderIcon(symbol: "gearshape", isDarkTheme: isDarkTheme)
                }
                .buttonStyle(.plain)
                .repoCursorOnHover()

                Button(action: refreshPrimaryPanel) {
                    RepoHeaderIcon(
                        symbol: viewModel.isPrimaryPanelRefreshing ? "arrow.triangle.2.circlepath.circle.fill" : "arrow.clockwise",
                        isDarkTheme: isDarkTheme
                    )
                }
                .buttonStyle(.plain)
                .repoCursorOnHover()
                .disabled(viewModel.isPrimaryPanelRefreshing)

                Button(action: closeWindow) {
                    RepoHeaderIcon(symbol: "xmark", isDarkTheme: isDarkTheme)
                }
                .buttonStyle(.plain)
                .repoCursorOnHover()
            }
        }
    }

    // MARK: - Heatmap

    private var heatmapSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            ContributionHeatmap(
                isDarkTheme: isDarkTheme,
                contributionCountsByDateKey: viewModel.contributionCountsByDateKey,
                totalContributions: viewModel.totalContributionsLast12Months
            )
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
        let localCurrentBranch = viewModel.localCurrentBranch(for: repo)
        let displayedBranch = localCurrentBranch ?? repo.branch

        return VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            HStack(spacing: 8) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(primaryTextColor)

                Text(displayedBranch)
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)

                Text("Up to date")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
            }

            Text("Upstream origin/\(repo.branch) - Fetched 1 min. ago")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryTextColor)

            if let localCurrentBranch {
                Text("Current local branch: \(localCurrentBranch)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
            }

        }
    }

    private func metricsSection(for repo: RepoItem) -> some View {
        let metrics = [
            RepoMetric(id: "prs", icon: "arrow.triangle.pull", title: "Pull Requests", value: repo.prs, destination: .pullRequests),
            RepoMetric(id: "ci", icon: "bolt", title: "CI Runs", value: repo.ciRuns, destination: .ciRuns),
            RepoMetric(id: "issues", icon: "exclamationmark.circle", title: "Issues", value: repo.issues, destination: .issues),
            RepoMetric(id: "commits", icon: "clock.arrow.circlepath", title: "Open Commits", value: repo.openCommits, destination: .openCommits),
            RepoMetric(id: "branches", icon: "arrow.triangle.branch", title: "Branches", value: repo.branches, destination: .branches),
            RepoMetric(id: "tags", icon: "tag", title: "Tags", value: repo.tags, destination: .tags),
            RepoMetric(id: "releases", icon: "shippingbox", title: "Releases", value: repo.releases, destination: .releases),
            RepoMetric(id: "discussions", icon: "bubble.left", title: "Discussions", value: repo.discussions, destination: .discussions),
            RepoMetric(id: "contributors", icon: "person.2", title: "Contributors", value: repo.contributors, destination: .contributors),
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
        case .switchWorktree:
            switchWorktreeOverlayPanel(for: repo)
        case .issues:
            issuesOverlayPanel(for: repo)
        case .pullRequests:
            pullRequestsOverlayPanel(for: repo)
        case .branches:
            branchesOverlayPanel(for: repo)
        case .releases,
                .ciRuns,
                .discussions,
                .tags,
                .contributors,
                .openCommits:
            destinationInfoOverlayPanel(for: repo, destination: destination)
        }
    }

    private func switchWorktreeOverlayPanel(for repo: RepoItem) -> some View {
        let worktrees = viewModel.worktrees(for: repo)
        let isLoadingWorktrees = viewModel.isLoadingWorktrees(for: repo)
        let worktreesLoadErrorMessage = viewModel.worktreesLoadErrorMessage(for: repo)
        let cloneRequiredPath = viewModel.worktreeCloneRequiredPath(for: repo)
        let worktreeActionErrorMessage = viewModel.worktreeActionErrorMessage(for: repo)
        let worktreeActionStatusMessage = viewModel.worktreeActionStatusMessage(for: repo)
        let isCreatingWorktree = viewModel.isCreatingWorktree(for: repo)
        let canCreateWorktree = !trimmedNewWorktreeBranchName.isEmpty && !isCreatingWorktree

        return VStack(spacing: 0) {
            overlayTopBar(
                title: "Switch Worktree",
                onRefresh: {
                    Task {
                        await viewModel.reloadWorktrees(for: repo)
                    }
                }
            )

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            if let worktreeActionStatusMessage {
                issueFeedbackBanner(worktreeActionStatusMessage, isError: false)
            } else if let worktreeActionErrorMessage {
                issueFeedbackBanner(worktreeActionErrorMessage, isError: true)
            }

            VStack(alignment: .leading, spacing: 10) {
                if let activePath = viewModel.activeWorktreePath(for: repo) {
                    Text("Active: \(URL(fileURLWithPath: activePath).lastPathComponent)")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)
                }

                if let cloneRequiredPath {
                    Text("Clone required at \(cloneRequiredPath)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(2)
                        .truncationMode(.middle)
                }

                HStack(spacing: 8) {
                    secondaryPillButton(icon: "folder", title: "Open in Finder") {
                        handleLocalAction(for: repo, action: .finder)
                    }
                    secondaryPillButton(icon: "terminal", title: "Open in Terminal") {
                        handleLocalAction(for: repo, action: .terminal)
                    }
                }

                VStack(alignment: .leading, spacing: 7) {
                    Text("Create worktree")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)

                    HStack(spacing: 8) {
                        TextField("Branch name", text: $newWorktreeBranchName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(actionCardFillColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(actionCardStrokeColor, lineWidth: 1)
                                    )
                            )

                        Button {
                            Task {
                                let created = await viewModel.createWorktree(
                                    in: repo,
                                    branchName: trimmedNewWorktreeBranchName
                                )
                                if created {
                                    newWorktreeBranchName = ""
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                if isCreatingWorktree {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white.opacity(0.95))
                                } else {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Create")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                            }
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                Capsule()
                                    .fill(accentColor)
                                    .overlay(
                                        Capsule()
                                            .stroke(accentColor.opacity(0.6), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .repoCursorOnHover()
                        .disabled(!canCreateWorktree)
                        .opacity(canCreateWorktree ? 1 : 0.55)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if isLoadingWorktrees && worktrees.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading worktrees...")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                    } else if let worktreesLoadErrorMessage, worktrees.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(worktreesLoadErrorMessage)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.red.opacity(isDarkTheme ? 0.86 : 0.72))
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 12) {
                                Button("Retry") {
                                    Task {
                                        await viewModel.reloadWorktrees(for: repo)
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(accentColor)
                                .repoCursorOnHover()

                                if cloneRequiredPath != nil {
                                    Button("Clone Repository") {
                                        cloneRepositoryForWorktrees(repo)
                                    }
                                    .buttonStyle(.plain)
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .foregroundStyle(accentColor)
                                    .repoCursorOnHover()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                    } else if worktrees.isEmpty {
                        Text("No worktrees available.")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                    } else {
                        ForEach(Array(worktrees.enumerated()), id: \.element.id) { index, worktree in
                            worktreeRow(
                                worktree,
                                in: repo,
                                showDivider: index < worktrees.count - 1
                            )
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
        .task(id: "switch-worktree-\(repo.id)") {
            if trimmedNewWorktreeBranchName.isEmpty {
                newWorktreeBranchName = repo.branch
            }
            await viewModel.loadWorktreesIfNeeded(for: repo)
        }
    }

    private func issuesOverlayPanel(for repo: RepoItem) -> some View {
        let issues = viewModel.filteredIssues(for: repo)
        let selectedIssue = viewModel.selectedIssue(for: repo)
        let isComposerVisible = viewModel.isIssueComposerVisible
        let isLoadingIssues = viewModel.isLoadingIssues(for: repo)
        let issuesLoadErrorMessage = viewModel.issuesLoadErrorMessage(for: repo)

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                overlayTopBar(
                    title: "Open Issues",
                    onRefresh: {
                        Task {
                            await viewModel.reloadIssues(for: repo)
                        }
                    }
                )

                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)

                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(RepoIssuesScope.allCases) { scope in
                            issuesFilterPill(scope)
                        }
                    }

                    Spacer(minLength: 8)

                    newIssueButton
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if let statusMessage = viewModel.issueActionStatusMessage {
                    issueFeedbackBanner(statusMessage, isError: false)
                } else if let errorMessage = viewModel.issueActionErrorMessage {
                    issueFeedbackBanner(errorMessage, isError: true)
                }

                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        if isLoadingIssues && issues.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading issues...")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(secondaryTextColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                        } else if let issuesLoadErrorMessage, issues.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(issuesLoadErrorMessage)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.red.opacity(isDarkTheme ? 0.86 : 0.72))
                                    .fixedSize(horizontal: false, vertical: true)

                                Button("Retry") {
                                    Task {
                                        await viewModel.reloadIssues(for: repo)
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(accentColor)
                                .repoCursorOnHover()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                        } else if issues.isEmpty {
                            Text("No issues for this filter.")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                        } else {
                            ForEach(Array(issues.enumerated()), id: \.element.id) { index, issue in
                                issueRow(
                                    issue,
                                    in: repo,
                                    isSelected: selectedIssue?.id == issue.id,
                                    showDivider: index < issues.count - 1
                                )
                            }
                        }
                    }
                }
            }
            .allowsHitTesting(selectedIssue == nil && !isComposerVisible)

            if isComposerVisible {
                issueComposerOverlayPanel(for: repo)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if let selectedIssue {
                issueDetailsOverlayPanel(for: selectedIssue, in: repo)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(
            .easeInOut(duration: 0.18),
            value: "\(selectedIssue?.id ?? "none")-\(isComposerVisible ? "composer" : "list")"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
        .task(id: "issues-\(repo.id)") {
            await viewModel.loadIssuesIfNeeded(for: repo)
        }
    }

    private func issueComposerOverlayPanel(for repo: RepoItem) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: closeIssueComposer) {
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

                Text("Create Issue")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                TextField("Issue title", text: $viewModel.issueDraftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(actionCardFillColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(actionCardStrokeColor, lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                TextField("Issue description (optional)", text: $viewModel.issueDraftBody, axis: .vertical)
                    .lineLimit(5...10)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(actionCardFillColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(actionCardStrokeColor, lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Spacer(minLength: 0)

            HStack {
                Spacer(minLength: 0)

                Button(action: {
                    Task {
                        await createIssue(in: repo)
                    }
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isIssueCreating {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white.opacity(0.95))
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 11, weight: .bold))
                            Text("Create Issue")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(accentColor)
                            .overlay(
                                Capsule()
                                    .stroke(accentColor.opacity(0.6), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .repoCursorOnHover()
                .disabled(!viewModel.canCreateIssue || viewModel.isIssueCreating)
                .opacity((viewModel.canCreateIssue && !viewModel.isIssueCreating) ? 1 : 0.55)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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

    private func issueDetailsOverlayPanel(for issue: RepoIssueItem, in repo: RepoItem) -> some View {
        let isLoadingComments = viewModel.isLoadingIssueComments(for: issue)
        let isRefreshingIssue = viewModel.isRefreshingIssue(issue)
        let issueBranches = viewModel.issueBranches(for: issue, in: repo)
        let canCreateBranch = issue.isOpen && issueBranches.isEmpty
        let isBranchComposerVisible = canCreateBranch && viewModel.isIssueBranchComposerVisible

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: closeIssueDetails) {
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

                Text("Issue #\(issue.number)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)

                Spacer()

                if canCreateBranch {
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            viewModel.openIssueBranchComposer(for: issue, in: repo)
                        }
                    } label: {
                        Text("Create Branch")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                            .padding(.horizontal, 10)
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
                    .help("Create branch from this issue")
                    .disabled(viewModel.isIssueBranchCreating)
                    .opacity(viewModel.isIssueBranchCreating ? 0.7 : 1)
                }

                Button {
                    Task {
                        await viewModel.refreshIssue(issue, in: repo)
                    }
                } label: {
                    if isRefreshingIssue {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(actionCardFillColor)
                                    .overlay(
                                        Circle()
                                            .stroke(actionCardStrokeColor, lineWidth: 1)
                                    )
                            )
                    } else {
                        Image(systemName: "arrow.clockwise")
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
                }
                .buttonStyle(.plain)
                .repoCursorOnHover()
                .disabled(isRefreshingIssue)
                .opacity(isRefreshingIssue ? 0.7 : 1)

                Text(issue.isOpen ? "Open" : "Closed")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(issue.isOpen ? accentColor : secondaryTextColor.opacity(0.7))
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            if let statusMessage = viewModel.issueActionStatusMessage {
                issueFeedbackBanner(statusMessage, isError: false)

                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
            } else if let errorMessage = viewModel.issueActionErrorMessage {
                issueFeedbackBanner(errorMessage, isError: true)

                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
            }

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(issue.title)
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        ForEach(issue.labels) { label in
                            issueLabelPill(label)
                        }
                    }

                    Text("#\(issue.number) \(issue.author) \(issue.updatedAgo)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)

                    if !issueBranches.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(issueBranches.count == 1 ? "Linked branch" : "Linked branches")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(secondaryTextColor)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(issueBranches, id: \.self) { branchName in
                                        issueBranchTag(title: branchName)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    } else if isBranchComposerVisible {
                        Text("Branch name")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)

                        TextField("issue/\(issue.number)-short-description", text: $viewModel.issueBranchDraftName)
                            .textFieldStyle(.plain)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(primaryTextColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .fill(actionCardFillColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                                            .stroke(actionCardStrokeColor, lineWidth: 1)
                                    )
                            )

                        HStack(spacing: 8) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.18)) {
                                    viewModel.closeIssueBranchComposer()
                                }
                            } label: {
                                Text("Cancel")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(secondaryTextColor)
                                    .padding(.horizontal, 10)
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

                            Button {
                                Task {
                                    await createIssueBranch(from: issue, in: repo)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    if viewModel.isIssueBranchCreating {
                                        ProgressView()
                                            .controlSize(.small)
                                            .tint(.white.opacity(0.95))
                                    }
                                    Text(viewModel.isIssueBranchCreating ? "Creating..." : "Create Branch")
                                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                                }
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(accentColor)
                                        .overlay(
                                            Capsule()
                                                .stroke(accentColor.opacity(0.6), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                            .repoCursorOnHover()
                            .disabled(viewModel.isIssueBranchCreating)
                            .opacity(viewModel.isIssueBranchCreating ? 0.7 : 1)
                        }
                    }

                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)

                    Text(issue.body)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(primaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)

                    if issue.comments > 0 {
                        Rectangle()
                            .fill(dividerColor)
                            .frame(height: 1)

                        Text(issue.comments == 1 ? "1 comment" : "\(issue.comments) comments")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)

                        if isLoadingComments {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading comments...")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(secondaryTextColor)
                            }
                        } else if issue.commentItems.isEmpty {
                            Text("Comments are not available for this issue.")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(issue.commentItems.enumerated()), id: \.element.id) { index, comment in
                                    issueCommentRow(
                                        comment,
                                        showDivider: index < issue.commentItems.count - 1
                                    )
                                }
                            }
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(actionCardFillColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(actionCardStrokeColor, lineWidth: 1)
                                    )
                            )
                        }
                    }

                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)

                    Text("Add comment")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)

                    TextField("Write a comment...", text: $viewModel.issueCommentDraft, axis: .vertical)
                        .lineLimit(4...8)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(primaryTextColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(actionCardFillColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(actionCardStrokeColor, lineWidth: 1)
                                )
                        )

                    HStack {
                        Spacer(minLength: 0)

                        Button(action: {
                            Task {
                                await addIssueComment(in: repo)
                            }
                        }) {
                            HStack(spacing: 6) {
                                if viewModel.isIssueCommentSubmitting {
                                    ProgressView()
                                        .controlSize(.small)
                                        .tint(.white.opacity(0.95))
                                } else {
                                    Image(systemName: "paperplane.fill")
                                        .font(.system(size: 11, weight: .bold))
                                    Text("Add Comment")
                                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                                }
                            }
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(accentColor)
                                    .overlay(
                                        Capsule()
                                            .stroke(accentColor.opacity(0.6), lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                        .repoCursorOnHover()
                        .disabled(!viewModel.canSubmitIssueComment || viewModel.isIssueCommentSubmitting)
                        .opacity((viewModel.canSubmitIssueComment && !viewModel.isIssueCommentSubmitting) ? 1 : 0.55)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
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

    private func pullRequestsOverlayPanel(for repo: RepoItem) -> some View {
        let pullRequests = viewModel.filteredPullRequests(for: repo)
        let selectedPullRequest = viewModel.selectedPullRequest(for: repo)
        let isComposerVisible = viewModel.isPullRequestComposerVisible
        let isLoadingPullRequests = viewModel.isLoadingPullRequests(for: repo)
        let pullRequestsLoadErrorMessage = viewModel.pullRequestsLoadErrorMessage(for: repo)

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                overlayTopBar(
                    title: "Open Pull Requests",
                    onRefresh: {
                        Task {
                            await viewModel.reloadPullRequests(for: repo)
                        }
                    }
                )

                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)

                HStack(spacing: 10) {
                    HStack(spacing: 10) {
                        ForEach(RepoPullRequestsScope.allCases) { scope in
                            pullRequestsFilterPill(scope)
                        }
                    }

                    Spacer(minLength: 8)

                    newPullRequestButton(for: repo)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if let statusMessage = viewModel.pullRequestActionStatusMessage {
                    issueFeedbackBanner(statusMessage, isError: false)
                } else if let errorMessage = viewModel.pullRequestActionErrorMessage {
                    issueFeedbackBanner(errorMessage, isError: true)
                }

                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        if isLoadingPullRequests && pullRequests.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading pull requests...")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(secondaryTextColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                        } else if let pullRequestsLoadErrorMessage, pullRequests.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(pullRequestsLoadErrorMessage)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.red.opacity(isDarkTheme ? 0.86 : 0.72))
                                    .fixedSize(horizontal: false, vertical: true)

                                Button("Retry") {
                                    Task {
                                        await viewModel.reloadPullRequests(for: repo)
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(accentColor)
                                .repoCursorOnHover()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                        } else if pullRequests.isEmpty {
                            Text("No pull requests for this filter.")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                        } else {
                            ForEach(Array(pullRequests.enumerated()), id: \.element.id) { index, pullRequest in
                                pullRequestRow(
                                    pullRequest,
                                    in: repo,
                                    isSelected: selectedPullRequest?.id == pullRequest.id,
                                    showDivider: index < pullRequests.count - 1
                                )
                            }
                        }
                    }
                }
            }
            .allowsHitTesting(selectedPullRequest == nil && !isComposerVisible)

            if isComposerVisible {
                pullRequestComposerOverlayPanel(for: repo)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            } else if let selectedPullRequest {
                pullRequestDetailsOverlayPanel(for: selectedPullRequest, in: repo)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(
            .easeInOut(duration: 0.18),
            value: "\(selectedPullRequest?.id ?? "none")-\(isComposerVisible ? "composer" : "list")"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
        .task(id: "pull-requests-\(repo.id)") {
            await viewModel.loadPullRequestsIfNeeded(for: repo)
            await viewModel.loadBranchesIfNeeded(for: repo)
        }
    }

    private func pullRequestComposerOverlayPanel(for repo: RepoItem) -> some View {
        let eligibleBranches = viewModel.eligiblePullRequestBranches(for: repo)
        let selectedHeadBranch = viewModel.pullRequestDraftHeadBranch

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: closePullRequestComposer) {
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

                Text("Create Pull Request")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("Base branch")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                Text(repo.branch)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(primaryTextColor)

                if let selectedHeadBranch {
                    Text("Head branch: \(selectedHeadBranch)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("Title")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                TextField("Pull request title", text: $viewModel.pullRequestDraftTitle)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(actionCardFillColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(actionCardStrokeColor, lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text("Description")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                TextField("Description (optional)", text: $viewModel.pullRequestDraftBody, axis: .vertical)
                    .lineLimit(3...8)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(actionCardFillColor)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(actionCardStrokeColor, lineWidth: 1)
                            )
                    )
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if eligibleBranches.isEmpty {
                        Text("No branches ready to open a PR.")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                    } else {
                        ForEach(Array(eligibleBranches.enumerated()), id: \.element.id) { index, branch in
                            pullRequestComposerBranchRow(
                                branch,
                                in: repo,
                                isSelected: selectedHeadBranch == branch.name,
                                showDivider: index < eligibleBranches.count - 1
                            )
                        }
                    }
                }
            }

            HStack {
                Spacer(minLength: 0)

                Button(action: {
                    Task {
                        await createPullRequest(in: repo)
                    }
                }) {
                    HStack(spacing: 6) {
                        if viewModel.isPullRequestCreating {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white.opacity(0.95))
                        } else {
                            Image(systemName: "arrow.triangle.pull")
                                .font(.system(size: 11, weight: .bold))
                            Text("Create PR")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                    }
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(
                        Capsule()
                            .fill(accentColor)
                            .overlay(
                                Capsule()
                                    .stroke(accentColor.opacity(0.6), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .repoCursorOnHover()
                .disabled(!viewModel.canCreatePullRequest || viewModel.isPullRequestCreating)
                .opacity((viewModel.canCreatePullRequest && !viewModel.isPullRequestCreating) ? 1 : 0.55)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
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

    private func pullRequestDetailsOverlayPanel(
        for pullRequest: RepoPullRequestItem,
        in repo: RepoItem
    ) -> some View {
        let commits = viewModel.pullRequestCommits(for: pullRequest, in: repo)
        let isLoadingCommits = viewModel.isLoadingPullRequestCommits(for: pullRequest)
        let commitsLoadErrorMessage = viewModel.pullRequestCommitsLoadErrorMessage(for: pullRequest)

        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: closePullRequestDetails) {
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

                Text("PR #\(pullRequest.number)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)

                Spacer()

                Text(pullRequest.isMerged ? "Merged" : "Open")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(pullRequest.isMerged ? Color.green.opacity(0.7) : accentColor)
                    )

                Button {
                    Task {
                        await viewModel.reloadPullRequestCommits(for: pullRequest, in: repo)
                    }
                } label: {
                    if isLoadingCommits {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: 28, height: 28)
                            .background(
                                Circle()
                                    .fill(actionCardFillColor)
                                    .overlay(
                                        Circle()
                                            .stroke(actionCardStrokeColor, lineWidth: 1)
                                    )
                            )
                    } else {
                        Image(systemName: "arrow.clockwise")
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
                }
                .buttonStyle(.plain)
                .repoCursorOnHover()
                .disabled(isLoadingCommits)
                .opacity(isLoadingCommits ? 0.7 : 1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                Text(pullRequest.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text("#\(pullRequest.number) \(pullRequest.author) \(pullRequest.updatedAgo)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                HStack(spacing: 8) {
                    Text("\(pullRequest.sourceBranch) -> \(pullRequest.targetBranch)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("\(pullRequest.commits) commits")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 0) {
                    if isLoadingCommits && commits.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("Loading commits...")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                    } else if let commitsLoadErrorMessage, commits.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(commitsLoadErrorMessage)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(Color.red.opacity(isDarkTheme ? 0.86 : 0.72))
                                .fixedSize(horizontal: false, vertical: true)

                            Button("Retry") {
                                Task {
                                    await viewModel.reloadPullRequestCommits(for: pullRequest, in: repo)
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                            .repoCursorOnHover()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 18)
                    } else if commits.isEmpty {
                        Text("No commits for this pull request.")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                    } else {
                        ForEach(Array(commits.enumerated()), id: \.element.id) { index, commit in
                            pullRequestCommitRow(commit, showDivider: index < commits.count - 1)
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
        .task(id: "pull-request-commits-\(pullRequest.id)") {
            await viewModel.loadPullRequestCommitsIfNeeded(for: pullRequest, in: repo)
        }
    }

    private func branchesOverlayPanel(for repo: RepoItem) -> some View {
        let branches = viewModel.branches(for: repo)
        let selectedBranch = viewModel.selectedBranch(for: repo)
        let isLoadingBranches = viewModel.isLoadingBranches(for: repo)
        let branchesLoadErrorMessage = viewModel.branchesLoadErrorMessage(for: repo)

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                overlayTopBar(
                    title: "Branches",
                    onRefresh: {
                        Task {
                            await viewModel.reloadBranches(for: repo)
                        }
                    }
                )

                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        if isLoadingBranches && branches.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading branches...")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(secondaryTextColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                        } else if let branchesLoadErrorMessage, branches.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(branchesLoadErrorMessage)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.red.opacity(isDarkTheme ? 0.86 : 0.72))
                                    .fixedSize(horizontal: false, vertical: true)

                                Button("Retry") {
                                    Task {
                                        await viewModel.reloadBranches(for: repo)
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(accentColor)
                                .repoCursorOnHover()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                        } else if branches.isEmpty {
                            Text("No branches available.")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                        } else {
                            ForEach(Array(branches.enumerated()), id: \.element.id) { index, branch in
                                branchRow(
                                    branch,
                                    isSelected: selectedBranch?.id == branch.id,
                                    showDivider: index < branches.count - 1
                                )
                            }
                        }
                    }
                }
            }
            .allowsHitTesting(selectedBranch == nil)

            if let selectedBranch {
                branchDetailsOverlayPanel(for: selectedBranch, in: repo)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: selectedBranch?.id)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
        .task(id: "branches-\(repo.id)") {
            await viewModel.loadBranchesIfNeeded(for: repo)
        }
    }

    private func branchDetailsOverlayPanel(for branch: RepoBranchItem, in repo: RepoItem) -> some View {
        return VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: closeBranchDetails) {
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

                Text(branch.name)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)

                Spacer()

                if branch.isDefault {
                    Text("Default")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.95))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(accentColor)
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(branch.isCurrent ? "Current branch" : "Branch")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)
                    Spacer()
                    Text(branch.updatedAgo)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                }

                Text("Ahead \(branch.aheadBy) • Behind \(branch.behindBy)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                if branch.hasOpenPullRequest {
                    Text("This branch already has an open pull request.")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(Color.orange.opacity(0.9))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            VStack(alignment: .leading, spacing: 10) {
                detailNavigationRow(icon: "arrow.triangle.branch", title: "Checkout Branch") {
                    handleLocalAction(for: repo, action: .checkout(branchName: branch.name))
                }
                detailNavigationRow(icon: "terminal", title: "Open in Terminal") {
                    handleLocalAction(for: repo, action: .terminalOnBranch(branchName: branch.name))
                }

                Button {
                    openPullRequestComposer(from: branch, in: repo)
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.pull")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Create PR")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(accentColor)
                            .overlay(
                                Capsule()
                                    .stroke(accentColor.opacity(0.65), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(.plain)
                .repoCursorOnHover()
                .disabled(!branch.canOpenPullRequest(baseBranch: repo.branch))
                .opacity(branch.canOpenPullRequest(baseBranch: repo.branch) ? 1 : 0.55)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Spacer(minLength: 0)
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

    private func destinationInfoOverlayPanel(
        for repo: RepoItem,
        destination: RepoDetailDestination
    ) -> some View {
        let supportsRemoteLoading = destination == .ciRuns
            || destination == .openCommits
            || destination == .tags
            || destination == .releases
            || destination == .discussions
            || destination == .contributors
        let items = viewModel.destinationInfoItems(for: repo, destination: destination)
        let selectedItem = viewModel.selectedDestinationInfoItem(for: repo, destination: destination)
        let isLoadingItems: Bool
        let loadErrorMessage: String?
        let onRefresh: (() -> Void)?

        switch destination {
        case .ciRuns:
            isLoadingItems = viewModel.isLoadingCIRuns(for: repo)
            loadErrorMessage = viewModel.ciRunsLoadErrorMessage(for: repo)
            onRefresh = {
                Task {
                    await viewModel.reloadCIRuns(for: repo)
                }
            }
        case .openCommits:
            isLoadingItems = viewModel.isLoadingOpenCommits(for: repo)
            loadErrorMessage = viewModel.openCommitsLoadErrorMessage(for: repo)
            onRefresh = {
                Task {
                    await viewModel.reloadOpenCommits(for: repo)
                }
            }
        case .tags:
            isLoadingItems = viewModel.isLoadingTags(for: repo)
            loadErrorMessage = viewModel.tagsLoadErrorMessage(for: repo)
            onRefresh = {
                Task {
                    await viewModel.reloadTags(for: repo)
                }
            }
        case .releases:
            isLoadingItems = viewModel.isLoadingReleases(for: repo)
            loadErrorMessage = viewModel.releasesLoadErrorMessage(for: repo)
            onRefresh = {
                Task {
                    await viewModel.reloadReleases(for: repo)
                }
            }
        case .discussions:
            isLoadingItems = viewModel.isLoadingDiscussions(for: repo)
            loadErrorMessage = viewModel.discussionsLoadErrorMessage(for: repo)
            onRefresh = {
                Task {
                    await viewModel.reloadDiscussions(for: repo)
                }
            }
        case .contributors:
            isLoadingItems = viewModel.isLoadingContributors(for: repo)
            loadErrorMessage = viewModel.contributorsLoadErrorMessage(for: repo)
            onRefresh = {
                Task {
                    await viewModel.reloadContributors(for: repo)
                }
            }
        default:
            isLoadingItems = false
            loadErrorMessage = nil
            onRefresh = nil
        }

        return ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                overlayTopBar(title: "Open \(destination.title)", onRefresh: onRefresh)

                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)

                if destination == .contributors {
                    HStack(spacing: 10) {
                        Image(systemName: "arrow.trianglehead.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(secondaryTextColor)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("App update available")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(primaryTextColor)

                            Text("Open latest release and update OpenKubbo.")
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                        }

                        Spacer(minLength: 8)

                        Button("Update App") {
                            openAppUpdatePage()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(accentColor)
                        .disabled(!isAppUpdateEnabled)
                        .opacity(isAppUpdateEnabled ? 1 : 0.58)
                        .repoCursorOnHover()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: 0) {
                        if supportsRemoteLoading && isLoadingItems && items.isEmpty {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .controlSize(.small)
                                Text("Loading \(destination.title.lowercased())...")
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(secondaryTextColor)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                        } else if supportsRemoteLoading, let loadErrorMessage, items.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(loadErrorMessage)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color.red.opacity(isDarkTheme ? 0.86 : 0.72))
                                    .fixedSize(horizontal: false, vertical: true)

                                Button("Retry") {
                                    Task {
                                        switch destination {
                                        case .ciRuns:
                                            await viewModel.reloadCIRuns(for: repo)
                                        case .openCommits:
                                            await viewModel.reloadOpenCommits(for: repo)
                                        case .tags:
                                            await viewModel.reloadTags(for: repo)
                                        case .releases:
                                            await viewModel.reloadReleases(for: repo)
                                        case .discussions:
                                            await viewModel.reloadDiscussions(for: repo)
                                        case .contributors:
                                            await viewModel.reloadContributors(for: repo)
                                        default:
                                            break
                                        }
                                    }
                                }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .foregroundStyle(accentColor)
                                .repoCursorOnHover()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 18)
                        } else if items.isEmpty {
                            Text("No items available.")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(secondaryTextColor)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 18)
                        } else {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                destinationInfoRow(
                                    item,
                                    icon: destination.icon,
                                    isSelected: selectedItem?.id == item.id,
                                    showDivider: index < items.count - 1
                                )
                            }
                        }
                    }
                }
            }
            .allowsHitTesting(selectedItem == nil)

            if let selectedItem {
                destinationInfoDetailsOverlayPanel(item: selectedItem, destination: destination)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: selectedItem?.id)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
        .task(id: "destination-\(destination.rawValue)-\(repo.id)") {
            if destination == .ciRuns {
                await viewModel.loadCIRunsIfNeeded(for: repo)
            } else if destination == .openCommits {
                await viewModel.loadOpenCommitsIfNeeded(for: repo)
            } else if destination == .tags {
                await viewModel.loadTagsIfNeeded(for: repo)
            } else if destination == .releases {
                await viewModel.loadReleasesIfNeeded(for: repo)
            } else if destination == .discussions {
                await viewModel.loadDiscussionsIfNeeded(for: repo)
            } else if destination == .contributors {
                await viewModel.loadContributorsIfNeeded(for: repo)
            }
        }
    }

    private func openAppUpdatePage() {
        guard let releaseURL = URL(string: "https://github.com/openkubbo/openkubbo/releases/latest") else {
            return
        }

        NSWorkspace.shared.open(releaseURL)
    }

    private func destinationInfoDetailsOverlayPanel(
        item: RepoDestinationInfoItem,
        destination: RepoDetailDestination
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                Button(action: closeDestinationInfoDetails) {
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

                Text(destination.title)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 8)

                        if let status = item.status {
                            Text(status)
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.95))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(
                                    Capsule()
                                        .fill(accentColor)
                                )
                        }
                    }

                    Text(item.subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)

                    Text(item.metadata)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)

                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)

                    Text(item.summary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(primaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)

                    if !item.bulletPoints.isEmpty {
                        Rectangle()
                            .fill(dividerColor)
                            .frame(height: 1)

                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(item.bulletPoints.enumerated()), id: \.offset) { _, bulletPoint in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(accentColor)
                                        .frame(width: 6, height: 6)
                                        .padding(.top, 5)

                                    Text(bulletPoint)
                                        .font(.system(size: 12, weight: .medium, design: .rounded))
                                        .foregroundStyle(primaryTextColor)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
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

    private func overlayTopBar(
        title: String,
        onFilter: (() -> Void)? = nil,
        onRefresh: (() -> Void)? = nil
    ) -> some View {
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

            overlayHeaderIconButton(symbol: "line.3.horizontal.decrease", action: onFilter)
            overlayHeaderIconButton(symbol: "arrow.clockwise", action: onRefresh)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    private func overlayHeaderIconButton(symbol: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
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
        .disabled(action == nil)
        .opacity(action == nil ? 0.45 : 1)
    }

    private func issueFeedbackBanner(_ message: String, isError: Bool) -> some View {
        Text(message)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(
                isError
                    ? Color.red.opacity(isDarkTheme ? 0.9 : 0.72)
                    : Color.green.opacity(isDarkTheme ? 0.9 : 0.72)
            )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                (isError ? Color.red : Color.green)
                    .opacity(isDarkTheme ? 0.12 : 0.08)
            )
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

    private func pullRequestsFilterPill(_ scope: RepoPullRequestsScope) -> some View {
        let isActive = viewModel.selectedPullRequestsScope == scope

        return Button {
            withAnimation(.easeInOut(duration: 0.14)) {
                viewModel.selectPullRequestsScope(scope)
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

    private var newIssueButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.openIssueComposer()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("New Issue")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(accentColor)
                    .overlay(
                        Capsule()
                            .stroke(accentColor.opacity(0.6), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    private func newPullRequestButton(for repo: RepoItem) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.openPullRequestComposer(in: repo)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                Text("Create PR")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(accentColor)
                    .overlay(
                        Capsule()
                            .stroke(accentColor.opacity(0.6), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    private func pullRequestComposerBranchRow(
        _ branch: RepoBranchItem,
        in repo: RepoItem,
        isSelected: Bool,
        showDivider: Bool
    ) -> some View {
        Button {
            viewModel.selectPullRequestDraftHeadBranch(branch, baseBranch: repo.branch)
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 18, alignment: .center)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(branch.name)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)

                        Text("Ahead \(branch.aheadBy) • Behind \(branch.behindBy) • \(branch.updatedAgo)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                    }

                    Spacer(minLength: 8)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(accentColor)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(isSelected ? accentColor.opacity(isDarkTheme ? 0.16 : 0.11) : .clear)
                )

                if showDivider {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    private func branchRow(
        _ branch: RepoBranchItem,
        isSelected: Bool,
        showDivider: Bool
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.selectBranch(branch)
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 18, alignment: .center)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Text(branch.name)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .foregroundStyle(primaryTextColor)
                                .lineLimit(1)

                            if branch.isCurrent {
                                Text("Current")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(
                                        Capsule()
                                            .fill(accentColor)
                                    )
                            }
                        }

                        Text("Ahead \(branch.aheadBy) • Behind \(branch.behindBy) • \(branch.updatedAgo)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                    }

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(isSelected ? accentColor.opacity(isDarkTheme ? 0.16 : 0.11) : .clear)
                )

                if showDivider {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    private func worktreeRow(
        _ worktree: RepoWorktreeItem,
        in repo: RepoItem,
        showDivider: Bool
    ) -> some View {
        let isActive = viewModel.isWorktreeActive(worktree, in: repo)
        let branchName = worktree.branchName ?? "Detached HEAD"

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.switchToWorktree(worktree, in: repo)
            }
        } label: {
            VStack(spacing: 0) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "arrow.left.arrow.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 18, alignment: .center)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(worktree.directoryName)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)

                        Text(branchName)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)

                        Text(worktree.path)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }

                    Spacer(minLength: 8)

                    if isActive {
                        Text("Active")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                Capsule()
                                    .fill(accentColor)
                            )
                    } else if worktree.isCurrent {
                        Text("Current")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
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
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(isActive ? accentColor.opacity(isDarkTheme ? 0.16 : 0.11) : .clear)
                )

                if showDivider {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    private func destinationInfoRow(
        _ item: RepoDestinationInfoItem,
        icon: String,
        isSelected: Bool,
        showDivider: Bool
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.selectDestinationInfoItem(item)
            }
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accentColor)
                        .frame(width: 18, alignment: .center)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                            .lineLimit(1)

                        Text(item.subtitle)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 8)

                    if let trailingValue = item.trailingValue {
                        Text(trailingValue)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(primaryTextColor)
                            .padding(.horizontal, 7)
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

                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(isSelected ? accentColor.opacity(isDarkTheme ? 0.16 : 0.11) : .clear)
                )

                if showDivider {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    private func pullRequestRow(
        _ pullRequest: RepoPullRequestItem,
        in repo: RepoItem,
        isSelected: Bool,
        showDivider: Bool
    ) -> some View {
        Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.selectPullRequest(pullRequest, in: repo)
            }
        } label: {
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 9) {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "arrow.triangle.pull")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(accentColor)
                            .frame(width: 18, alignment: .center)

                        VStack(alignment: .leading, spacing: 5) {
                            Text(pullRequest.title)
                                .font(.system(size: 13, weight: .semibold, design: .rounded))
                                .foregroundStyle(primaryTextColor)
                                .fixedSize(horizontal: false, vertical: true)

                            HStack(spacing: 7) {
                                Text(pullRequest.isMerged ? "Merged" : "Open")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.95))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(
                                        Capsule()
                                            .fill(pullRequest.isMerged ? Color.green.opacity(0.7) : accentColor)
                                    )

                                Text("#\(pullRequest.number)")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundStyle(secondaryTextColor)
                            }
                        }

                        Spacer(minLength: 8)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(secondaryTextColor)
                    }

                    HStack(spacing: 8) {
                        Text("\(pullRequest.sourceBranch) -> \(pullRequest.targetBranch)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                            .lineLimit(1)

                        Spacer(minLength: 8)

                        Text("\(pullRequest.commits) commits")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(secondaryTextColor)
                    }

                    Text("\(pullRequest.changedFiles) files +\(pullRequest.additions) -\(pullRequest.deletions)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(isSelected ? accentColor.opacity(isDarkTheme ? 0.16 : 0.11) : .clear)
                )

                if showDivider {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    private func pullRequestCommitRow(_ commit: RepoPullRequestCommitItem, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(accentColor)
                    .frame(width: 7, height: 7)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 5) {
                    Text(commit.message)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(primaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("\(commit.sha) \(commit.author) \(commit.committedAgo)")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(secondaryTextColor)
                        .lineLimit(1)
                }

                Spacer(minLength: 6)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            if showDivider {
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
            }
        }
    }

    private func issueRow(
        _ issue: RepoIssueItem,
        in repo: RepoItem,
        isSelected: Bool,
        showDivider: Bool
    ) -> some View {
        let issueBranches = viewModel.issueBranches(for: issue, in: repo)

        return Button {
            withAnimation(.easeInOut(duration: 0.18)) {
                viewModel.selectIssue(issue, in: repo)
            }
        } label: {
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

                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(secondaryTextColor)
                    }

                    HStack(spacing: 8) {
                        ForEach(issue.labels) { label in
                            issueLabelPill(label)
                        }
                    }

                    Text("#\(issue.number) \(issue.author) \(issue.updatedAgo)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)

                    if !issueBranches.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 6) {
                                ForEach(issueBranches, id: \.self) { branchName in
                                    issueBranchTag(title: branchName)
                                }
                            }
                            .padding(.vertical, 1)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(
                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                        .fill(isSelected ? accentColor.opacity(isDarkTheme ? 0.16 : 0.11) : .clear)
                )

                if showDivider {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 1)
                }
            }
        }
        .buttonStyle(.plain)
        .repoCursorOnHover()
    }

    private func issueBranchTag(title: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.branch")
                .font(.system(size: 9, weight: .semibold))
            Text(title)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .lineLimit(1)
        }
        .foregroundStyle(secondaryTextColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(actionCardFillColor)
                .overlay(
                    Capsule()
                        .stroke(actionCardStrokeColor, lineWidth: 1)
                )
        )
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

    private func issueCommentRow(_ comment: RepoIssueCommentItem, showDivider: Bool) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(comment.author)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryTextColor)

                    Spacer(minLength: 8)

                    Text(comment.updatedAgo)
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(secondaryTextColor)
                }

                Text(comment.body)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            if showDivider {
                Rectangle()
                    .fill(dividerColor)
                    .frame(height: 1)
                    .padding(.horizontal, 12)
            }
        }
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

    private func openSettingsWindow() {
        openWindow(id: "settings")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func refreshPrimaryPanel() {
        Task {
            await viewModel.reloadPanelData()
        }
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

    private func closeIssueDetails() {
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.closeIssueDetails()
        }
    }

    private func closeIssueComposer() {
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.closeIssueComposer()
        }
    }

    private func createIssue(in repo: RepoItem) async {
        await viewModel.createIssue(in: repo)
    }

    private func addIssueComment(in repo: RepoItem) async {
        guard let issue = viewModel.selectedIssue(for: repo) else { return }
        await viewModel.addIssueComment(to: issue, in: repo)
    }

    private func createPullRequest(in repo: RepoItem) async {
        await viewModel.createPullRequest(in: repo)
    }

    private func createIssueBranch(from issue: RepoIssueItem, in repo: RepoItem) async {
        await viewModel.createBranchFromIssue(issue, in: repo)
    }

    private func closePullRequestDetails() {
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.closePullRequestDetails()
        }
    }

    private func closePullRequestComposer() {
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.closePullRequestComposer()
        }
    }

    private func closeBranchDetails() {
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.closeBranchDetails()
        }
    }

    private func closeDestinationInfoDetails() {
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.closeDestinationInfoDetails()
        }
    }

    private func openPullRequestComposer(from branch: RepoBranchItem, in repo: RepoItem) {
        withAnimation(.easeInOut(duration: 0.18)) {
            viewModel.openPullRequestComposer(in: repo, preferredHeadBranch: branch.name)
        }
    }

    private func openRepositoryOnGitHub(_ repo: RepoItem) {
        guard let repositoryURL = URL(string: "https://github.com/\(repo.name)") else { return }
        NSWorkspace.shared.open(repositoryURL)
    }

    private func cloneRepositoryForWorktrees(_ repo: RepoItem) {
        Task {
            let result = await viewModel.cloneLocalRepository(for: repo)
            switch result {
            case .cloned:
                await viewModel.reloadWorktrees(for: repo)
            case .rootNotConfigured:
                localActionAlertState = LocalActionAlertState(kind: .rootNotConfigured)
            case .cloneRequired(let expectedPath):
                localActionAlertState = LocalActionAlertState(
                    kind: .failed("Repository could not be cloned to \(expectedPath).")
                )
            case .failed(let message):
                localActionAlertState = LocalActionAlertState(kind: .failed(message))
            case .opened:
                break
            }
        }
    }

    private func handleLocalAction(for repo: RepoItem, action: PendingLocalAction) {
        let branchForAction: RepoBranchItem?

        switch action {
        case .finder, .terminal:
            branchForAction = nil
        case .checkout(let branchName), .terminalOnBranch(let branchName):
            guard let branch = viewModel.branches(for: repo).first(where: { $0.name == branchName }) else {
                localActionAlertState = LocalActionAlertState(
                    kind: .failed("Branch '\(branchName)' is not available anymore.")
                )
                return
            }
            branchForAction = branch
        }

        Task {
            let result: RepositoryLocalActionResult

            switch action {
            case .finder:
                result = await viewModel.openInFinder(for: repo)
            case .terminal:
                result = await viewModel.openInTerminal(for: repo)
            case .checkout:
                guard let branchForAction else {
                    return
                }
                result = await viewModel.checkoutBranch(branchForAction, in: repo)
            case .terminalOnBranch:
                guard let branchForAction else {
                    return
                }
                result = await viewModel.openInTerminal(for: repo, on: branchForAction)
            }

            handleLocalActionResult(result, for: repo, action: action)
        }
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

    private var trimmedNewWorktreeBranchName: String {
        newWorktreeBranchName.trimmingCharacters(in: .whitespacesAndNewlines)
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
    var contributionCountsByDateKey: [String: Int]
    var totalContributions: Int

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

    private func dateKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        let year = components.year ?? 0
        let month = components.month ?? 1
        let day = components.day ?? 1
        return String(format: "%04d-%02d-%02d", year, month, day)
    }

    private func contributionCount(for date: Date) -> Int {
        let key = dateKey(for: date)
        return max(0, contributionCountsByDateKey[key] ?? 0)
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

    private var totalContributionsText: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: totalContributions)) ?? "\(totalContributions)"
        return "\(formatted) contributions"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(totalContributionsText)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(isDarkTheme ? .white.opacity(0.64) : .black.opacity(0.58))
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
