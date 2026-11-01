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

// Mirrors JobCard's dimensions so the listing doesn't jump/reflow once real
// data replaces it.

import { Box, Skeleton, Stack } from "@mui/material";

const JobCardSkeleton = () => (
  <Box
    sx={{
      height: "100%",
      padding: "30px 28px 28px",
      border: "1px solid",
      borderColor: "divider",
      borderRadius: "14px",
      backgroundColor: "background.glass",
    }}
  >
    <Skeleton variant="rounded" width={90} height={22} sx={{ borderRadius: "999px", mb: 2 }} />
    <Skeleton variant="text" width="80%" height={28} sx={{ mb: 2 }} />
    <Stack direction="row" gap={0.75} sx={{ mb: 2.5 }}>
      <Skeleton variant="rounded" width={70} height={22} sx={{ borderRadius: "999px" }} />
      <Skeleton variant="rounded" width={60} height={22} sx={{ borderRadius: "999px" }} />
    </Stack>
    <Skeleton variant="text" width="40%" height={20} sx={{ ml: "auto", mt: 3 }} />
  </Box>
);

export default JobCardSkeleton;
