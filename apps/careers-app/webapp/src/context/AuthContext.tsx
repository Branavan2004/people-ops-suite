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

import { useAuthContext } from "@asgardeo/auth-react";
import { useIdleTimer } from "react-idle-timer";

import React, { useCallback, useContext, useEffect, useMemo, useRef, useState } from "react";

import PreLoader from "@component/common/PreLoader";
import SessionWarningDialog from "@component/common/SessionWarningDialog";
import { setUserAuthData } from "@slices/authSlice/auth";
import { useAppDispatch } from "@slices/store";

type AuthContextType = {
  appSignIn: () => void;
  appSignOut: () => void;
  // False for visitors browsing without an account.
  isSignedIn: boolean;
  // The access token for a signed-in user, or an empty string for a guest.
  getToken: () => Promise<string>;
  // A new access token for a signed-in user whose token has expired, got without leaving the page. It fails when the
  // sign-in cannot be renewed that way, and the user has to sign in again.
  renewToken: () => Promise<string>;
};

const AuthContext = React.createContext<AuthContextType>({} as AuthContextType);

// How long a signed-in user can be inactive before the sign-out warning opens, and how long it stays open.
const IDLE_TIMEOUT_MS = 30 * 60 * 1000;
const WARNING_MS = 60 * 1000;

const AppAuthProvider = (props: { children: React.ReactNode }) => {
  const {
    signIn,
    signOut,
    state,
    getBasicUserInfo,
    getDecodedIDToken,
    getAccessToken,
    refreshAccessToken,
    trySignInSilently,
  } = useAuthContext();
  const isAuthenticated = state.isAuthenticated;
  const isLoading = state.isLoading;

  const [sessionWarningOpen, setSessionWarningOpen] = useState<boolean>(false);
  const [userLoaded, setUserLoaded] = useState<boolean>(false);

  const dispatch = useAppDispatch();

  useEffect(() => {
    if (userLoaded) return;
    if (!isAuthenticated) return;

    const loadUser = async () => {
      try {
        const [userInfo, idToken] = await Promise.all([getBasicUserInfo(), getDecodedIDToken()]);
        dispatch(setUserAuthData({ userInfo, decodedIdToken: idToken }));
        setUserLoaded(true);
      } catch (err) {
        console.error("Auth loadUser() failed — signing out:", err);
        signOut();
      }
    };

    loadUser();
  }, [isAuthenticated, userLoaded, getBasicUserInfo, getDecodedIDToken, dispatch, signOut]);

  const appSignIn = useCallback(() => {
    signIn();
  }, [signIn]);

  const appSignOut = useCallback(() => {
    setUserLoaded(false);
    signOut();
  }, [signOut]);

  // Signs the user out of the app and the identity provider once the inactivity period ends, so an unattended browser
  // does not stay signed in.
  const onIdle = () => {
    if (!isAuthenticated) return;
    setSessionWarningOpen(false);
    appSignOut();
  };

  const { activate } = useIdleTimer({
    onPrompt: () => {
      if (isAuthenticated) setSessionWarningOpen(true);
    },
    onIdle,
    timeout: IDLE_TIMEOUT_MS,
    promptBeforeIdle: WARNING_MS,
    throttle: 500,
    // Activity in any open tab counts, and the sign-out reaches every tab.
    crossTab: true,
  });

  const handleContinue = () => {
    setSessionWarningOpen(false);
    activate();
  };

  // The identity provider's functions change on every render, so they are read through a ref. That keeps getToken and
  // renewToken stable, and the pages that load data when they change do not reload on a theme switch.
  const sdk = useRef({ getAccessToken, refreshAccessToken, trySignInSilently });
  sdk.current = { getAccessToken, refreshAccessToken, trySignInSilently };

  // Guests browse and apply without a token; calls made on their behalf send no credentials.
  const getToken = useCallback(async () => {
    if (!isAuthenticated) return "";
    try {
      return await sdk.current.getAccessToken();
    } catch {
      return "";
    }
  }, [isAuthenticated]);

  // Renews the access token with the refresh token, and when there is none, through the user's session with the
  // identity provider.
  const renewToken = useCallback(async () => {
    try {
      await sdk.current.refreshAccessToken();
    } catch {
      if (!(await sdk.current.trySignInSilently())) throw new Error("The session could not be renewed.");
    }
    return sdk.current.getAccessToken();
  }, []);

  const authContext: AuthContextType = useMemo(
    () => ({ appSignIn, appSignOut, isSignedIn: isAuthenticated, getToken, renewToken }),
    [appSignIn, appSignOut, isAuthenticated, getToken, renewToken],
  );

  if (isLoading) {
    return <PreLoader isLoading message="Setting up your Candidate Passport ..." />;
  }

  return (
    <AuthContext.Provider value={authContext}>
      <SessionWarningDialog open={sessionWarningOpen} handleContinue={handleContinue} appSignOut={appSignOut} />
      {isAuthenticated && !userLoaded ? (
        <PreLoader isLoading message="Setting up your Candidate Passport ..." />
      ) : (
        props.children
      )}
    </AuthContext.Provider>
  );
};

const useAppAuthContext = (): AuthContextType => useContext(AuthContext);

export { useAppAuthContext };
export default AppAuthProvider;
