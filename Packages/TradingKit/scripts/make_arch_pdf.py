from reportlab.lib.pagesizes import letter, landscape
from reportlab.pdfgen import canvas
from reportlab.lib import colors
from reportlab.lib.units import inch
import math

OUT = "algo_trading_macos_architecture_diagrams.pdf"


def draw_box(c, x, y, w, h, title, lines, fill=colors.whitesmoke):
    c.setFillColor(fill)
    c.setStrokeColor(colors.black)
    c.roundRect(x, y, w, h, 10, fill=1, stroke=1)
    c.setFillColor(colors.black)
    c.setFont("Helvetica-Bold", 13)
    c.drawString(x + 10, y + h - 20, title)
    c.setFont("Helvetica", 10)
    ty = y + h - 36
    for line in lines:
        c.drawString(x + 10, ty, line)
        ty -= 13


def arrow(c, x1, y1, x2, y2, label=None):
    c.setStrokeColor(colors.black)
    c.setLineWidth(1.8)
    c.line(x1, y1, x2, y2)
    ang = math.atan2(y2 - y1, x2 - x1)
    ah = 9
    a1 = ang + math.pi * 0.85
    a2 = ang - math.pi * 0.85
    c.line(x2, y2, x2 + ah * math.cos(a1), y2 + ah * math.sin(a1))
    c.line(x2, y2, x2 + ah * math.cos(a2), y2 + ah * math.sin(a2))
    if label:
        c.setFont("Helvetica", 9)
        c.drawString((x1 + x2) / 2 + 3, (y1 + y2) / 2 + 3, label)


c = canvas.Canvas(OUT, pagesize=landscape(letter))
_, H = landscape(letter)

# Page 1: Current component architecture
c.setFont("Helvetica-Bold", 18)
c.drawString(0.55 * inch, H - 0.55 * inch, "AlgoTradingMac - Current Component Architecture")

draw_box(
    c,
    0.55 * inch,
    4.65 * inch,
    3.45 * inch,
    2.4 * inch,
    "MacApp (SwiftUI)",
    [
        "- Shared AppModel + StoreSnapshot binding",
        "- Tabs: Order Ticket, Blotter, Market Watch",
        "- Tabs: Algo Control, Proposals, Logs",
        "- Settings: env, live arming, kill switch",
    ],
    fill=colors.Color(0.91, 0.96, 1.0),
)

draw_box(
    c,
    4.25 * inch,
    4.65 * inch,
    4.1 * inch,
    2.4 * inch,
    "TradingKit (UI-agnostic core)",
    [
        "- Engine actor (lifecycle + safety gates)",
        "- Store actor (event bus + projections)",
        "- Alpaca REST + Trade WS + Market WS",
        "- StrategyRunner + Proposal/Run stores",
        "- ReplayRunner + SimBroker + Bars cache",
    ],
    fill=colors.Color(0.92, 1.0, 0.93),
)

draw_box(
    c,
    8.65 * inch,
    5.65 * inch,
    2.35 * inch,
    1.35 * inch,
    "Alpaca REST",
    [
        "- account/positions/orders/assets",
        "- strict rate limiter at boundary",
    ],
    fill=colors.Color(1.0, 0.95, 0.9),
)

draw_box(
    c,
    8.65 * inch,
    4.9 * inch,
    2.35 * inch,
    0.65 * inch,
    "trade_updates WS",
    [
        "- authoritative order lifecycle",
    ],
    fill=colors.Color(1.0, 0.95, 0.9),
)

draw_box(
    c,
    8.65 * inch,
    3.95 * inch,
    2.35 * inch,
    0.8 * inch,
    "market data WS",
    [
        "- one multiplexed socket",
        "- incremental subs/resubs",
    ],
    fill=colors.Color(1.0, 0.95, 0.9),
)

draw_box(
    c,
    4.25 * inch,
    3.45 * inch,
    4.1 * inch,
    1.0 * inch,
    "Security + Local Control Plane",
    [
        "- Keychain credentials only (no secret logs)",
        "- IPC server: 127.0.0.1 + session token",
        "- Structured audit JSONL in Application Support",
    ],
    fill=colors.Color(1.0, 0.98, 0.85),
)

arrow(c, 3.95 * inch, 4.8 * inch, 4.25 * inch, 4.8 * inch, "state/commands")
arrow(c, 8.35 * inch, 6.2 * inch, 8.65 * inch, 6.2 * inch)
arrow(c, 8.35 * inch, 5.2 * inch, 8.65 * inch, 5.2 * inch)
arrow(c, 8.35 * inch, 4.35 * inch, 8.65 * inch, 4.35 * inch)
c.showPage()

