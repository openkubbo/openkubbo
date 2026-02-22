//
//  SettingsView.swift
//  OpenKubbo
//
//  Created by Tarik Villalobos on 2/22/26.
//

import SwiftUI

private enum SettingsSection: String, CaseIterable {
    case geral = "Geral"
    case aparência = "Aparência"
    case codexCLI = "Codex CLI"
    case atalhos = "Atalhos"
}

struct SettingsView: View {
    @State private var selectedSection: SettingsSection = .atalhos
    @State private var searchText = ""

    /// Barra lateral ~220pt
    private let sidebarWidth: CGFloat = 220
    /// Item selecionado: lilás/roxo claro (#EDE9F8)
    private let selectedBackground = Color(red: 237/255, green: 233/255, blue: 248/255)
    /// Ícone e texto do item selecionado
    private let selectedForeground = Color(white: 0.18)
    /// Fundo da sidebar: cinza muito suave
    private let sidebarGray = Color(red: 246/255, green: 246/255, blue: 247/255)
    /// Fundo do conteúdo: branco puro
    private let contentWhite = Color.white
    /// Borda do campo de busca
    private let searchBorderGray = Color(white: 0.86)
    /// Divisor
    private let dividerColor = Color(white: 0.88)

    var body: some View {
        HStack(spacing: 0) {
            sidebar

            // Divisor vertical
            Rectangle()
                .fill(dividerColor)
                .frame(width: 1)

            mainContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(contentWhite)
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 2) {
                ForEach(SettingsSection.allCases, id: \.self) { section in
                    SettingsNavItem(
                        section: section,
                        isSelected: selectedSection == section,
                        selectedBackground: selectedBackground,
                        selectedForeground: selectedForeground
                    ) {
                        selectedSection = section
                    }
                }
            }
            .padding(.horizontal, 10)

            Spacer(minLength: 0)

            // Divisor acima do usuário
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)
                .padding(.horizontal, 0)

            userArea
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
        }
        .frame(width: sidebarWidth, alignment: .leading)
        .background(sidebarGray)
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(white: 0.58))
                .font(.system(size: 13))
            TextField("Buscar", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color(white: 0.3))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(searchBorderGray, lineWidth: 1)
        )
    }

    private var userArea: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(selectedBackground)
                    .frame(width: 36, height: 36)
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color(red: 0.45, green: 0.35, blue: 0.72))
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("GlassUser")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Color(white: 0.18))
                Text("PRO ACCOUNT")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(white: 0.55))
                    .tracking(0.3)
            }
            Spacer(minLength: 0)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(sectionTitle)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Color(white: 0.12))
                .padding(.top, 22)
                .padding(.leading, 28)
                .padding(.bottom, 18)

            // Linha horizontal sob o título
            Rectangle()
                .fill(dividerColor)
                .frame(height: 1)

            sectionContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(contentWhite)
    }

    private var sectionTitle: String {
        switch selectedSection {
        case .geral:      return "Geral"
        case .aparência:  return "Aparência"
        case .codexCLI:   return "Codex CLI"
        case .atalhos:    return "Atalhos de Teclado"
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .geral, .aparência, .codexCLI, .atalhos:
            Color.clear
        }
    }
}

// MARK: - Nav Item

private struct SettingsNavItem: View {
    let section: SettingsSection
    let isSelected: Bool
    let selectedBackground: Color
    let selectedForeground: Color
    let action: () -> Void

    private var iconName: String {
        switch section {
        case .geral:      return "slider.horizontal.3"
        case .aparência:  return "display"
        case .codexCLI:   return "terminal"
        case .atalhos:    return "command"
        }
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 15))
                    .foregroundStyle(isSelected ? Color(red: 0.42, green: 0.32, blue: 0.70) : Color(white: 0.38))
                    .frame(width: 20, height: 20)

                Text(section.rawValue)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? selectedForeground : Color(white: 0.22))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(selectedBackground)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .frame(width: 720, height: 450)
}
