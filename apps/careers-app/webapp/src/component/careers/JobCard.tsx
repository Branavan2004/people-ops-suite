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

import { Box, Stack, Tooltip, Typography } from "@mui/material";
import { ArrowRight, Bookmark, BookmarkCheck } from "lucide-react";
import { Link } from "react-router-dom";

import { Job } from "@/types/types";
import { useAppAuthContext } from "@context/AuthContext";
import { RootState, useAppDispatch, useAppSelector } from "@slices/store";
import { jobPath } from "@utils/jobFilterUtils";
import { toggleSavedJob } from "@utils/savedJobs";

interface JobCardProps {
  job: Job;
}

const JobCard = ({ job }: JobCardProps) => {
  const dispatch = useAppDispatch();
  const { isSignedIn } = useAppAuthContext();
  const savedJobIds = useAppSelector((state: RootState) => state.careers.savedJobIds);
  const isSaved = savedJobIds.includes(job.id);
  const saveLabel = isSaved ? "Unsave job" : "Save job";

  return (
    // The save button is a sibling of the link, not inside it: a button must not be nested in an anchor.
    <Box sx={{ position: "relative", height: "100%" }}>
      <Box component={Link} to={jobPath(job, "list")} sx={{ textDecoration: "none", display: "block", height: "100%" }}>
        <Box
          sx={{
            height: "100%",
            display: "flex",
            flexDirection: "column",
            padding: "30px 28px 28px",
            border: "1px solid",
            borderColor: "divider",
            borderRadius: "14px",
            boxShadow: "0 18px 40px -16px rgb(7 20 46 / 18%)",
            backgroundColor: "background.glass",
            transition: "transform 0.15s, box-shadow 0.15s, border-color 0.15s",
            "&:hover": {
              transform: "translateY(-2px)",
              boxShadow: "0 18px 40px -16px rgb(7 20 46 / 18%)",
              borderColor: "rgba(255,103,0,0.45)",
            },
          }}
        >
          <Box
            sx={{
              alignSelf: "flex-start",
              marginBottom: "16px",
              padding: "6px 10px",
              borderRadius: "999px",
              backgroundColor: (theme) => (theme.palette.mode === "dark" ? "rgba(255,103,0,0.18)" : "#ffe0cc"),
              color: "#e55a00",
              fontSize: "11px",
              fontWeight: 700,
              lineHeight: 1.5,
              textTransform: "uppercase",
              letterSpacing: "0.08em",
            }}
          >
            {job.team}
          </Box>

          <Typography
            sx={{
              margin: "0 0 16px",
              paddingBottom: "16px",
              borderBottom: "1px solid",
              borderBottomColor: "divider",
              fontSize: "1.2rem",
              lineHeight: "1.8rem",
              fontWeight: 700,
              color: "text.primary",
            }}
          >
            {job.title}
          </Typography>

          <Stack direction="row" flexWrap="wrap" gap={0.75} sx={{ marginBottom: "18px" }}>
            <Box
              sx={{
                padding: "4px 9px",
                backgroundColor: "action.hover",
                border: "1px solid",
                borderColor: "divider",
                borderRadius: "999px",
                fontSize: "11.5px",
                fontWeight: 500,
                color: "text.primary",
              }}
            >
              {job.jobType}
            </Box>
            {job.country.map((c) => (
              <Box
                key={c}
                sx={{
                  padding: "4px 9px",
                  backgroundColor: (theme) => (theme.palette.mode === "dark" ? "rgba(59,130,246,0.22)" : "#dceffd"),
                  border: "1px solid transparent",
                  borderRadius: "999px",
                  fontSize: "11.5px",
                  fontWeight: 500,
                  color: "text.primary",
                }}
              >
                {c}
              </Box>
            ))}
          </Stack>

          <Stack
            direction="row"
            alignItems="center"
            justifyContent="flex-end"
            gap={0.5}
            sx={{ marginTop: "auto", paddingTop: "30px" }}
          >
            <Typography sx={{ fontSize: "0.9rem", fontWeight: 600, color: "text.primary" }}>Apply Now</Typography>
            <ArrowRight size={14} color="#ff6700" />
          </Stack>
        </Box>
      </Box>

      {isSignedIn && (
        <Stack direction="row" gap={0.5} sx={{ position: "absolute", top: 14, right: 14 }}>
          <Tooltip title={saveLabel} arrow>
            <Box
              component="button"
              aria-label={saveLabel}
              onClick={() => dispatch(toggleSavedJob(job.id))}
              sx={{
                border: "none",
                background: "none",
                cursor: "pointer",
                p: 0.5,
                borderRadius: "6px",
                color: isSaved ? "#ff6700" : "#6b7591",
                "&:hover": { backgroundColor: "action.hover" },
              }}
            >
              {isSaved ? <BookmarkCheck size={16} /> : <Bookmark size={16} />}
            </Box>
          </Tooltip>
        </Stack>
      )}
    </Box>
  );
};

export default JobCard;
