import AppKit
import ObjectiveC.runtime
import SwiftUI

// MARK: - Data Model

private struct RepoItem: Identifiable {
    let id = UUID()
    let name: String
    let issues: Int
    let prs: Int
    let stars: Int
    let branch: String
    let updatedAgo: String
    let isPinned: Bool
    let isWork: Bool
}

// MARK: - Main View

struct RepositoryPanelView: View {
    private let panelWidth: CGFloat = 340
    private let panelHorizontalInset: CGFloat = 2
    private let panelVerticalInset: CGFloat = 6
    private let windowEdgePaddingX: CGFloat = 10
    private let windowEdgePaddingY: CGFloat = 12

    @State private var hostWindow: NSWindow?
    @State private var selectedFilter: RepoFilter = .all
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
            name: "tarikvillalobos/postme",
            issues: 2,
            prs: 1,
            stars: 124,
            branch: "main",
            updatedAgo: "1 min. ago",
            isPinned: true,
            isWork: false
        ),
        RepoItem(
            name: "tarikvillalobos/rentify",
            issues: 4,
            prs: 5,
            stars: 892,
            branch: "main",
            updatedAgo: "14 min. ago",
            isPinned: true,
            isWork: true
        ),
        RepoItem(
            name: "tarikvillalobos/time-zones",
            issues: 1,
            prs: 0,
            stars: 340,
            branch: "dev",
            updatedAgo: "13 min. ago",
            isPinned: false,
            isWork: false
        ),
        RepoItem(
            name: "tarikvillalobos/squaddy",
            issues: 0,
            prs: 2,
            stars: 56,
            branch: "master",
            updatedAgo: "1 hr. ago",
            isPinned: false,
            isWork: true
        ),
        RepoItem(
            name: "tarikvillalobos/api-kit",
            issues: 3,
            prs: 1,
            stars: 1205,
            branch: "feature/v2",
            updatedAgo: "30 min. ago",
            isPinned: true,
            isWork: true
        ),
        RepoItem(
            name: "tarikvillalobos/mnemonic",
            issues: 0,
            prs: 0,
            stars: 78,
            branch: "main",
            updatedAgo: "2 hr. ago",
            isPinned: false,
            isWork: false
        ),
        RepoItem(
            name: "tarikvillalobos/open-tasks",
            issues: 5,
            prs: 3,
            stars: 412,
            branch: "main",
            updatedAgo: "4 min. ago",
            isPinned: true,
            isWork: true
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

    // MARK: - Panel height

    private var repoListHeight: CGFloat {
        let rowHeight: CGFloat = 72
        let spacing: CGFloat = 0
        let count = CGFloat(min(filteredRepos.count, 5))
        return count * rowHeight + max(count - 1, 0) * spacing
    }

    private var panelHeight: CGFloat {
        // header(56) + heatmap section(158) + filter(44) + list + footer(46) + paddings
        56 + 158 + 44 + repoListHeight + 46 + 40
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
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("last 12 months")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                Spacer()
            }

            ContributionHeatmap(isDarkTheme: isDarkTheme)
                .frame(maxWidth: .infinity)
                .frame(height: 100)

            HStack {
                Text("Nov 2024")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(secondaryTextColor)

                Spacer()

                Text("Dec 2025")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(secondaryTextColor)
            }
            .padding(.top, 2)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(cardFillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(cardStrokeColor, lineWidth: 1)
                )
        )
    }

    // MARK: - Filter tabs

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

    // MARK: - Repo list

    private var repoList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 0) {
                ForEach(filteredRepos) { repo in
                    RepoRow(
                        repo: repo,
                        isDarkTheme: isDarkTheme,
                        primaryColor: primaryTextColor,
                        secondaryColor: secondaryTextColor,
                        accentColor: accentColor,
                        dividerColor: dividerColor
                    )
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

    // MARK: - Actions

    private func closeWindow() {
        hostWindow?.close()
    }
}

// MARK: - Contribution Heatmap

private struct ContributionHeatmap: View {
    var isDarkTheme: Bool

    // 53 columns × 7 rows (≈ 1 year of weeks)
    private let weeks = 53
    private let days = 7

    // Seeded pseudo-random intensity for a realistic-looking pattern
    private func intensity(week: Int, day: Int) -> Double {
        let seed = (week * 7 + day + 17) % 13
        // Weekend (sat/sun index 5,6) slightly less activity
        let isWeekend = day >= 5
        let base: [Double] = [0, 0, 0, 0.25, 0.5, 0.75, 1.0, 0.5, 0.25, 0, 0, 0.75, 0.5]
        var value = base[seed]
        if isWeekend {
            value *= 0.5
        }
        // Burst weeks
        if week % 6 == 2 {
            value = min(1.0, value + 0.4)
        }
        if week % 11 == 5 {
            value = min(1.0, value + 0.6)
        }
        return value
    }

    private func cellColor(intensity: Double) -> Color {
        guard intensity > 0 else {
            return isDarkTheme
                ? Color(red: 0.20, green: 0.21, blue: 0.26)
                : Color(red: 0.91, green: 0.91, blue: 0.93)
        }
        // Indigo-purple gradient
        let red = 0.39 + intensity * 0.08
        let green = 0.25 - intensity * 0.05
        let blue = 0.95 - intensity * 0.12
        return Color(red: red, green: green, blue: blue).opacity(0.55 + intensity * 0.45)
    }

    var body: some View {
        GeometryReader { geometry in
            let cellWidth = geometry.size.width / CGFloat(weeks)
            let cellHeight = geometry.size.height / CGFloat(days)
            let gap: CGFloat = 2

            Canvas { context, _ in
                for week in 0..<weeks {
                    for day in 0..<days {
                        let value = intensity(week: week, day: day)
                        let color = cellColor(intensity: value)
                        let x = CGFloat(week) * cellWidth
                        let y = CGFloat(day) * cellHeight
                        let rect = CGRect(
                            x: x + gap / 2,
                            y: y + gap / 2,
                            width: cellWidth - gap,
                            height: cellHeight - gap
                        )
                        let path = Path(roundedRect: rect, cornerRadius: 2)
                        context.fill(path, with: .color(color))
                    }
                }
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

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 10) {
                // Bullet
                Circle()
                    .fill(accentColor)
                    .frame(width: 8, height: 8)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 4) {
                    Text(repo.name)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(primaryColor)
                        .lineLimit(1)

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
            .background(
                isHovered
                    ? (isDarkTheme ? Color.white.opacity(0.05) : Color.black.opacity(0.03))
                    : Color.clear
            )

            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)
                .padding(.horizontal, 12)
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

// MARK: - Window infrastructure

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

        // Keep explicit drag handling via drag-region view.
        let canMove: @convention(block) (AnyObject) -> Bool = { _ in false }
        if let method = class_getInstanceMethod(windowClass, NSSelectorFromString("isMovable")) {
            method_setImplementation(method, imp_implementationWithBlock(canMove))
        }

        Self.patchedClasses.insert(classID)
    }
}
