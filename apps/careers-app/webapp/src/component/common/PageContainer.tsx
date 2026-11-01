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

import { Box } from "@mui/material";

import { PAGE_MARGIN_X, PAGE_PADDING_X } from "@config/brand";

// Page content column with the side margin and padding.
const PageContainer = ({ children }: { children: React.ReactNode }) => (
  <Box sx={{ mx: PAGE_MARGIN_X, px: PAGE_PADDING_X, pt: { xs: 2.5, md: 3 }, pb: { xs: 4, md: 5 } }}>
    {children}
  </Box>
);

export default PageContainer;
