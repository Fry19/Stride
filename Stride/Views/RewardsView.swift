import StrideCore
import SwiftUI

struct RewardsView: View {
    @Environment(AppModel.self) private var model
    @State private var confirming: Reward?
    @State private var justRedeemed: Reward?
    @State private var showingAdd = false

    private static let ideas = [
        RewardIdea(name: "Fancy coffee", cost: 300),
        RewardIdea(name: "New audiobook", cost: 800),
        RewardIdea(name: "Movie night", cost: 1_200),
        RewardIdea(name: "New walking shoes", cost: 6_000),
    ]

    var body: some View {
        let summary = model.summary
        let rewards = model.state.rewards
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("BALANCE")
                            .font(.caption.weight(.bold))
                            .tracking(1.2)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 10) {
                            CoinIcon(size: 34)
                            Text(summary.balance.formatted())
                                .font(.system(size: 52, weight: .black))
                                .fontWidth(.compressed)
                                .monospacedDigit()
                                .contentTransition(.numericText(value: Double(summary.balance)))
                        }
                        Text("\(summary.earnedCoins.formatted()) earned · \(summary.spentCoins.formatted()) spent")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                    if model.showsSampleDataBanner {
                        SampleDataBanner()
                    }
                }

                Section {
                    if rewards.isEmpty {
                        Text("Pick treats you'd really enjoy and give each a coin price. Tap an idea to add it, or use + to make your own.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        ForEach(Self.ideas) { idea in
                            Button {
                                model.addReward(name: idea.name, cost: idea.cost)
                            } label: {
                                HStack {
                                    Label(idea.name, systemImage: "plus.circle")
                                    Spacer()
                                    CoinAmount(value: idea.cost)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        ForEach(rewards) { reward in
                            RewardRow(reward: reward, balance: summary.balance, canRedeem: model.canRedeem(reward)) {
                                confirming = reward
                            }
                        }
                        .onDelete { offsets in
                            for reward in offsets.map({ rewards[$0] }) {
                                model.deleteReward(reward)
                            }
                        }
                    }
                } header: {
                    Text("Your rewards")
                } footer: {
                    if !rewards.isEmpty {
                        Text("Swipe left on a reward to remove it.")
                    }
                }

                Section("How you earn coins") {
                    EarnRow(text: "Every \(RewardRules.stepsPerCoin) steps", amount: 1)
                    EarnRow(text: "Hitting your daily goal", amount: RewardRules.goalBonus)
                    EarnRow(text: "Each badge", amount: nil)
                }

                if !model.state.redemptions.isEmpty {
                    Section("Redeemed") {
                        ForEach(model.state.redemptions.reversed()) { redemption in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(redemption.rewardName)
                                    Text(redemption.date.formatted(date: .abbreviated, time: .omitted))
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                CoinAmount(value: redemption.cost, prefix: "−")
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Rewards")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAdd = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add reward")
                }
            }
            .sheet(isPresented: $showingAdd) {
                AddRewardView()
            }
            .confirmationDialog(
                confirming.map { "Spend \(StrideFormat.coins($0.cost)) on \($0.name)?" } ?? "",
                isPresented: isConfirming,
                titleVisibility: .visible,
                presenting: confirming
            ) { reward in
                Button("Redeem \(reward.name)") {
                    if model.redeem(reward) {
                        justRedeemed = reward
                    }
                }
            } message: { reward in
                Text("You'll have \(StrideFormat.coins(summary.balance - reward.cost)) left.")
            }
            .alert(
                "Enjoy it!",
                isPresented: isCelebratingRedemption,
                presenting: justRedeemed
            ) { _ in
                Button("Thanks") {}
            } message: { reward in
                Text("You earned your \(reward.name.lowercased()).")
            }
            .sensoryFeedback(.success, trigger: justRedeemed)
        }
    }

    private var isConfirming: Binding<Bool> {
        Binding(get: { confirming != nil }, set: { if !$0 { confirming = nil } })
    }

    private var isCelebratingRedemption: Binding<Bool> {
        Binding(get: { justRedeemed != nil }, set: { if !$0 { justRedeemed = nil } })
    }
}

private struct RewardIdea: Identifiable {
    let name: String
    let cost: Int

    var id: String { name }
}

private struct RewardRow: View {
    let reward: Reward
    let balance: Int
    let canRedeem: Bool
    let redeem: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(reward.name)
                    .font(.body.weight(.semibold))
                Spacer()
                CoinAmount(value: reward.cost)
                    .font(.subheadline.weight(.semibold))
            }
            HStack(spacing: 12) {
                ProgressView(value: min(1, Double(max(balance, 0)) / Double(max(reward.cost, 1))))
                    .tint(canRedeem ? Color.pine : Color.coin)
                if canRedeem {
                    Button("Redeem", action: redeem)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                } else {
                    Text("\(max(reward.cost - balance, 0).formatted()) to go")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
        .padding(.vertical, 4)
    }
}

private struct EarnRow: View {
    let text: String
    let amount: Int?

    var body: some View {
        HStack {
            Text(text)
            Spacer()
            if let amount {
                CoinAmount(value: amount, prefix: "+")
                    .foregroundStyle(.secondary)
            } else {
                Text("10 to 500")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct AddRewardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var cost = 500

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var estimate: String {
        let perGoalDay = model.goal / RewardRules.stepsPerCoin + RewardRules.goalBonus
        let days = Int((Double(cost) / Double(max(perGoalDay, 1))).rounded(.up))
        return "About \(StrideFormat.days(days)) of hitting your \(model.goal.formatted())-step goal."
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Reward, like a fancy coffee", text: $name)
                    HStack {
                        Text("Price")
                        Spacer()
                        TextField("Coins", value: $cost, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 120)
                        CoinIcon()
                    }
                } footer: {
                    Text(estimate)
                }
            }
            .navigationTitle("New reward")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        model.addReward(name: trimmedName, cost: cost)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty || cost < 1)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
