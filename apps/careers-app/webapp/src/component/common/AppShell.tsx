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

import { Box, Button, Stack, Tooltip, useTheme } from "@mui/material";
import { Briefcase, ClipboardList, LogOut, Moon, Sun, User } from "lucide-react";
import { Outlet, useLocation, useMatches, useNavigate } from "react-router-dom";

import { useContext, useEffect, useRef } from "react";

import SnackbarListener from "@component/common/SnackbarListener";
import { useAppAuthContext } from "@context/AuthContext";
import { ColorModeContext } from "@context/ColorModeContext";

import wso2LogoBlack from "@assets/images/wso2-logo_black.svg";
import wso2LogoWhite from "@assets/images/wso2-logo_white.svg";
import { State } from "@/types/types";
import {
  applicationsFailed,
  clearUserData,
  loadApplications,
  loadFailed,
  loadJobDetail,
  loadJobs,
  loadOrgStructure,
  loadProfile,
  profileFailed,
  setSavedJobs,
} from "@slices/careersSlice/careers";
import { RootState, useAppDispatch, useAppSelector } from "@slices/store";
import { dataNeededBy } from "@utils/routeData";
import { readSavedJobs } from "@utils/savedJobs";

const NAV_ITEMS = [
  { path: "/jobs", label: "Jobs", icon: Briefcase },
  { path: "/applications", label: "Applications", icon: ClipboardList },
  { path: "/profile", label: "Profile", icon: User },
];

