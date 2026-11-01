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

import {
  Box,
  Button,
  FormControlLabel,
  Grid,
  InputAdornment,
  Stack,
  Switch,
  TextField,
  Typography,
} from "@mui/material";
import { Search, X } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import { useNavigationType, useSearchParams } from "react-router-dom";

import { orangeTextOf } from "@config/brand";
import { useAppAuthContext } from "@context/AuthContext";

import JobCard from "@component/careers/JobCard";
import JobCardSkeleton from "@component/careers/JobCardSkeleton";
import JobFilters, { JobFilterValues } from "@component/careers/JobFilters";
import PageContainer from "@component/common/PageContainer";
import PageHeading from "@component/common/PageHeading";
import { State } from "@/types/types";
import { retryLoad } from "@slices/careersSlice/careers";
import { RootState, useAppDispatch, useAppSelector } from "@slices/store";
import { matchesJobType, matchesLocation, matchesSearch, matchesTeam } from "@utils/jobFilterUtils";

const Jobs = () => {
  const dispatch = useAppDispatch();
  const { isSignedIn } = useAppAuthContext();
  const jobs = useAppSelector((state: RootState) => state.careers.jobs);
  const jobsState = useAppSelector((state: RootState) => state.careers.jobsState);
  const orgStructureState = useAppSelector((state: RootState) => state.careers.orgStructureState);
  const savedJobIds = useAppSelector((state: RootState) => state.careers.savedJobIds);

  const [searchParams, setSearchParams] = useSearchParams();
  const navigationType = useNavigationType();
  const [tab, setTab] = useState<"available" | "saved">("available");
  const [search, setSearch] = useState(searchParams.get("search") ?? "");
  const urlJobType = searchParams.get("jobType") ?? "";
  const [filters, setFilters] = useState<JobFilterValues>({
    team: searchParams.getAll("team"),
    location: searchParams.getAll("location"),
  });

  // The page writes its own URL changes with replace; other navigation re-reads the search and filters.
  useEffect(() => {
    if (navigationType === "REPLACE") return;
    setSearch(searchParams.get("search") ?? "");
    setFilters({ team: searchParams.getAll("team"), location: searchParams.getAll("location") });
  }, [searchParams, navigationType]);

  useEffect(() => {
    const params = new URLSearchParams();
    if (search.trim()) params.set("search", search.trim());
    filters.location.forEach((loc) => params.append("location", loc));
    filters.team.forEach((team) => params.append("team", team));
    if (urlJobType) params.set("jobType", urlJobType);
    setSearchParams(params, { replace: true });
  }, [search, filters, urlJobType, setSearchParams]);

  const sourceJobs = useMemo(
    () => (tab === "saved" ? jobs.filter((job) => savedJobIds.includes(job.id)) : jobs),
    [jobs, tab, savedJobIds],
  );

  // Jobs matching everything except the team and location dropdowns.
  const baseJobs = useMemo(
    () => sourceJobs.filter((job) => matchesSearch(job, search) && matchesJobType(job, urlJobType)),
    [sourceJobs, search, urlJobType],
  );

  const filtered = useMemo(
    () => baseJobs.filter((job) => matchesTeam(job, filters.team) && matchesLocation(job, filters.location)),
    [baseJobs, filters],
  );

  return (
    <PageContainer>
      {/* Signed-in users get the saved-jobs switch right below, so the title sits closer to it. */}
      <PageHeading accent="Available" mb={isSignedIn ? 1.5 : 3}>
        Positions
      </PageHeading>

      {isSignedIn && (
        <Stack direction="row" mb={2}>
          <FormControlLabel
            control={
              <Switch
                size="small"
                checked={tab === "saved"}
                onChange={(e) => setTab(e.target.checked ? "saved" : "available")}
                sx={{
                  "& .MuiSwitch-switchBase.Mui-checked": { color: "primary.main" },
                  "& .MuiSwitch-switchBase.Mui-checked + .MuiSwitch-track": { backgroundColor: "primary.main" },
                }}
              />
            }
            label="Show saved jobs"
            sx={{ "& .MuiFormControlLabel-label": { fontSize: "0.95rem", fontWeight: 600 } }}
          />
        </Stack>
      )}

      {/* Search & Filters */}
      <Stack gap={2} mb={3}>
        <TextField
          placeholder="Search by job title or team..."
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          size="small"
          fullWidth
          InputProps={{
            startAdornment: (
              <InputAdornment position="start">
                <Search size={16} color="#9CA3AF" />
              </InputAdornment>
            ),
            // A clear button appears once there is text to remove.
            endAdornment: search ? (
              <InputAdornment position="end">
                <Box
                  component="button"
                  type="button"
                  aria-label="Clear search"
                  onClick={() => setSearch("")}
                  sx={{
                    display: "flex",
                    border: "none",
                    background: "none",
                    cursor: "pointer",
                    p: 0.5,
                    borderRadius: "50%",
                    color: "text.secondary",
                    "&:hover": { backgroundColor: "action.hover", color: "primary.main" },
                  }}
                >
                  <X size={16} />
                </Box>
              </InputAdornment>
            ) : null,
            sx: {
              borderRadius: "10px",
              "&:hover .MuiOutlinedInput-notchedOutline": {
                borderColor: "primary.main",
              },
            },
          }}
        />
        <JobFilters
          jobs={baseJobs}
          filters={filters}
          onChange={setFilters}
          searchActive={search.trim() !== ""}
          onClearAll={() => {
            setSearch("");
            setFilters({ team: [], location: [] });
          }}
        />
        {/* When the jobs failed too, the retry button below reloads both. */}
        {orgStructureState === State.failed && jobsState !== State.failed && (
          <Stack direction="row" alignItems="center" gap={1}>
            <Typography fontSize="13px" color="error">
              The team and location filters could not be loaded.
            </Typography>
            <Button size="small" onClick={() => dispatch(retryLoad())}>
              Try again
            </Button>
          </Stack>
        )}
      </Stack>

      {/* Loading */}
      {(jobsState === State.idle || jobsState === State.loading) && (
        <Grid container spacing={2}>
          {Array.from({ length: 6 }).map((_, i) => (
            <Grid key={i} size={{ xs: 12, sm: 6, md: 4 }}>
              <JobCardSkeleton />
            </Grid>
          ))}
        </Grid>
      )}

      {/* Error */}
      {jobsState === State.failed && (
        <Box
          sx={{
            py: 8,
            textAlign: "center",
            border: "1px dashed",
            borderColor: "error.light",
            borderRadius: "12px",
          }}
        >
          <Typography color="error" mb={2}>
            Failed to load jobs.
          </Typography>
          <Button variant="outlined" onClick={() => dispatch(retryLoad())}>
            Try again
          </Button>
        </Box>
      )}

      {/* Results */}
      {jobsState === State.success && (
        <>
          <Typography fontSize="13px" color="text.secondary" mb={2}>
            Showing {filtered.length} of {sourceJobs.length} jobs
          </Typography>

          {filtered.length === 0 ? (
            <Box sx={{ py: 8, textAlign: "center" }}>
              <Typography fontWeight={600} fontSize="1rem" sx={{ color: (theme) => orangeTextOf(theme) }}>
                {tab === "saved" && sourceJobs.length === 0
                  ? "You haven't saved any jobs yet. Click the bookmark icon on a job card to save it here."
                  : "There are no available vacancies that match your search"}
              </Typography>
            </Box>
          ) : (
            <Grid container spacing={2}>
              {filtered.map((job) => (
                <Grid key={job.id} size={{ xs: 12, sm: 6, md: 4 }}>
                  <JobCard job={job} />
                </Grid>
              ))}
            </Grid>
          )}
        </>
      )}
    </PageContainer>
  );
};

export default Jobs;
