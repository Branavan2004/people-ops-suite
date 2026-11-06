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

import { Box, LinearProgress, Typography } from "@wso2/oxygen-ui";

interface CenteredSpinnerProps {
  py?: number;
}

// The progress bar shown while a page's content is being fetched.
const CenteredSpinner = ({ py = 8 }: CenteredSpinnerProps) => (
  <Box sx={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 2, py }}>
    <LinearProgress color="primary" sx={{ width: { xs: "70%", sm: 530 }, borderRadius: 1 }} />
    <Typography variant="body2" color="text.secondary">
      Loading...
    </Typography>
  </Box>
);

export default CenteredSpinner;
