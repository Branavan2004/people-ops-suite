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

import { Navigate, Outlet, RouterProvider, createBrowserRouter, useLocation } from "react-router-dom";

import { useEffect, useMemo } from "react";

import AppShell from "@component/common/AppShell";
import NotFoundPage from "@component/common/NotFoundPage";
import PreLoader from "@component/common/PreLoader";
import { useAppAuthContext } from "@context/AuthContext";
import { opensDirectly } from "@utils/jobFilterUtils";
import type { RouteHandle } from "@utils/routeData";
import { View } from "@view/index";

// Shows the pages inside it to signed-in candidates, and sends a guest to sign in.
const RequireSignIn = () => {
  const { isSignedIn, appSignIn } = useAppAuthContext();

  useEffect(() => {
    if (!isSignedIn) appSignIn();
  }, [isSignedIn, appSignIn]);

  return isSignedIn ? <Outlet /> : <PreLoader isLoading message="Taking you to sign in ..." />;
};

// Shows a job when it was opened from inside the app, or from a link made for it (a new tab, a share). An address
// typed into the browser goes to the list.
const JobPage = () => {
  const { key, search } = useLocation();
  const allowed = key !== "default" || opensDirectly(search);
  return allowed ? <View.jobDetail /> : <Navigate to="/jobs" replace />;
};

const AppHandler = () => {
  const router = useMemo(
    () =>
      createBrowserRouter([
        {
          element: <AppShell />,
          errorElement: <NotFoundPage />,
          children: [
            { path: "/", element: <Navigate to="/jobs" replace /> },
            {
              path: "/jobs",
              element: <View.jobs />,
              handle: { needs: ["jobs", "orgStructure", "jobDetails"] } satisfies RouteHandle,
            },
            {
              path: "/jobs/:id/:slug?",
              element: <JobPage />,
              handle: { needs: ["jobs", "jobDetails", "profile"] } satisfies RouteHandle,
            },
            {
              element: <RequireSignIn />,
              children: [
                // The address Asgardeo's "Sign in" links return to: it starts the sign-in, then opens the jobs.
                { path: "/sign-in", element: <Navigate to="/jobs" replace /> },
                {
                  path: "/profile",
                  element: <View.profile />,
                  handle: { needs: ["profile"] } satisfies RouteHandle,
                },
                // The job list tells whether a vacancy is still open.
                {
                  path: "/applications",
                  element: <View.applications />,
                  handle: { needs: ["jobs", "applications"] } satisfies RouteHandle,
                },
                {
                  path: "/applications/:id",
                  element: <View.applications />,
                  handle: { needs: ["jobs", "applications"] } satisfies RouteHandle,
                },
                {
                  path: "/applications/:id/documents",
                  element: <View.documents />,
                  handle: { needs: ["applications", "profile"] } satisfies RouteHandle,
                },
              ],
            },
          ],
        },
        { path: "*", element: <NotFoundPage /> },
      ]),
    [],
  );

  return <RouterProvider router={router} />;
};

export default AppHandler;
