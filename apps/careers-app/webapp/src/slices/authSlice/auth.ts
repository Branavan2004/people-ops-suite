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

import { BasicUserInfo, DecodedIDTokenPayload } from "@asgardeo/auth-spa";
import { PayloadAction, createSlice } from "@reduxjs/toolkit";

interface AuthState {
  userInfo: BasicUserInfo | null;
  decodedIdToken: DecodedIDTokenPayload | null;
}

const initialState: AuthState = {
  userInfo: null,
  decodedIdToken: null,
};

const authSlice = createSlice({
  name: "auth",
  initialState,
  reducers: {
    // Keeps the signed-in user's details.
    setUserAuthData: (state, action: PayloadAction<AuthState>) => {
      state.userInfo = action.payload.userInfo;
      state.decodedIdToken = action.payload.decodedIdToken;
    },
  },
});

export const { setUserAuthData } = authSlice.actions;
export default authSlice.reducer;
