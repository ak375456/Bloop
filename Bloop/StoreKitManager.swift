//
//  StoreKitManager.swift
//  Bloop
//
//  Created by aftab fazal qayum on 05/05/2026.
//

import StoreKit
import SwiftUI
import Combine


@MainActor
final class StoreKitManager: ObservableObject {

    static let shared = StoreKitManager()

    // Must match your Product ID in App Store Connect exactly
    static let proProductID = "menubarpets_pro"

    @Published var isProUnlocked: Bool = false
    @Published var proProduct: Product? = nil
    @Published var isPurchasing: Bool = false
    @Published var errorMessage: String? = nil

    private var transactionListener: Task<Void, Never>? = nil

    private init() {
        // Start listening for transactions immediately
        transactionListener = listenForTransactions()
        Task {
            await loadProducts()
            await checkCurrentEntitlements()
        }
    }

    deinit {
        transactionListener?.cancel()
    }

    // MARK: - Load Products

    func loadProducts() async {
        do {
            let products = try await Product.products(for: [Self.proProductID])
            proProduct = products.first
        } catch {
            errorMessage = "Could not load product: \(error.localizedDescription)"
        }
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product = proProduct else {
            errorMessage = "Product not available. Please try again."
            return
        }

        isPurchasing = true
        errorMessage = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                await transaction.finish()
                isProUnlocked = true
            case .userCancelled:
                break
            case .pending:
                errorMessage = "Purchase is pending approval."
            @unknown default:
                break
            }
        } catch {
            errorMessage = "Purchase failed: \(error.localizedDescription)"
        }

        isPurchasing = false
    }

    // MARK: - Restore

    func restore() async {
        isPurchasing = true
        errorMessage = nil

        do {
            try await AppStore.sync()
            await checkCurrentEntitlements()
        } catch {
            errorMessage = "Restore failed: \(error.localizedDescription)"
        }

        isPurchasing = false
    }

    // MARK: - Check Entitlements

    func checkCurrentEntitlements() async {
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Self.proProductID,
               transaction.revocationDate == nil {
                isProUnlocked = true
                return
            }
        }
    }

    // MARK: - Listen for Transactions (handles renewals, refunds, etc.)

    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    if transaction.productID == Self.proProductID {
                        await MainActor.run {
                            self.isProUnlocked = transaction.revocationDate == nil
                        }
                    }
                }
            }
        }
    }

    // MARK: - Verify Transaction

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let value):
            return value
        }
    }

    enum StoreError: Error {
        case failedVerification
    }
}
