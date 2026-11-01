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

import { AssignmentOutlined } from "@mui/icons-material";
import { Button, Card, CardContent, Grid, Stack, Tab, Tabs, Typography } from "@mui/material";

import { useState } from "react";

import { type Application, State } from "@/types/types";
import CenteredSpinner from "@component/common/CenteredSpinner";
import PageHeading from "@component/common/PageHeading";
import { SnackMessage } from "@config/constant";
import { cardSx } from "@utils/styles";
import { type ApplicationFilter, defaultTabOf, tabOf } from "@view/applications/applicationHelpers";
import ApplicationListCard from "@view/applications/components/ApplicationListCard";

interface ApplicationListProps {
  applications: Application[];
  applicationsState: State;
  onView: (applicationId: string) => void;
  onBrowseJobs: () => void;
  onRetry: () => void;
}

const TABS: { key: ApplicationFilter; label: string }[] = [
  { key: "all", label: "All" },
  { key: "active", label: "Active" },
  { key: "offers", label: "Offers" },
  { key: "closed", label: "Closed" },
];

// The applications list with its loading, failed and empty states, tabs and cards.
const ApplicationList = ({ applications, applicationsState, onView, onBrowseJobs, onRetry }: ApplicationListProps) => {
  // The tab the candidate picked; the default one until then.
  const [chosenTab, setChosenTab] = useState<ApplicationFilter | null>(null);
  const tab = chosenTab ?? defaultTabOf(applications);

  const countOf = (key: ApplicationFilter) =>
    key === "all" ? applications.length : applications.filter((a) => tabOf(a) === key).length;
  const visible = tab === "all" ? applications : applications.filter((a) => tabOf(a) === tab);

  return (
    <>
      <PageHeading accent="My">Applications</PageHeading>

      {applicationsState === State.loading && applications.length === 0 && <CenteredSpinner />}

      {applicationsState === State.failed && (
        <Stack direction="row" alignItems="center" gap={2} mb={2}>
          <Typography color="error">{SnackMessage.error.fetchApplications}</Typography>
          <Button variant="outlined" size="small" onClick={onRetry}>
            Try again
          </Button>
        </Stack>
      )}

      {applicationsState === State.success && applications.length === 0 ? (
        <Card elevation={0} sx={cardSx}>
          <CardContent sx={{ py: 8, textAlign: "center" }}>
            <AssignmentOutlined sx={{ fontSize: 48, color: "text.secondary", mb: 2 }} />
            <Typography variant="h6" fontWeight={600} mb={1} color="text.primary">
              No Applications Yet
            </Typography>
            <Typography color="text.secondary" mb={3} fontSize="0.9rem">
              You haven&apos;t applied to any positions. Start exploring open roles!
            </Typography>
            <Button variant="contained" onClick={onBrowseJobs}>
              Browse Jobs
            </Button>
          </CardContent>
        </Card>
      ) : (
        <>
          <Tabs
            value={tab}
            onChange={(_, value: ApplicationFilter) => setChosenTab(value)}
            sx={{
              mb: 3,
              borderBottom: "1px solid",
              borderColor: "divider",
              "& .MuiTabs-indicator": { backgroundColor: "primary.main" },
              "& .MuiTab-root": { textTransform: "none", fontSize: "1rem", fontWeight: 500, color: "text.secondary" },
              "& .MuiTab-root.Mui-selected": { color: "text.primary" },
            }}
          >
            {TABS.map((t) => (
              <Tab key={t.key} value={t.key} label={`${t.label} (${countOf(t.key)})`} />
            ))}
          </Tabs>

          {visible.length === 0 ? (
            <Typography color="text.secondary">No applications in this tab.</Typography>
          ) : (
            <Grid container spacing={3}>
              {visible.map((application) => (
                <Grid key={application.id} size={{ xs: 12, sm: 6, md: 4 }}>
                  <ApplicationListCard application={application} onView={() => onView(application.id)} />
                </Grid>
              ))}
            </Grid>
          )}
        </>
      )}
    </>
  );
};

export default ApplicationList;
