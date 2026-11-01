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

import { Box, Card, CardContent, Stack, Typography } from "@mui/material";
import { ArrowRight } from "lucide-react";

import type { Application } from "@/types/types";
import ApplicationStatusBadge from "@component/careers/ApplicationStatusBadge";
import { daysLeftText, isOffer, offerDeadlineOf, timeAgo } from "@view/applications/applicationHelpers";

interface ApplicationListCardProps {
  application: Application;
  onView: () => void;
}

// One application in the list.
const ApplicationListCard = ({ application, onView }: ApplicationListCardProps) => {
  const updated = application.updatedDate ?? (application.timeline ?? []).at(-1)?.date ?? application.appliedDate;
  const deadline = isOffer(application) ? offerDeadlineOf(application) : null;
  const actionNeeded = isOffer(application) && (deadline === null || deadline.daysLeft >= 0);

  return (
    <Card
      elevation={0}
      sx={{
        height: "100%",
        border: "1px solid",
        borderColor: "divider",
        borderRadius: "8px",
        transition: "border-color 0.15s",
        "&:hover": { borderColor: "primary.main" },
      }}
    >
      <CardContent sx={{ p: 3, height: "100%", display: "flex", flexDirection: "column", "&:last-child": { pb: 3 } }}>
        <Typography
          component="h3"
          sx={{
            fontSize: "1.2rem",
            lineHeight: 1.5,
            fontWeight: 400,
            color: "text.primary",
            display: "-webkit-box",
            WebkitLineClamp: 3,
            WebkitBoxOrient: "vertical",
            overflow: "hidden",
          }}
        >
          {application.jobTitle}
        </Typography>
        <Typography fontSize="0.9rem" color="text.secondary" mt={0.5}>
          Updated {timeAgo(updated)}
        </Typography>

        <Stack direction="row" alignItems="center" gap={1} mt={2}>
          <ApplicationStatusBadge status={application.status} />
          {actionNeeded && (
            <Typography fontSize="0.8rem" fontWeight={700} sx={{ color: "primary.main" }}>
              Action needed{deadline ? ` · ${daysLeftText(deadline.daysLeft)}` : ""}
            </Typography>
          )}
        </Stack>

        <Box sx={{ flexGrow: 1 }} />
        <Box
          component="button"
          type="button"
          onClick={onView}
          sx={{
            alignSelf: "flex-end",
            mt: 3,
            display: "flex",
            alignItems: "center",
            gap: 0.5,
            p: 0,
            border: "none",
            background: "none",
            cursor: "pointer",
            fontFamily: "inherit",
            fontSize: "0.9rem",
            fontWeight: 600,
            color: "text.primary",
          }}
        >
          View application
          <ArrowRight size={14} color="#ff6700" />
        </Box>
      </CardContent>
    </Card>
  );
};

export default ApplicationListCard;
