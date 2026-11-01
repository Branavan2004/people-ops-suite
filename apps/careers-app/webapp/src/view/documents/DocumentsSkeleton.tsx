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

import { Box, Card, Skeleton, Stack } from "@mui/material";

import { cardSx } from "@utils/styles";
import { STEPS } from "@view/documents/documentFiles";

// The shape of the form while the page loads.
const DocumentsSkeleton = () => (
  <Card elevation={0} sx={cardSx} aria-busy="true" aria-label="Loading your documents form">
    <Stack direction="row" gap={2} sx={{ p: 3, borderBottom: "1px solid", borderColor: "divider" }}>
      {STEPS.map((step) => (
        <Skeleton key={step} variant="rounded" width={110} height={28} sx={{ borderRadius: "999px" }} />
      ))}
    </Stack>
    <Stack gap={2.5} sx={{ p: 3 }}>
      {[0, 1, 2, 3].map((row) => (
        <Box key={row}>
          <Skeleton variant="text" width={140} height={20} />
          <Skeleton variant="rounded" height={44} />
        </Box>
      ))}
    </Stack>
    <Stack direction="row" justifyContent="space-between" sx={{ p: 3, borderTop: "1px solid", borderColor: "divider" }}>
      <Skeleton variant="rounded" width={80} height={36} sx={{ borderRadius: "999px" }} />
      <Skeleton variant="rounded" width={100} height={36} sx={{ borderRadius: "999px" }} />
    </Stack>
  </Card>
);

export default DocumentsSkeleton;
