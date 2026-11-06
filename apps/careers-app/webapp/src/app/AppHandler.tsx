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

import { Navigate, Outlet, RouterProvider, createBrowserRouter, useLocation, useParams } from "react-router-dom";

import { useEffect, useMemo } from "react";

import AppShell from "@component/common/AppShell";
import NotFoundPage from "@component/common/NotFoundPage";
import PreLoader from "@component/common/PreLoader";
import { CareersSiteUrl } from "@config/config";
import { DOCUMENTS_SUBMISSION_ENABLED } from "@config/constant";
import { useAppAuthContext } from "@context/AuthContext";
import { hasSignInError } from "@utils/profileService";
import type { RouteHandle } from "@utils/routeData";
import { View } from "@view/index";

// Shows the pages inside it to signed-in candidates, and sends a guest to sign in.
const RequireSignIn = () => {
  const { isSignedIn, appSignIn } = useAppAuthContext();
  const { search } = useLocation();

  // An error from Asgardeo on the address is not answered with another sign-in, which would loop. The landing page
  // shows it and asks the candidate.
  const signInRefused = hasSignInError(search);

  useEffect(() => {
    if (!isSignedIn && !signInRefused) appSignIn();
  }, [isSignedIn, signInRefused, appSignIn]);

  if (!isSignedIn && signInRefused) return <Navigate to={{ pathname: "/", search }} replace />;

  return isSignedIn ? <Outlet /> : <PreLoader isLoading message="Authenticating..." />;
};

// Sends the visitor to the wso2.com careers page, for the old job addresses of this app.
const CareersSiteRedirect = () => {
  useEffect(() => {
    window.location.replace(CareersSiteUrl);
  }, []);

  return <PreLoader isLoading message="Taking you to the careers page ..." />;
};

// While the documents step is closed, an address that opens it goes back to the application.
const DocumentsNotOpen = () => {
  const { id } = useParams<{ id: string }>();
  return <Navigate to={`/applications/${id}`} replace />;
};

const AppHandler = () => {
  const router = useMemo(
    () =>
      createBrowserRouter([
        {
          element: <AppShell />,
          errorElement: <NotFoundPage />,
          children: [
            { path: "/", element: <View.landing /> },
            { path: "/jobs/*", element: <CareersSiteRedirect /> },
            {
              element: <RequireSignIn />,
              children: [
                // The address Asgardeo's "Sign in" links return to: it starts the sign-in, then opens the applications.
                { path: "/sign-in", element: <Navigate to="/applications" replace /> },
                {
                  path: "/profile",
                  element: <View.profile />,
                  handle: { needs: ["profile"] } satisfies RouteHandle,
                },
                {
                  path: "/applications",
                  element: <View.applications />,
                  handle: { needs: ["applications"] } satisfies RouteHandle,
                },
                {
                  path: "/applications/:id",
                  element: <View.applications />,
                  handle: { needs: ["applications"] } satisfies RouteHandle,
                },
                {
                  path: "/applications/:id/documents",
                  element: DOCUMENTS_SUBMISSION_ENABLED ? <View.documents /> : <DocumentsNotOpen />,
                  // While the step is closed the route only redirects, so it declares no needs of its own.
                  handle: {
                    needs: DOCUMENTS_SUBMISSION_ENABLED ? ["applications", "profile"] : [],
                  } satisfies RouteHandle,
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
