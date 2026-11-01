// Copyright (c) 2026 WSO2 LLC. (https://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import { type PaletteMode } from "@mui/material";

import { BRAND_ORANGE } from "@config/brand";

declare module "@mui/material/styles" {
  interface TypeBackground {
    // The see-through surface of cards in dark mode; white in light mode.
    glass: string;
  }
}

// WSO2 brand palette
const wso2 = {
  orange: {
    400: "#FB923C",
    500: BRAND_ORANGE,
    600: "#EA6A00",
    700: "#C2570A",
  },
};

// Solid dark paper, so dialogs, menus and every other overlay built on Paper stay readable.
const DARK_PAPER = "#131d33";

export const themeSettings = (mode: PaletteMode) => {
  const isDark = mode === "dark";
  // Dark mode follows the Oxygen UI WSO2 theme; both modes use the brand orange.
  const brand = BRAND_ORANGE;

  return {
    palette: {
      mode,
      primary: {
        main: brand,
        light: wso2.orange[400],
        dark: wso2.orange[700],
        contrastText: "#ffffff",
      },
      secondary: {
        main: isDark ? "#5CD1FF" : "#0EA5E9",
        light: "#38BDF8",
        dark: "#0284C7",
        contrastText: "#ffffff",
      },
      error: { main: "#EF4444", light: "#F87171", dark: "#DC2626" },
      warning: { main: "#F59E0B", light: "#FCD34D", dark: "#D97706" },
      info: { main: "#3B82F6", light: "#60A5FA", dark: "#2563EB" },
      success: { main: "#10B981", light: "#34D399", dark: "#059669" },
      background: {
        default: isDark ? "#0f172a" : "#FFFFFF",
        paper: isDark ? DARK_PAPER : "#FFFFFF",
        glass: isDark ? "#00000026" : "#FFFFFF",
      },
      divider: isDark ? "rgba(255,255,255,0.12)" : "#e2e5ec",
      text: {
        primary: isDark ? "#FFFFFF" : "#17223A",
        secondary: isDark ? "rgba(255,255,255,0.7)" : "#1F2937",
        // Lighter than secondary, so disabled fields and labels still look disabled.
        disabled: isDark ? "rgba(255,255,255,0.38)" : "#9CA3AF",
      },
    },

    typography: {
      fontFamily: '"Inter Variable", Inter, sans-serif',
      fontSize: 14,
      h1: { fontSize: "2.5rem", fontWeight: 800, lineHeight: 1.2 },
      h2: { fontSize: "2rem", fontWeight: 700, lineHeight: 1.25 },
      h3: { fontSize: "1.75rem", fontWeight: 700, lineHeight: 1.3 },
      h4: { fontSize: "1.5rem", fontWeight: 700, lineHeight: 1.35 },
      h5: { fontSize: "1.25rem", fontWeight: 600, lineHeight: 1.4 },
      h6: { fontSize: "1.1rem", fontWeight: 600, lineHeight: 1.4 },
      body1: { fontSize: "1rem", lineHeight: 1.6, letterSpacing: ".018rem" },
      body2: { fontSize: "0.875rem", lineHeight: 1.6 },
      caption: { fontSize: "0.75rem", lineHeight: 1.5 },
      overline: { fontSize: "0.6875rem", fontWeight: 600, letterSpacing: "0.08em", textTransform: "uppercase" as const },
    },

    shape: { borderRadius: 8 },
    spacing: 8,

    components: {
      MuiCssBaseline: {
        styleOverrides: {
          ":focus-visible": { outline: `2px solid ${brand}`, outlineOffset: "2px" },
          // Oxygen UI dark page gradient.
          ...(isDark && {
            body: {
              backgroundAttachment: "fixed",
              backgroundImage:
                "radial-gradient(circle at 50% 25%, #233248 0%, rgba(153, 170, 205, 0) 40%)," +
                "radial-gradient(circle at 500% 90%, #3b4e69 0%, rgba(153, 170, 205, 0) 20%)," +
                "radial-gradient(circle at 100% 125%, #3b4e69 0%, rgba(153, 170, 205, 0) 20%)," +
                "linear-gradient(120deg, #060812 100%)",
              backgroundBlendMode: "screen",
            },
          }),
        },
      },
      // Dark mode removes the lighter overlay MUI adds to raised paper.
      ...(isDark && { MuiPaper: { styleOverrides: { root: { backgroundImage: "none" } } } }),
      MuiButton: {
        styleOverrides: {
          root: {
            textTransform: "none" as const,
            borderRadius: 8,
            fontWeight: 600,
            boxShadow: "none",
            "&:hover": { boxShadow: "none" },
          },
          contained: {
            backgroundColor: brand,
            "&:hover": { backgroundColor: wso2.orange[600] },
            "&.Mui-disabled": isDark
              ? { backgroundColor: "rgba(255,103,0,0.22)", color: "rgba(232,238,251,0.55)" }
              : { backgroundColor: "#FFD4A8", color: "#fff" },
          },
        },
      },
      // Tooltips close without a fade-out.
      MuiTooltip: {
        defaultProps: { slotProps: { transition: { timeout: 0 } } },
      },
      MuiCard: {
        styleOverrides: {
          root: {
            borderRadius: 12,
            // Cards are the glass surfaces in dark mode: see-through and blurred.
            ...(isDark && {
              backgroundColor: "#00000026",
              backdropFilter: "blur(16px)",
              WebkitBackdropFilter: "blur(16px)",
            }),
            boxShadow: isDark
              ? "0 1px 3px rgba(0,0,0,0.4)"
              : "0 1px 3px rgba(0,0,0,0.06), 0 1px 2px rgba(0,0,0,0.04)",
          },
        },
      },
      MuiChip: {
        styleOverrides: {
          root: { borderRadius: 6, fontWeight: 500 },
        },
      },
      MuiTextField: {
        styleOverrides: {
          root: {
            "& .MuiOutlinedInput-root": { borderRadius: 8 },
          },
        },
      },
      // Brand outline on hover and focus for outlined inputs.
      MuiOutlinedInput: {
        styleOverrides: {
          root: {
            "&:not(.Mui-error):not(.Mui-disabled):hover .MuiOutlinedInput-notchedOutline": {
              borderColor: brand,
            },
            "&.Mui-focused:not(.Mui-error) .MuiOutlinedInput-notchedOutline": {
              borderColor: brand,
            },
          },
        },
      },
      MuiInputLabel: {
        styleOverrides: {
          root: {
            "&.Mui-focused:not(.Mui-error)": { color: brand },
          },
        },
      },
    },

    breakpoints: {
      values: { xs: 0, sm: 600, md: 960, lg: 1280, xl: 1920 },
    },
  };
};
