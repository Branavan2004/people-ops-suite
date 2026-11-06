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

import { useColorScheme } from "@wso2/oxygen-ui";

export const BRAND_ORANGE = "#ff6700";

// Whether the page is in dark mode, from the library's colour scheme (the system setting when none is chosen).
export const useIsDark = (): boolean => {
  const { mode, systemMode } = useColorScheme();
  return (mode === "system" ? systemMode : mode) === "dark";
};

export const BRAND_TINT = {
  faint: "#ff670010",
  soft: "#ff670018",
  border: "#ff670040",
};

// Side margin of a page by breakpoint (116px on wide screens) and its inner padding.
export const PAGE_MARGIN_X = { xs: 0, md: "48px", lg: "116px" };
export const PAGE_PADDING_X = "15px";

// Text on the brand orange: dark in both modes.
export const ON_ORANGE = "#0B1220";
