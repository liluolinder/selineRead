package dev.canghui.android;

/** Android-only system-bar policy exposed by {@link CangHuiSurfaceActivity}. */
public enum CangHuiSystemBarsMode {
    /** Status and navigation bars are visible and content avoids their insets. */
    VISIBLE,
    /** Bars remain visible while content is allowed to extend behind them. */
    EDGE_TO_EDGE,
    /** Bars are hidden and may be revealed transiently with a system swipe. */
    IMMERSIVE_STICKY
}
