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

    /// Barra lateral ~25–30% da janela (720 → ~220pt)
    private let sidebarWidth: CGFloat = 220
    /// Item selecionado: lilás/roxo claro (#F2EDF8)
    private let selectedBackground = Color(red: 242/255, green: 237/255, blue: 248/255)
    /// Ícone e texto do item selecionado: mais escuro/contraste sobre o lilás
    private let selectedForeground = Color(white: 0.22)
    /// Fundos: barra lateral e área de conteúdo branco sólido
    private let contentWhite = Color.white
    /// Borda sutil do campo de busca
    private let searchBorderGray = Color(white: 0.88)

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            mainContent
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(contentWhite)
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            searchField
                .padding(.horizontal, 12)
                .padding(.top, 16)
                .padding(.bottom, 14)

            VStack(alignment: .leading, spacing: 4) {
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
            .padding(.horizontal, 12)

            Spacer(minLength: 0)

            userArea
                .padding(12)
        }
        .frame(width: sidebarWidth, alignment: .leading)
        .background(contentWhite)
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(white: 0.55))
                .font(.system(size: 14))
            TextField("Buscar", text: $searchText)
                .textFieldStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(contentWhite)
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
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(selectedForeground)
            }
            .fixedSize()
            VStack(alignment: .leading, spacing: 2) {
                Text("GlassUser")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color(white: 0.25))
                Text("PRO ACCOUNT")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color(white: 0.55))
            }
            Spacer(minLength: 0)
        }
        .padding(8)
    }

    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(sectionTitle)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(white: 0.15))
                .padding(.top, 20)
                .padding(.leading, 28)
                .padding(.bottom, 20)

            sectionContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(contentWhite)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(contentWhite)
    }

    private var sectionTitle: String {
        switch selectedSection {
        case .geral: return "Geral"
        case .aparência: return "Aparência"
        case .codexCLI: return "Codex CLI"
        case .atalhos: return "Atalhos de Teclado"
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .geral, .aparência, .codexCLI, .atalhos:
            contentWhite
        }
    }
}

private struct SettingsNavItem: View {
    let section: SettingsSection
    let isSelected: Bool
    let selectedBackground: Color
    let selectedForeground: Color
    let action: () -> Void

    /// Ícones: Geral = layout/gráfico, Aparência = monitor, Codex CLI = prompt, Atalhos = ⌘
    private var iconName: String {
        switch section {
        case .geral: return "rectangle.split.2x2"
        case .aparência: return "display"
        case .codexCLI: return "terminal"
        case .atalhos: return "command"
        }
    }

    /// Cantos arredondados só à direita no item selecionado
    private var selectedShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 8,
            topTrailingRadius: 8
        )
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundStyle(isSelected ? selectedForeground : Color(white: 0.35))
                    .frame(width: 20, height: 20)

                Text(section.rawValue)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? selectedForeground : Color(white: 0.25))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .background {
                if isSelected {
                    selectedShape.fill(selectedBackground)
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