# Page 2: Single order pipeline + safety gates
c.setFont("Helvetica-Bold", 18)
c.drawString(0.55 * inch, H - 0.55 * inch, "Single Order Pipeline (UI + Strategy) and Safety Gates")

draw_box(
    c,
    0.55 * inch,
    5.45 * inch,
    3.0 * inch,
    1.2 * inch,
    "Manual Order Ticket",
    [
        "- user order intent",
    ],
    fill=colors.Color(0.91, 0.96, 1.0),
)

draw_box(
    c,
    0.55 * inch,
    3.95 * inch,
    3.0 * inch,
    1.2 * inch,
    "StrategyRunner",
    [
        "- proposal-backed strategy intents",
    ],
    fill=colors.Color(0.91, 0.96, 1.0),
)

draw_box(
    c,
    3.9 * inch,
    4.55 * inch,
    2.15 * inch,
    1.55 * inch,
    "Validation",
    [
        "- symbol/qty/order type checks",
        "- short/options preflight",
        "- request shaping",
    ],
    fill=colors.Color(0.92, 1.0, 0.93),
)

draw_box(
    c,
    6.35 * inch,
    4.55 * inch,
    2.1 * inch,
    1.55 * inch,
    "Safety Gates",
    [
        "- live disarmed default",
        "- kill switch blocks new/replace",
        "- cancel always allowed",
    ],
    fill=colors.Color(1.0, 0.92, 0.9),
)

draw_box(
    c,
    8.75 * inch,
    4.55 * inch,
    2.35 * inch,
    1.55 * inch,
    "Order Router",
    [
        "- rate-limited REST submit",
        "- cancel/replace",
        "- typed errors + audit",
    ],
    fill=colors.Color(0.92, 1.0, 0.93),
)

draw_box(
    c,
    8.75 * inch,
    2.95 * inch,
    2.35 * inch,
    1.2 * inch,
    "Store Projections",
    [
        "- trade_updates as truth",
        "- open orders/positions/account",
        "- debounced repair refreshes",
    ],
    fill=colors.Color(0.95, 0.95, 0.95),
)

draw_box(
    c,
    5.25 * inch,
    2.95 * inch,
    3.15 * inch,
    1.2 * inch,
    "Replay Path (safe)",
    [
        "- bars cache -> ReplayRunner",
        "- SimBroker synthetic trade updates",
        "- never calls Alpaca trading endpoints",
    ],
    fill=colors.Color(0.94, 0.97, 1.0),
)

arrow(c, 3.55 * inch, 5.95 * inch, 3.9 * inch, 5.35 * inch, "OrderIntent")
arrow(c, 3.55 * inch, 4.45 * inch, 3.9 * inch, 5.05 * inch, "OrderIntent")
arrow(c, 6.05 * inch, 5.35 * inch, 6.35 * inch, 5.35 * inch, "validated")
arrow(c, 8.45 * inch, 5.35 * inch, 8.75 * inch, 5.35 * inch, "allowed")
arrow(c, 9.95 * inch, 4.55 * inch, 9.95 * inch, 4.15 * inch, "events")
arrow(c, 8.4 * inch, 3.55 * inch, 8.75 * inch, 3.55 * inch, "project")
c.showPage()

# Page 3: Lifecycle + reconnect + control plane
c.setFont("Helvetica-Bold", 18)
c.drawString(0.55 * inch, H - 0.55 * inch, "Runtime Lifecycle and Control Plane")

draw_box(
    c,
    0.7 * inch,
    1.2 * inch,
    10.0 * inch,
    5.9 * inch,
    "Startup -> Runtime -> Recovery",
    [
        "1) Build config + read Keychain credentials for selected env",
        "2) Startup reconciliation: fetch account, positions, open orders",
        "3) Connect trade_updates (auth + subscribe), then market data (multiplex)",
        "4) Project stream events into Store snapshots consumed by UI/strategies",
        "5) On disconnect/error: exponential backoff + reconnect + resubscribe",
        "6) Debounced REST repairs: positions on fill, open-orders on lifecycle events",
        "7) Proposal approval gate controls paper runs and strategy starts",
        "8) IPC server starts on loopback with session token for alpaca_agentctl",
        "9) On stop: cancel refreshers, stop streams, stop IPC cleanly",
    ],
    fill=colors.Color(0.96, 0.96, 1.0),
)

c.setFont("Helvetica", 10)
c.drawString(
    0.7 * inch,
    0.85 * inch,
    "Principle: streams are authoritative for state transitions; REST is initialization + bounded repair only.",
)
c.save()

print(f"Wrote {OUT}")
