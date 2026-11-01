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

import { Box, Stack, Typography } from "@mui/material";

import { type HistoryEntry, formatDate, formatDateTime } from "@view/applications/applicationHelpers";
import SectionTitle from "@view/applications/components/SectionTitle";

interface ProgressHistoryProps {
  entries: HistoryEntry[];
}

// What happened to the application, newest first.
const ProgressHistory = ({ entries }: ProgressHistoryProps) => {
  if (entries.length === 0) return null;

  return (
    <Box sx={{ mb: 2 }}>
      <SectionTitle>PROGRESS HISTORY</SectionTitle>
      <Stack gap={1}>
        {[...entries].reverse().map((entry, index) => (
          <Stack key={`${entry.label}-${entry.date}-${index}`} direction="row" gap={2}>
            <Typography fontSize="0.85rem" color="text.secondary" sx={{ minWidth: 150 }}>
              {entry.date ? (entry.withTime ? formatDateTime(entry.date) : formatDate(entry.date)) : "Date not recorded"}
            </Typography>
            <Box>
              <Typography fontSize="0.9rem" fontWeight={600}>
                {entry.label}
              </Typography>
              {entry.detail && (
                <Typography fontSize="0.8rem" color="text.secondary">
                  {entry.detail}
                </Typography>
              )}
            </Box>
          </Stack>
        ))}
      </Stack>
    </Box>
  );
};

export default ProgressHistory;
