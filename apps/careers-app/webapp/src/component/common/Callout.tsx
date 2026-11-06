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

import { Box, Stack } from "@wso2/oxygen-ui";
import type { SxProps, Theme } from "@wso2/oxygen-ui";

import { BRAND_TINT } from "@config/brand";

const TONES = {
  brand: { background: BRAND_TINT.faint, border: BRAND_TINT.border },
  success: { background: "rgba(5,150,105,0.12)", border: "#05966930" },
  danger: { background: "rgba(239,68,68,0.1)", border: "#EF444430" },
};

interface CalloutProps {
  tone: keyof typeof TONES;
  // A leading icon; when given, the content sits beside it.
  icon?: React.ReactNode;
  children: React.ReactNode;
  sx?: SxProps<Theme>;
}

// A tinted, bordered panel that draws attention to a message: a prompt, a result or a warning.
const Callout = ({ tone, icon, children, sx }: CalloutProps) => (
  <Box
    sx={[
      {
        p: 2,
        borderRadius: "10px",
        backgroundColor: TONES[tone].background,
        border: `1px solid ${TONES[tone].border}`,
      },
      ...(Array.isArray(sx) ? sx : [sx]),
    ]}
  >
    {icon ? (
      <Stack direction="row" gap={1.5} alignItems="flex-start">
        {icon}
        <Box>{children}</Box>
      </Stack>
    ) : (
      children
    )}
  </Box>
);

export default Callout;
