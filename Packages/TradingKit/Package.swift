// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "TradingKit",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .library(
            name: "TradingKit",
            targets: ["TradingKit"]
        ),
        .executable(
            name: "alpaca_smoke",
            targets: ["alpaca_smoke"]
        ),
        .executable(
            name: "alpaca_trade_updates_smoke",
            targets: ["alpaca_trade_updates_smoke"]
        ),
        .executable(
            name: "alpaca_marketdata_smoke",
            targets: ["alpaca_marketdata_smoke"]
        ),
        .executable(
            name: "alpaca_agentctl",
            targets: ["alpaca_agentctl"]
        ),
        .executable(
            name: "alpaca_analyst_worker",
            targets: ["alpaca_analyst_worker"]
        ),
        .executable(
            name: "fmp_tier1_probe",
            targets: ["fmp_tier1_probe"]
        ),
        .executable(
            name: "telegram_bridge_smoke",
            targets: ["telegram_bridge_smoke"]
        ),
        .executable(
            name: "pm_reasoning_smoke",
            targets: ["pm_reasoning_smoke"]
        ),
        .executable(
            name: "anthropic_messages_smoke",
            targets: ["anthropic_messages_smoke"]
        ),
    ],
    targets: [
        .target(
            name: "TradingKit",
            linkerSettings: [
                .linkedFramework("Security"),
                .linkedFramework("LocalAuthentication"),
                .linkedFramework("Network"),
                .linkedLibrary("sqlite3")
            ]
        ),
        .executableTarget(
            name: "alpaca_smoke",
            dependencies: ["TradingKit"]
        ),
        .executableTarget(
            name: "alpaca_trade_updates_smoke",
            dependencies: ["TradingKit"]
        ),
        .executableTarget(
            name: "alpaca_marketdata_smoke",
            dependencies: ["TradingKit"]
        ),
        .executableTarget(
            name: "alpaca_agentctl",
            dependencies: ["TradingKit"]
        ),
        .executableTarget(
            name: "alpaca_analyst_worker",
            dependencies: ["TradingKit"]
        ),
        .executableTarget(
            name: "fmp_tier1_probe",
            dependencies: ["TradingKit"]
        ),
        .executableTarget(
            name: "telegram_bridge_smoke",
            dependencies: ["TradingKit"]
        ),
        .executableTarget(
            name: "pm_reasoning_smoke",
            dependencies: ["TradingKit"]
        ),
        .executableTarget(
            name: "anthropic_messages_smoke",
            dependencies: ["TradingKit"]
        ),
        .testTarget(
            name: "TradingKitTests",
            dependencies: ["TradingKit", "alpaca_agentctl"]
        ),
    ]
)
