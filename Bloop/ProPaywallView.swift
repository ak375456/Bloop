//
//  ProPaywallView.swift
//  Bloop
//
//  Created by aftab fazal qayum on 05/05/2026.
//



import SwiftUI
import StoreKit

struct ProPaywallView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var storeKit: StoreKitManager
    let onPurchased: () -> Void

    var body: some View {
        VStack(spacing: 0) {

            // ── Header ──────────────────────────────────────────────
            HStack {
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            // ── Hero ─────────────────────────────────────────────────
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.accentColor.opacity(0.12))
                        .frame(width: 80, height: 80)
                    Image(systemName: "sparkles")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.accentColor)
                }

                Text("MenuBar Pets Pro")
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                Text("Unlock the full experience")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)
            .padding(.bottom, 28)

            // ── Feature List ─────────────────────────────────────────
            VStack(spacing: 14) {
                FeatureRow(icon: "photo.badge.plus",
                           color: .blue,
                           title: "Custom Hanging Characters",
                           subtitle: "Upload any image and hang it from your menu bar")

                FeatureRow(icon: "wand.and.stars",
                           color: .purple,
                           title: "Auto Background Removal",
                           subtitle: "Instantly cut out backgrounds with one tap")

                FeatureRow(icon: "bolt.fill",
                           color: .orange,
                           title: "Clickable Actions",
                           subtitle: "Link characters to apps, URLs, or Shortcuts")

                FeatureRow(icon: "infinity",
                           color: .green,
                           title: "One-Time Purchase",
                           subtitle: "Pay once, yours forever — no subscription")
            }
            .padding(.horizontal, 28)

            Spacer()

            // ── Error message ────────────────────────────────────────
            if let error = storeKit.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)
            }

            // ── CTA ──────────────────────────────────────────────────
            VStack(spacing: 10) {
                Button {
                    Task {
                        await storeKit.purchase()
                        if storeKit.isProUnlocked {
                            onPurchased()
                        }
                    }
                } label: {
                    HStack {
                        if storeKit.isPurchasing {
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(.white)
                        }
                        Text(priceLabel)
                            .font(.system(size: 15, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)
                .disabled(storeKit.isPurchasing || storeKit.proProduct == nil)

                Button {
                    Task {
                        await storeKit.restore()
                        if storeKit.isProUnlocked {
                            onPurchased()
                        }
                    }
                } label: {
                    Text("Restore Purchase")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .disabled(storeKit.isPurchasing)

                Text("Payment processed securely by Apple.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .padding(.top, 2)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(width: 380, height: 520)
        .background(.regularMaterial)
    }

    private var priceLabel: String {
        if storeKit.isPurchasing { return "Processing…" }
        if let product = storeKit.proProduct {
            return "Unlock Pro — \(product.displayPrice)"
        }
        return "Unlock Pro"
    }
}

// MARK: - Feature Row

private struct FeatureRow: View {
    let icon: String
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }
}

#Preview {
    ProPaywallView(storeKit: StoreKitManager.shared, onPurchased: {})
}
