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

import { Box, Button, Typography } from "@mui/material";
import { useLocation, useNavigate, useParams } from "react-router-dom";

import { useEffect, useRef, useState } from "react";

import { State } from "@/types/types";
import { PAGE_MARGIN_X, PAGE_PADDING_X } from "@config/brand";
import { JOB_NOT_FOUND_ERROR } from "@config/constant";
import { useAppAuthContext } from "@context/AuthContext";
import { loadJobDetail } from "@slices/careersSlice/careers";
import { RootState, useAppDispatch, useAppSelector } from "@slices/store";
import { jobPath, opensDirectly, withoutArrivalMark } from "@utils/jobFilterUtils";
import { toggleSavedJob } from "@utils/savedJobs";
import ApplySection from "@view/jobs/components/ApplySection";
import JobDescription from "@view/jobs/components/JobDescription";
import JobDetailSkeleton from "@view/jobs/components/JobDetailSkeleton";
import JobHero from "@view/jobs/components/JobHero";

const JobDetail = () => {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const location = useLocation();

  // Goes back in history, or to the job list when opened directly.
  const openedDirectly = useRef(location.key === "default");
  const goBackToJobs = () => (openedDirectly.current ? navigate("/jobs") : navigate(-1));
  const dispatch = useAppDispatch();
  const { getToken: getAccessToken, isSignedIn } = useAppAuthContext();

  const savedJobIds = useAppSelector((state: RootState) => state.careers.savedJobIds);
  const detail = useAppSelector((state: RootState) => (id ? state.careers.jobDetails[id] : undefined)) ?? null;

  const jobs = useAppSelector((state: RootState) => state.careers.jobs);
  const jobsState = useAppSelector((state: RootState) => state.careers.jobsState);

  const [loading, setLoading] = useState(!detail);
  const [error, setError] = useState(false);
  const [missing, setMissing] = useState(false);

  // Replaces the address with the readable job path.
  useEffect(() => {
    if (!detail) return;
    const path = jobPath(detail);
    if (location.pathname !== path || opensDirectly(location.search)) {
      navigate(`${path}${withoutArrivalMark(location.search)}${location.hash}`, { replace: true });
    }
  }, [detail, location.pathname, location.search, location.hash, navigate]);

  // Opens at the form for a #Apply-Now link.
  useEffect(() => {
    if (!detail || window.location.hash !== "#Apply-Now") return;
    const timer = setTimeout(() => document.getElementById("Apply-Now")?.scrollIntoView(), 100);
    return () => clearTimeout(timer);
  }, [detail]);

  useEffect(() => {
    if (!id || detail) {
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(false);
    setMissing(false);
    getAccessToken()
      .then((token) => dispatch(loadJobDetail({ accessToken: token, jobId: id })).unwrap())
      .catch((err: { name?: string }) => {
        setError(true);
        setMissing(err?.name === JOB_NOT_FOUND_ERROR);
      })
      .finally(() => setLoading(false));
  }, [id, detail, dispatch, getAccessToken]);

  if (loading) return <JobDetailSkeleton />;

  // The job does not exist or could not be loaded.
  const notAvailable = missing || (error && jobsState === State.success && !jobs.some((job) => job.id === id));

  if (error || !detail) {
    return (
      <Box>
        <Box sx={{ textAlign: "center", py: 10 }}>
          <Typography variant="h5" mb={notAvailable ? 1 : 2} color="text.primary">
            {notAvailable ? "This job is not available." : "Failed to load job details."}
          </Typography>
          {notAvailable && (
            <Typography color="text.secondary" mb={2}>
              It may have been closed, or the link may be wrong.
            </Typography>
          )}
          <Button variant="contained" onClick={() => navigate("/jobs")}>
            Back to Jobs
          </Button>
        </Box>
      </Box>
    );
  }

  const isSaved = savedJobIds.includes(detail.id);

  const scrollToApplyForm = () => {
    // Updates the address without adding a history entry.
    window.history.replaceState(window.history.state, "", `${location.pathname}${location.search}#Apply-Now`);
    document.getElementById("Apply-Now")?.scrollIntoView({ behavior: "smooth" });
  };

  return (
    <Box sx={{ bgcolor: "background.glass" }}>
      <JobHero
        detail={detail}
        isSignedIn={isSignedIn}
        isSaved={isSaved}
        onBack={goBackToJobs}
        onApplyNow={scrollToApplyForm}
        onToggleSave={() => dispatch(toggleSavedJob(detail.id))}
        onSeeAllRoles={() => navigate("/jobs")}
      />

      <Box sx={{ mx: PAGE_MARGIN_X, px: PAGE_PADDING_X, py: { xs: 5, md: 7 } }}>
        <JobDescription
          mainContent={detail.mainContent}
          taskInformation={detail.taskInformation}
          additionalContent={detail.additionalContent}
        />
        <ApplySection detail={detail} />
      </Box>
    </Box>
  );
};

export default JobDetail;
