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

import type { PreLoaderProps } from "@/types/types";

const PreLoader = (props: PreLoaderProps) => {
  return (
    <Box
      sx={{
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        justifyContent: "center",
        height: "100vh",
        gap: 2,
        background: (theme) => theme.palette.background.default,
      }}
    >
      {props.isLoading && (
        <LinearProgress sx={{ width: "200px", borderRadius: 1 }} color="primary" />
      )}
      {props.message && (
        <Typography
          variant="body2"
          sx={{ color: "text.secondary", fontWeight: 500 }}
        >
          {props.message}
        </Typography>
      )}
    </Box>
  );
};

export default PreLoader;
