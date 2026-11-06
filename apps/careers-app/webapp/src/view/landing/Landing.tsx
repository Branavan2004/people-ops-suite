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

import { Box, Button, Typography } from "@wso2/oxygen-ui";
import { Navigate, useSearchParams } from "react-router-dom";

import { useEffect, useState } from "react";

import PreLoader from "@component/common/PreLoader";
import { useAppAuthContext } from "@context/AuthContext";
import { emailFromLink, isValidEmail } from "@utils/email";
import { clearForcedSignOut, forcedSignOutRecently, hasSignInError } from "@utils/profileService";
import { pillButtonSx } from "@utils/styles";

// The entry of the link in the email sent after applying: it opens the Asgardeo sign-in right away, where the
// candidate can also create an account. A valid ?email= in the link is filled in there.
const Landing = () => {
  const { isSignedIn, appSignIn } = useAppAuthContext();
  const [params] = useSearchParams();
  const emailParam = emailFromLink(params.get("email"));
  const email = isValidEmail(emailParam) ? emailParam : undefined;

  // Set when the app just signed the candidate out because the backend refused their session. A sign-in started again
  // at once would end the same way, so the candidate is asked instead.
  const [stopped, setStopped] = useState(() => forcedSignOutRecently());

  // Set when Asgardeo sent the candidate back here with an error. The same sign-in would come back with the same
  // error, so it is not started again until the candidate asks.
  const signInRefused = hasSignInError(params.toString());

  useEffect(() => {
    if (!isSignedIn && !stopped && !signInRefused) appSignIn(email);
  }, [isSignedIn, stopped, signInRefused, appSignIn, email]);

  if (isSignedIn) return <Navigate to="/applications" replace />;

  if (stopped || signInRefused) {
    return (
      <Box
        sx={{
          minHeight: "60vh",
          display: "flex",
          flexDirection: "column",
          alignItems: "center",
          justifyContent: "center",
          gap: 2,
          textAlign: "center",
          px: 2,
        }}
      >
        <Typography color="text.primary">
          {stopped
            ? "We could not verify your session with the server. Please try again in a moment."
            : "We could not sign you in. Please try again, or contact the recruitment team if it keeps happening."}
        </Typography>
        <Button
          variant="contained"
          onClick={() => {
            clearForcedSignOut();
            setStopped(false);
            if (signInRefused) appSignIn(email);
          }}
          sx={{ ...pillButtonSx, px: 3 }}
        >
          Sign in again
        </Button>
      </Box>
    );
  }

  // The same screen RequireSignIn shows while it waits for the sign-in, so going from one to the other does not flicker.
  return <PreLoader isLoading message="Authenticating..." />;
};

export default Landing;
