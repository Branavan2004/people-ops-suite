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

import type { Theme } from "@mui/material";

export const BRAND_ORANGE = "#ff6700";

// Orange for text; the darker shade on the light theme to meet contrast.
export const orangeTextOf = (theme: Theme) =>
  theme.palette.mode === "dark" ? theme.palette.primary.main : theme.palette.primary.dark;

export const BRAND_TINT = {
  faint: "#ff670010",
  soft: "#ff670018",
  border: "#ff670040",
};

// Side margin of a page by breakpoint (116px on wide screens) and its inner padding.
export const PAGE_MARGIN_X = { xs: 0, md: "48px", lg: "116px" };
export const PAGE_PADDING_X = "15px";
// The side margin as a negative value.
export const PAGE_PULL_LEFT = { xs: 0, md: "-48px", lg: "-116px" };

// Text on the brand orange: dark in both modes.
export const ON_ORANGE = "#0B1220";

// Job page hero colours for each theme mode, also used by its skeleton.
const HERO_COLORS = {
  dark: {
    background: "#0f172a",
    gridLine: "rgba(255,255,255,0.05)",
    outline: "rgba(255,255,255,0.2)",
    orangeGlow: "rgba(255,115,0,0.38)",
    blueGlow: "rgba(60,90,160,0.35)",
    backButtonBorder: "rgba(255,255,255,0.8)",
    backButtonFill: "rgba(255,255,255,0.12)",
    circleBorder: "rgba(255,255,255,0.25)",
    circleIcon: "rgba(255,255,255,0.7)",
    skeleton: "rgba(255,255,255,0.08)",
  },
  light: {
    background: "#F6F7FA",
    gridLine: "rgba(23,34,58,0.06)",
    outline: "rgba(23,34,58,0.2)",
    orangeGlow: "rgba(255,115,0,0.2)",
    blueGlow: "rgba(60,90,160,0.16)",
    backButtonBorder: "rgba(23,34,58,0.6)",
    backButtonFill: "rgba(255,255,255,0.8)",
    circleBorder: "rgba(23,34,58,0.25)",
    circleIcon: "#6B7280",
    skeleton: "rgba(23,34,58,0.08)",
  },
} as const;

export const heroColorsOf = (mode: "light" | "dark") => HERO_COLORS[mode];
