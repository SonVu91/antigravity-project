import os
from pathlib import Path
from typing import List, Dict, Any, Optional
import matplotlib
matplotlib.use("Agg")  # Headless backend
import matplotlib.pyplot as plt
import matplotlib.patches as patches
import numpy as np
from datetime import datetime

CHART_DIR = Path("data/charts")
CHART_DIR.mkdir(parents=True, exist_ok=True)


def generate_mini_chart(
    candles: List[Dict[str, Any]],
    symbol: str,
    action: str = "BUY",
    entry_price: float = 0.0,
    stop_loss: float = 0.0,
    take_profit: float = 0.0,
) -> Optional[str]:
    """
    Generate an aesthetic financial chart for Telegram alerts.
    Annotates Entry Price, Stop Loss, and Take Profit levels.
    """
    if not candles or len(candles) < 5:
        return None

    try:
        closes = [c["close"] for c in candles[-30:]]
        times = list(range(len(closes)))

        plt.style.use("dark_background")
        fig, ax = plt.subplots(figsize=(8, 4), dpi=120)

        line_color = "#00FFA3" if action == "BUY" else ("#FF3366" if action == "SELL" else "#3399FF")
        ax.plot(times, closes, color=line_color, linewidth=2.0, label=f"{symbol} Price")
        ax.fill_between(times, closes, min(closes) * 0.995, color=line_color, alpha=0.15)

        if entry_price > 0:
            ax.axhline(entry_price, color="#FFFF00", linestyle="--", alpha=0.8, label=f"Entry: {entry_price:.4f}")
        if take_profit > 0:
            ax.axhline(take_profit, color="#00FFA3", linestyle=":", alpha=0.8, label=f"TP: {take_profit:.4f}")
        if stop_loss > 0:
            ax.axhline(stop_loss, color="#FF3366", linestyle=":", alpha=0.8, label=f"SL: {stop_loss:.4f}")

        ax.set_title(f"AI Sentinel Signal: {symbol} [{action}]", fontsize=12, fontweight="bold", color="#FFFFFF")
        ax.grid(True, linestyle="--", alpha=0.25)
        ax.legend(loc="upper left", fontsize=8, facecolor="#1a1a1a", edgecolor="#333333")

        filename = CHART_DIR / f"signal_{symbol.replace('/', '_')}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"
        plt.tight_layout()
        plt.savefig(filename, dpi=120)
        plt.close(fig)
        return str(filename)
    except Exception as e:
        return None


