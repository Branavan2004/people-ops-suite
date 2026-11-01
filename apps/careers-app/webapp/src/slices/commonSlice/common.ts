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

import { createSlice, type PayloadAction } from "@reduxjs/toolkit";
import type { VariantType } from "notistack";

interface CommonState {
  message: string;
  timestamp: number | null;
  type: VariantType;
}

const initialState: CommonState = {
  message: "",
  timestamp: null,
  type: "success",
};

const CommonSlice = createSlice({
  name: "common",
  initialState,
  reducers: {
    enqueueSnackbarMessage: (
      state,
      action: PayloadAction<{
        message: string;
        type: VariantType;
      }>,
    ) => {
      state.message = action.payload.message;
      state.type = action.payload.type;
      state.timestamp = Date.now();
    },
    // Clears the message only if it is still the one shown, so a message queued since is not lost.
    clearSnackbarMessage: (state, action: PayloadAction<number>) => {
      if (state.timestamp !== action.payload) return;
      state.message = "";
      state.timestamp = null;
    },
  },
});

export const { enqueueSnackbarMessage, clearSnackbarMessage } = CommonSlice.actions;
export default CommonSlice.reducer;
