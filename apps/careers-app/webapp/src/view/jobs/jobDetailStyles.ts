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

export const teamColors: Record<string, string> = {
  ENGINEERING: "#3B82F6",
  "CUSTOMER SUCCESS": "#8B5CF6",
  MARKETING: "#10B981",
  SALES: "#EF4444",
  "SALES ENGINEERING": "#F59E0B",
  "PEOPLE OPERATIONS": "#EC4899",
  FINANCE: "#06B6D4",
  "CHANNEL SALES": "#6366F1",
  "DIGITAL TRANSFORMATION": "#14B8A6",
  "BUSINESS OPERATIONS": "#F97316",
};

// The closing block of a job (what WSO2 offers, and its commitment to diversity): a dark card with a blue sheen,
// white headings, orange bullets and light text, in both light and dark mode.
export const offerCardStyles = {
  mt: 4,
  p: { xs: 3, md: 6 },
  borderRadius: "28px",
  background:
    "linear-gradient(115deg, #0B1230 0%, #0E1A3D 34%, #1F4079 60%, #0E1A3D 74%, #0B1230 86%, #1B2A55 100%)",
  fontSize: "1rem",
  lineHeight: "1.7rem",
  letterSpacing: ".01rem",
  "&, & *": { fontFamily: "inherit !important", color: "rgba(255,255,255,0.92) !important" },
  "& h1, & h2, & h3": {
    color: "#ffffff !important",
    fontWeight: "700 !important",
    fontSize: { xs: "1.7rem", md: "2.3rem" },
    lineHeight: { xs: "2.1rem", md: "2.9rem" },
    mt: 0,
    mb: 3,
  },
  "& h2:not(:first-of-type), & h3:not(:first-of-type)": { mt: 5 },
  "& ul": { pl: 2.5, listStyle: "disc", mb: 2 },
  "& li": { mb: 1.75, pl: 0.5, "&::marker": { color: "#ff7a2f", fontSize: "1.1em" } },
  "& p": { mb: 2, letterSpacing: ".012rem" },
  "& strong": { color: "#ffffff !important" },
  "& a": { color: "#ff9a5c !important", textDecoration: "underline" },
} as const;

export const proseStyles = {
  fontSize: "1rem",
  lineHeight: "1.6rem",
  letterSpacing: ".008rem",
  color: "text.primary",
  "&, & *": { fontFamily: "inherit !important", color: "inherit !important" },
  "& a": { color: "#ff6700 !important", textDecoration: "underline" },
  "& h1, & h2, & h3": {
    color: "text.primary",
    fontWeight: 400,
    mt: 3,
    mb: 1.5,
    fontSize: "1.5rem",
    lineHeight: "2.3rem",
  },
  "& h4": { color: "text.primary", fontWeight: 400, fontSize: "1.2rem", lineHeight: "1.8rem" },
  "& ul, & ol": { pl: 2.5 },
  "& li": { mb: 0.75 },
  "& p": { mb: 1.5, letterSpacing: ".018rem" },
  "& strong": { color: "text.primary" },
} as const;