def generate_sd_chart(
    candles: List[Dict[str, Any]],
    symbol: str,
    timeframe: str = "4h",
    zones: Optional[List[Any]] = None,
    signal: Optional[Any] = None,
    max_candles: int = 60,
) -> Optional[str]:
    """
    Generate a professional Dark Theme Candlestick chart with Supply & Demand zones
    styled similarly to FimiSDbot.
    Features:
    - Candlesticks with wicks (Green #00E676 / Red #FF5252)
    - Volume bars in bottom panel
    - Supply Zones (Red/Coral shaded boxes with price tags)
    - Demand Zones (Blue/Teal shaded boxes with price tags)
    - Watermark and header with Symbol and Timeframe
    """
    if not candles or len(candles) < 5:
        return None

    try:
        # Display the most recent `max_candles`
        display_candles = candles[-max_candles:]
        n = len(display_candles)
        offset = len(candles) - n  # Offset from original candle list

        plt.style.use("dark_background")
        fig = plt.figure(figsize=(10, 6), dpi=140, facecolor="#0B0E14")
        gs = fig.add_gridspec(2, 1, height_ratios=[4, 1], hspace=0.08)

        ax_price = fig.add_subplot(gs[0, 0], facecolor="#0B0E14")
        ax_vol = fig.add_subplot(gs[1, 0], facecolor="#0B0E14", sharex=ax_price)

        # Draw Candlesticks & Volume
        bull_color = "#00FFA3"
        bear_color = "#FF3366"
        candle_width = 0.65

        highs = [c["high"] for c in display_candles]
        lows = [c["low"] for c in display_candles]
        volumes = [c.get("volume", 0.0) for c in display_candles]

        for i, c in enumerate(display_candles):
            o = c["open"]
            h = c["high"]
            l = c["low"]
            cl = c["close"]
            v = c.get("volume", 0.0)

            is_bull = cl >= o
            color = bull_color if is_bull else bear_color

            # Draw candle wick
            ax_price.vlines(i, l, h, color=color, linewidth=1.1, alpha=0.9)

            # Draw candle body
            body_bottom = min(o, cl)
            body_height = max(abs(cl - o), (max(highs) - min(lows)) * 0.002)
            rect = patches.Rectangle(
                (i - candle_width / 2.0, body_bottom),
                candle_width,
                body_height,
                facecolor=color,
                edgecolor=color,
                linewidth=0.8,
                alpha=0.95,
            )
            ax_price.add_patch(rect)

            # Draw volume bar
            ax_vol.bar(i, v, width=candle_width, color=color, alpha=0.55)

        # Render Supply and Demand Zones
        if zones:
            for z in zones:
                z_type = getattr(z, "zone_type", None)
                z_type_str = z_type.value if hasattr(z_type, "value") else str(z_type)
                proximal = float(z.proximal)
                distal = float(z.distal)
                status = getattr(z, "status", None)
                status_str = status.value if hasattr(status, "value") else str(status)

                # Skip completely violated zones if not visible
                if status_str == "VIOLATED":
                    continue

                z_bottom = min(proximal, distal)
                z_top = max(proximal, distal)
                z_height = z_top - z_bottom

                # Determine starting x coordinate
                creation_idx = getattr(z, "creation_index", 0) - offset
                x_start = max(0, creation_idx)
                x_width = (n - 1 + 2) - x_start

                if "SUPPLY" in z_type_str.upper():
                    zone_color = "#FF3366" if status_str == "FRESH" else "#E57373"
                    edge_color = "#FF1744"
                    alpha_val = 0.28 if status_str == "FRESH" else 0.16
                    tag_prefix = "Supply"
                else:
                    zone_color = "#00C853" if status_str == "FRESH" else "#29B6F6"
                    edge_color = "#00E676"
                    alpha_val = 0.28 if status_str == "FRESH" else 0.16
                    tag_prefix = "Demand"

                # Draw zone rectangle extending to the right edge
                zone_rect = patches.Rectangle(
                    (x_start, z_bottom),
                    x_width,
                    z_height,
                    facecolor=zone_color,
                    edgecolor=edge_color,
                    linewidth=1.0,
                    linestyle="--",
                    alpha=alpha_val,
                )
                ax_price.add_patch(zone_rect)

                # Price label at the right boundary
                label_y = z_top if "SUPPLY" in z_type_str.upper() else z_bottom
                ax_price.text(
                    n - 0.5,
                    label_y,
                    f" {tag_prefix}: {label_y:.4f}",
                    color="#FFFFFF",
                    fontsize=8,
                    fontweight="bold",
                    verticalalignment="center",
                    bbox=dict(boxstyle="round,pad=0.2", facecolor="#1E222D", edgecolor=edge_color, alpha=0.85),
                )

        # Plot Signal Markers (if present)
        if signal and hasattr(signal, "entry_price") and signal.entry_price > 0 and signal.action in ["BUY", "SELL"]:
            entry_p = signal.entry_price
            sl_p = signal.stop_loss
            tp_p = signal.take_profit
            action = signal.action

            ax_price.axhline(entry_p, color="#FFFF00", linestyle="-.", linewidth=1.2, alpha=0.85)
            ax_price.text(
                0.5, entry_p, f" Entry ({action}): {entry_p:.4f}",
                color="#FFFF00", fontsize=8, fontweight="bold",
                bbox=dict(boxstyle="round,pad=0.2", facecolor="#1a1a1a", edgecolor="#FFFF00", alpha=0.8),
            )

            if sl_p > 0:
                ax_price.axhline(sl_p, color="#FF1744", linestyle=":", linewidth=1.2, alpha=0.85)
                ax_price.text(
                    0.5, sl_p, f" SL: {sl_p:.4f}",
                    color="#FF1744", fontsize=8, fontweight="bold",
                    bbox=dict(boxstyle="round,pad=0.2", facecolor="#1a1a1a", edgecolor="#FF1744", alpha=0.8),
                )

            if tp_p > 0:
                ax_price.axhline(tp_p, color="#00FFA3", linestyle=":", linewidth=1.2, alpha=0.85)
                ax_price.text(
                    0.5, tp_p, f" TP: {tp_p:.4f}",
                    color="#00FFA3", fontsize=8, fontweight="bold",
                    bbox=dict(boxstyle="round,pad=0.2", facecolor="#1a1a1a", edgecolor="#00FFA3", alpha=0.8),
                )

        # Current Price horizontal line
        curr_price = display_candles[-1]["close"]
        ax_price.axhline(curr_price, color="#64B5F6", linestyle="-", linewidth=0.9, alpha=0.7)

        # Header Titles & Watermarks
        tf_display = timeframe.upper()
        if tf_display in ["1D", "D1"]:
            tf_display = "Daily"
        elif tf_display in ["4H", "H4"]:
            tf_display = "H4"
        elif tf_display in ["1H", "H1"]:
            tf_display = "H1"
        elif tf_display in ["15M", "M15"]:
            tf_display = "15m"

        title_text = f"{symbol.replace('/', ',')}, {tf_display}"
        ax_price.text(
            0.02, 0.94, title_text,
            transform=ax_price.transAxes,
            color="#FFFFFF", fontsize=13, fontweight="bold",
            bbox=dict(boxstyle="square,pad=0.3", facecolor="#161B22", edgecolor="#30363D", alpha=0.85),
        )

        ax_price.text(
            0.02, 0.86, f"Price: {curr_price:.4f} | S&D Sentinel Engine",
            transform=ax_price.transAxes,
            color="#8B949E", fontsize=8,
        )

        # Watermark at bottom left
        ax_vol.text(
            0.02, 0.2, "Supply & Demand | Antigravity AI",
            transform=ax_vol.transAxes,
            color="#484F58", fontsize=7, fontweight="bold",
        )

        # Grids and axes styling
        ax_price.set_xlim(-1, n + 5)
        price_min = min(lows) * 0.99
        price_max = max(highs) * 1.01
        ax_price.set_ylim(price_min, price_max)

        ax_price.grid(True, linestyle=":", color="#21262D", alpha=0.7)
        ax_vol.grid(True, linestyle=":", color="#21262D", alpha=0.5)

        ax_price.tick_params(colors="#8B949E", labelsize=8)
        ax_vol.tick_params(colors="#8B949E", labelsize=7)

        # Format price ticks on right axis
        ax_price.yaxis.tick_right()
        ax_vol.yaxis.tick_right()
        plt.setp(ax_price.get_xticklabels(), visible=False)

        # Generate unique filename
        clean_sym = symbol.replace("/", "_").replace(":", "_")
        filename = CHART_DIR / f"sd_{clean_sym}_{timeframe}_{datetime.now().strftime('%Y%m%d_%H%M%S')}.png"

        plt.subplots_adjust(left=0.04, right=0.92, top=0.96, bottom=0.06)
        plt.savefig(filename, dpi=140, facecolor=fig.get_facecolor(), edgecolor="none")
        plt.close(fig)
        return str(filename)
    except Exception as e:
        import logging
        logging.getLogger("Charts").error(f"Error generating S&D chart: {e}", exc_info=True)
        return None
