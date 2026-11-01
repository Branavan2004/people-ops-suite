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

import { Box, Grid, Skeleton, type Theme } from "@mui/material";

import { PAGE_MARGIN_X, PAGE_PADDING_X, heroColorsOf } from "@config/brand";

// Skeleton of the job page, in the hero's colours.
const heroBackground = (theme: Theme) => heroColorsOf(theme.palette.mode).background;
const skeletonFill = (theme: Theme) => heroColorsOf(theme.palette.mode).skeleton;

const JobDetailSkeleton = () => (
  <Box>
    <Box sx={{ backgroundColor: heroBackground, py: { xs: 5, md: 7 } }}>
      <Box sx={{ mx: PAGE_MARGIN_X, px: PAGE_PADDING_X }}>
        <Grid container spacing={4} alignItems="center">
          <Grid size={{ xs: 12, md: 7 }}>
            <Skeleton
              variant="rounded"
              width={140}
              height={22}
              sx={{ borderRadius: "999px", mb: 2, bgcolor: skeletonFill }}
            />
            <Skeleton variant="text" width="70%" height={52} sx={{ mb: 3, bgcolor: skeletonFill }} />
            <Skeleton
              variant="rounded"
              width={150}
              height={44}
              sx={{ borderRadius: "999px", bgcolor: skeletonFill }}
            />
          </Grid>
          <Grid size={{ xs: 12, md: 5 }}>
            <Skeleton variant="rounded" height={180} sx={{ borderRadius: "16px", bgcolor: skeletonFill }} />
          </Grid>
        </Grid>
      </Box>
    </Box>
    <Box sx={{ mx: PAGE_MARGIN_X, px: PAGE_PADDING_X, py: { xs: 5, md: 7 } }}>
      <Skeleton variant="text" height={24} sx={{ mb: 1 }} />
      <Skeleton variant="text" height={24} sx={{ mb: 1 }} />
      <Skeleton variant="text" height={24} width="80%" />
    </Box>
  </Box>
);

export default JobDetailSkeleton;
