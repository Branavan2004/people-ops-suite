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

import { Box, Button, Grid, Stack, Tooltip, Typography, useTheme } from "@mui/material";
import { ArrowLeft, ArrowRight } from "lucide-react";

import { ON_ORANGE, PAGE_MARGIN_X, PAGE_PADDING_X, PAGE_PULL_LEFT, heroColorsOf } from "@config/brand";
import { pillButtonSx } from "@utils/styles";
import type { VacancyDetail } from "@utils/vacancyService";
import JobAtAGlance from "@view/jobs/components/JobAtAGlance";
import JobShareActions from "@view/jobs/components/JobShareActions";
import { teamColors } from "@view/jobs/jobDetailStyles";

interface JobHeroProps {
  detail: VacancyDetail;
  isSignedIn: boolean;
  isSaved: boolean;
  onBack: () => void;
  onApplyNow: () => void;
  onToggleSave: () => void;
  onSeeAllRoles: () => void;
}

const JobHero = ({
  detail,
  isSignedIn,
  isSaved,
  onBack,
  onApplyNow,
  onToggleSave,
  onSeeAllRoles,
}: JobHeroProps) => {
  const color = teamColors[detail.team.toUpperCase()] ?? "#6B7280";
  // An office-less vacancy is Remote only when remote work is allowed.
  const noOfficeLabel = detail.allowRemote ? "Remote" : "Not specified";
  const officeLabel = detail.officeLocations.length > 0 ? detail.officeLocations.join(", ") : noOfficeLabel;

  const hero = heroColorsOf(useTheme().palette.mode);

  return (
    <Box
      sx={{
        position: "relative",
        overflow: "hidden",
        backgroundColor: hero.background,
        backgroundImage: [
          `radial-gradient(circle at 78% 65%, ${hero.orangeGlow}, transparent 60%)`,
          `radial-gradient(circle at 30% 20%, ${hero.blueGlow}, transparent 55%)`,
          `linear-gradient(${hero.gridLine} 1px, transparent 1px)`,
          `linear-gradient(90deg, ${hero.gridLine} 1px, transparent 1px)`,
        ].join(", "),
        backgroundSize: "auto, auto, 42px 42px, 42px 42px",
      }}
    >
      <Box sx={{ mx: PAGE_MARGIN_X, px: PAGE_PADDING_X, py: { xs: 5, md: 7 } }}>
        <Tooltip title="Back to jobs" arrow>
          <Box
            component="button"
            onClick={onBack}
            aria-label="Back to jobs"
            sx={{
              width: 40,
              height: 40,
              mb: 3,
              ml: PAGE_PULL_LEFT,
              borderRadius: "50%",
              border: `1.5px solid ${hero.backButtonBorder}`,
              backgroundColor: hero.backButtonFill,
              cursor: "pointer",
              display: "flex",
              alignItems: "center",
              justifyContent: "center",
              color: "text.primary",
              transition: "background-color 0.15s, border-color 0.15s, color 0.15s",
              "&:hover": { backgroundColor: "primary.main", borderColor: "primary.main", color: "#fff" },
            }}
          >
            <ArrowLeft size={20} strokeWidth={2.5} />
          </Box>
        </Tooltip>

        <Grid container spacing={4} alignItems="center">
          <Grid size={{ xs: 12, md: 7 }}>
            <Stack direction="row" gap={1} mb={2} flexWrap="wrap">
              <Box
                sx={{
                  px: 1.5,
                  py: 0.5,
                  borderRadius: "999px",
                  border: `1px solid ${hero.outline}`,
                  color: color,
                  fontSize: "11px",
                  fontWeight: 700,
                  letterSpacing: "0.05em",
                }}
              >
                • {detail.team.toUpperCase()}
              </Box>
              {detail.country.map((c) => (
                <Box
                  key={c}
                  sx={{
                    px: 1.5,
                    py: 0.5,
                    borderRadius: "999px",
                    border: `1px solid ${hero.outline}`,
                    color: "primary.main",
                    fontSize: "11px",
                    fontWeight: 700,
                    letterSpacing: "0.05em",
                  }}
                >
                  • {c.toUpperCase()}
                </Box>
              ))}
            </Stack>

            <Typography
              variant="h1"
              fontWeight={800}
              sx={{
                color: "text.primary",
                textWrap: "balance",
                fontSize: { xs: "2.4rem", md: "4rem" },
                lineHeight: { xs: "3rem", md: "5rem" },
                mb: 3,
              }}
            >
              {detail.title}
            </Typography>

            <Button
              variant="contained"
              size="large"
              onClick={onApplyNow}
              endIcon={<ArrowRight size={17} />}
              sx={{
                ...pillButtonSx,
                px: 3.5,
                py: 1.2,
                backgroundColor: "primary.main",
                color: ON_ORANGE,
                "&:hover": { backgroundColor: "primary.main", filter: "brightness(0.95)" },
              }}
            >
              Apply Now
            </Button>

            <JobShareActions
              job={detail}
              isSignedIn={isSignedIn}
              isSaved={isSaved}
              onToggleSave={onToggleSave}
            />
          </Grid>

          <Grid size={{ xs: 12, md: 5 }}>
            <JobAtAGlance
              team={detail.team}
              officeLabel={officeLabel}
              jobType={detail.jobType}
              onSeeAllRoles={onSeeAllRoles}
            />
          </Grid>
        </Grid>
      </Box>
    </Box>
  );
};

export default JobHero;
