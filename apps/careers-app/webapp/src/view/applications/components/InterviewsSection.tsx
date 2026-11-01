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

import { Box, Button, Chip, Link, Stack, Typography } from "@mui/material";
import { ExternalLink } from "lucide-react";

import type { ApplicationInterview } from "@/types/types";
import { BRAND_TINT } from "@config/brand";
import { formatDateTime, interviewChip, interviewIcon } from "@view/applications/applicationHelpers";
import SectionTitle from "@view/applications/components/SectionTitle";

interface InterviewsSectionProps {
  interviews: ApplicationInterview[];
}

const InterviewsSection = ({ interviews }: InterviewsSectionProps) => {
  if (interviews.length === 0) return null;

  return (
    <Box sx={{ mb: 3 }}>
      <SectionTitle>INTERVIEWS</SectionTitle>
      <Stack gap={1.25}>
        {interviews.map((interview) => {
          const Icon = interviewIcon[interview.mode];
          const chip = interviewChip[interview.status];
          const isLink = interview.mode === "Video" && /^https?:\/\//i.test(interview.location);
          return (
            <Box
              key={interview.id}
              sx={{
                display: "flex",
                alignItems: "center",
                justifyContent: "space-between",
                flexWrap: "wrap",
                gap: 1,
                p: 2,
                borderRadius: "10px",
                border: "1px solid",
                borderColor: "primary.main",
                transition: "border-color 0.15s, background-color 0.15s, box-shadow 0.15s, transform 0.15s",
                // Lift and orange tint on hover for a box with a meeting link.
                ...(isLink && {
                  "&:hover": {
                    backgroundColor: BRAND_TINT.faint,
                    boxShadow: "0 8px 20px -10px rgb(255 103 0 / 45%)",
                    transform: "translateY(-2px)",
                  },
                }),
              }}
            >
              <Stack direction="row" gap={1.5} alignItems="center">
                <Box sx={{ color: "primary.main", display: "flex" }}>
                  <Icon size={18} />
                </Box>
                <Box>
                  <Typography fontWeight={600} fontSize="0.95rem">
                    {interview.round}
                  </Typography>
                  <Typography fontSize="0.85rem" color="text.secondary">
                    {formatDateTime(interview.dateTime)} · {interview.mode}
                    {!isLink && interview.location && ` · ${interview.location}`}
                  </Typography>
                  {isLink && interview.status !== "Upcoming" && (
                    <Link
                      href={interview.location}
                      target="_blank"
                      rel="noopener noreferrer"
                      fontSize="0.8rem"
                      sx={{ wordBreak: "break-all" }}
                    >
                      Meeting link
                    </Link>
                  )}
                </Box>
              </Stack>
              <Stack direction="row" alignItems="center" gap={1}>
                {isLink && interview.status === "Upcoming" && (
                  <Button
                    size="small"
                    component="a"
                    href={interview.location}
                    target="_blank"
                    rel="noopener noreferrer"
                    endIcon={<ExternalLink size={13} />}
                    sx={{
                      fontWeight: 600,
                      // A clear border keeps the button size on hover.
                      border: "1px solid transparent",
                      "&:hover": { borderColor: "primary.main", backgroundColor: BRAND_TINT.soft },
                    }}
                  >
                    Join meeting
                  </Button>
                )}
                <Chip
                  label={interview.status}
                  size="small"
                  sx={{ fontWeight: 600, fontSize: "11px", color: chip.color, backgroundColor: chip.bg }}
                />
              </Stack>
            </Box>
          );
        })}
      </Stack>
    </Box>
  );
};

export default InterviewsSection;