const AppShell = () => {
  const theme = useTheme();
  const colorMode = useContext(ColorModeContext);
  const isDark = theme.palette.mode === "dark";
  const navigate = useNavigate();
  const location = useLocation();
  const dispatch = useAppDispatch();
  const { getToken: getAccessToken, isSignedIn, appSignIn, appSignOut } = useAppAuthContext();
  const jobsState = useAppSelector((state: RootState) => state.careers.jobsState);
  const orgStructureState = useAppSelector((state: RootState) => state.careers.orgStructureState);
  const applicationsState = useAppSelector((state: RootState) => state.careers.applicationsState);
  const profileState = useAppSelector((state: RootState) => state.careers.profileState);
  const sessionExpired = useAppSelector((state: RootState) => state.careers.sessionExpired);
  const jobs = useAppSelector((state: RootState) => state.careers.jobs);
  const jobDetails = useAppSelector((state: RootState) => state.careers.jobDetails);

  // Latest job details for the prefetch below.
  const jobDetailsRef = useRef(jobDetails);
  jobDetailsRef.current = jobDetails;

  // The data the open route needs.
  const {
    jobs: needsJobs,
    orgStructure: needsOrgStructure,
    jobDetails: needsJobDetails,
    applications: needsApplications,
    profile: needsProfile,
  } = dataNeededBy(useMatches());

  // Loads the job list and org structure for the open route.
  useEffect(() => {
    const loadJobList = needsJobs && jobsState === State.idle;
    const loadOrgs = needsOrgStructure && orgStructureState === State.idle;
    if (!loadJobList && !loadOrgs) return;
    // Set when the effect is replaced before the token arrives, so the newer one does the load.
    let cancelled = false;
    getAccessToken()
      .then((token) => {
        if (cancelled) return;
        if (loadJobList) dispatch(loadJobs(token));
        if (loadOrgs) dispatch(loadOrgStructure(token));
      })
      .catch(() => {
        if (!cancelled) dispatch(loadFailed());
      });
    return () => {
      cancelled = true;
    };
  }, [dispatch, getAccessToken, jobsState, orgStructureState, needsJobs, needsOrgStructure]);

  // Prefetches each job's detail in the background.
  useEffect(() => {
    if (jobsState !== State.success || !needsJobDetails) return;
    const queue = jobs.map((job) => job.id).filter((jobId) => !jobDetailsRef.current[jobId]);
    if (queue.length === 0) return;

    // Two at a time; stops after two failures.
    let cancelled = false;
    let failures = 0;
    const worker = async () => {
      try {
        const token = await getAccessToken();
        while (!cancelled && failures < 2) {
          const jobId = queue.shift();
          if (!jobId) return;
          const result = await dispatch(loadJobDetail({ accessToken: token, jobId }));
          if (loadJobDetail.rejected.match(result)) failures += 1;
        }
      } catch {
        // No token: the job page loads its own detail on demand.
      }
    };
    Array.from({ length: 2 }, worker);

    return () => {
      cancelled = true;
    };
  }, [jobsState, jobs, needsJobDetails, dispatch, getAccessToken]);

  // Loads the candidate's applications and profile for the open route.
  useEffect(() => {
    const loadApps = needsApplications && applicationsState === State.idle;
    const loadOwnProfile = needsProfile && profileState === State.idle;
    if (!isSignedIn || (!loadApps && !loadOwnProfile)) return;
    // Set when the effect is replaced before the token arrives.
    let cancelled = false;
    getAccessToken()
      .then((token) => {
        if (cancelled) return;
        if (loadApps) dispatch(loadApplications(token));
        if (loadOwnProfile) dispatch(loadProfile(token));
      })
      .catch(() => {
        if (cancelled) return;
        if (loadApps) dispatch(applicationsFailed());
        if (loadOwnProfile) dispatch(profileFailed());
      });
    return () => {
      cancelled = true;
    };
  }, [isSignedIn, applicationsState, profileState, needsApplications, needsProfile, dispatch, getAccessToken]);

  // Clears the candidate's data when nobody is signed in.
  useEffect(() => {
    if (!isSignedIn) dispatch(clearUserData());
  }, [isSignedIn, dispatch]);

  // Restores the candidate's saved jobs on sign-in.
  const userId = useAppSelector((state: RootState) => state.auth.decodedIdToken?.sub);
  const savedJobsOf = useRef<string | null>(null);
  useEffect(() => {
    if (!isSignedIn || !userId) {
      savedJobsOf.current = null;
      return;
    }
    if (savedJobsOf.current === userId) return;
    savedJobsOf.current = userId;
    dispatch(setSavedJobs(readSavedJobs(userId)));
  }, [isSignedIn, userId, dispatch]);

  // Signs the candidate out when the backend refuses the access token.
  useEffect(() => {
    if (!sessionExpired) return;
    dispatch(clearUserData());
    appSignOut();
  }, [sessionExpired, dispatch, appSignOut]);

  // Guests only see the Jobs link.
  const navItems = isSignedIn ? NAV_ITEMS : NAV_ITEMS.filter((item) => item.path === "/jobs");

  const isActive = (path: string) => location.pathname.startsWith(path);

  // Resets the scroll of the page container on a route change.
  const contentRef = useRef<HTMLDivElement>(null);
  useEffect(() => {
    contentRef.current?.scrollTo({ top: 0 });
  }, [location.pathname]);

  return (
    <Box sx={{ height: "100vh", display: "flex", flexDirection: "column" }}>
      <SnackbarListener />

      {/* Top bar */}
      <Box
        sx={{
          height: "60px",
          flexShrink: 0,
          zIndex: 20,
          backgroundColor: isDark ? "#00000026" : "#FFFFFF",
          backdropFilter: isDark ? "blur(16px)" : "none",
          borderBottom: "1px solid",
          borderColor: isDark ? "rgba(255,255,255,0.08)" : "divider",
          boxShadow: isDark ? "0 4px 18px -8px rgba(0,0,0,0.6)" : "0 4px 18px -10px rgba(7,20,46,0.18)",
          display: "flex",
          alignItems: "center",
          justifyContent: "space-between",
          px: { xs: 2, md: 3 },
        }}
      >
        <Box component="a" href="https://wso2.com" aria-label="Go to the WSO2 home page" sx={{ display: "flex" }}>
          <Box
            component="img"
            src={theme.palette.mode === "dark" ? wso2LogoWhite : wso2LogoBlack}
            alt=""
            sx={{ height: 40, width: "auto" }}
          />
        </Box>

        <Stack direction="row" alignItems="center" gap={0.5}>
          {/* Icon-only links; the name shows as a tooltip on hover or keyboard focus */}
          <Stack component="nav" direction="row" alignItems="center" gap={0.5}>
            {navItems.map((item) => {
              const active = isActive(item.path);
              return (
                <Tooltip key={item.path} title={item.label} arrow disableInteractive>
                  <Box
                    component="button"
                    onClick={() => navigate(item.path)}
                    aria-label={item.label}
                    aria-current={active ? "page" : undefined}
                    sx={{
                      display: "flex",
                      alignItems: "center",
                      px: 1.25,
                      py: 0.9,
                      border: "none",
                      borderRadius: "10px",
                      cursor: "pointer",
                      backgroundColor: active ? "#ff670018" : "transparent",
                      color: active ? "#ff6700" : "text.secondary",
                      transition: "background-color 0.15s, color 0.15s",
                      "&:hover, &:focus-visible": {
                        backgroundColor: active ? "#ff670018" : "action.hover",
                        color: active ? "#ff6700" : "text.primary",
                      },
                    }}
                  >
                    <item.icon size={19} />
                  </Box>
                </Tooltip>
              );
            })}
          </Stack>

          <Box sx={{ width: "1px", height: 24, backgroundColor: "divider", mx: 1 }} />

          <Tooltip title={isDark ? "Switch to light mode" : "Switch to dark mode"} arrow disableInteractive>
            <Box
              component="button"
              onClick={colorMode.toggleColorMode}
              aria-label="Toggle light and dark mode"
              sx={{
                width: 34,
                height: 34,
                borderRadius: "50%",
                border: "1px solid",
                borderColor: "divider",
                background: "none",
                cursor: "pointer",
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                color: "text.secondary",
                transition: "color 0.15s, border-color 0.15s",
                "&:hover": { color: "primary.main", borderColor: "primary.main" },
              }}
            >
              {isDark ? <Sun size={17} /> : <Moon size={17} />}
            </Box>
          </Tooltip>

          {isSignedIn ? (
            <Tooltip title="Sign out" arrow disableInteractive>
              <Box
                component="button"
                onClick={appSignOut}
                aria-label="Sign out"
                sx={{
                  width: 34,
                  height: 34,
                  ml: 0.5,
                  borderRadius: "50%",
                  border: "1px solid",
                  borderColor: "divider",
                  background: "none",
                  cursor: "pointer",
                  display: "flex",
                  alignItems: "center",
                  justifyContent: "center",
                  color: "text.secondary",
                  transition: "color 0.15s, border-color 0.15s",
                  "&:hover": { color: "primary.main", borderColor: "primary.main" },
                }}
              >
                <LogOut size={16} />
              </Box>
            </Tooltip>
          ) : (
            <Button
              size="small"
              variant="contained"
              onClick={appSignIn}
              sx={{ ml: 1, fontWeight: 700, borderRadius: "999px", px: 2.5 }}
            >
              Sign in
            </Button>
          )}
        </Stack>
      </Box>

      {/* Page content */}
      <Box ref={contentRef} sx={{ flex: 1, overflowY: "auto" }}>
        <Outlet />
      </Box>
    </Box>
  );
};

export default AppShell;
