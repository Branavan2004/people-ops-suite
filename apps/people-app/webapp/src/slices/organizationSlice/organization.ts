// Copyright (c) 2025 WSO2 LLC. (https://www.wso2.com).
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

import { createSlice, createAsyncThunk, PayloadAction } from "@reduxjs/toolkit";
import { APIService } from "@utils/apiService";
import { State } from "@/types/types";
import { AppConfig } from "@config/config";
import { HttpStatusCode, isCancel } from "axios";
import { enqueueSnackbarMessage } from "@slices/commonSlice/common";

export interface BusinessUnit {
  id: number;
  name: string;
  head_email?: string;
  is_active?: boolean;
}

export interface Team {
  id: number;
  name: string;
  is_active?: boolean;
}

export interface SubTeam {
  id: number;
  name: string;
  is_active?: boolean;
}

export interface Unit {
  id: number;
  name: string;
  is_active?: boolean;
}

export interface CareerFunction {
  id: number;
  careerFunction: string;
}

export interface Designation {
  id: number;
  designation: string;
  jobBand: number | null;
}

export interface Company {
  id: number;
  name: string;
  prefix: string;
  location: string;
  allowedLocations: { location: string; probationPeriod: number | null }[];}

export interface Office {
  id: number;
  name: string;
  location: string;
  workingLocations: string[];
}

export interface EmploymentType {
  id: number;
  name: string;
  isActive: boolean;
}

export interface House {
  id: number;
  name: string;
}

export interface OrganizationState {
  state: State;
  stateMessage: string | null;
  errorMessage: string | null;
  businessUnits: BusinessUnit[];
  teams: Team[];
  subTeams: SubTeam[];
  units: Unit[];
  careerFunctions: CareerFunction[];
  designations: Designation[];
  companies: Company[];
  offices: Office[];
  employmentTypes: EmploymentType[];
  houses: House[];
  // Suggestions for an intern's University field. Tracked apart from `state`, so
  // loading them never flips the whole slice to loading.
  universities: string[];
  universitiesState: State;
}

const initialState: OrganizationState = {
  state: State.idle,
  stateMessage: null,
  errorMessage: null,
  businessUnits: [],
  teams: [],
  subTeams: [],
  units: [],
  careerFunctions: [],
  designations: [],
  companies: [],
  offices: [],
  employmentTypes: [],
  houses: [],
  universities: [],
  universitiesState: State.idle,
};

interface FetchParams {
  id?: number;
}

interface FetchDesignationsParams {
  careerFunctionId?: number;
}

// Fetch Business Units
export const fetchBusinessUnits = createAsyncThunk(
  "organization/fetchBusinessUnits",
  async (_, { dispatch, rejectWithValue }) => {
    try {
      const resp = await APIService.getInstance().get(
        `${AppConfig.serviceUrls.businessUnits}`,
      );
      if (!Array.isArray(resp.data)) {
        throw new Error("Invalid response: business units should be an array");
      }
      return resp.data as BusinessUnit[];
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching business units"
          : error.response?.data?.message ||
            error.message ||
            "An unknown error occurred while fetching business units.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
);

// Fetch Teams
export const fetchTeams = createAsyncThunk(
  "organization/fetchTeams",
  async ({ id: buId }: FetchParams = {}, { dispatch, rejectWithValue }) => {
    try {
      const url = buId
        ? `${AppConfig.serviceUrls.teams}?buId=${buId}`
        : `${AppConfig.serviceUrls.teams}`;
      const resp = await APIService.getInstance().get(url);
      if (!Array.isArray(resp.data)) {
        throw new Error("Invalid response: teams should be an array");
      }
      return resp.data as Team[];
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching teams"
          : error.response?.data?.message ||
            error.message ||
            "An unknown error occurred while fetching teams.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
);

// Fetch Sub Teams
export const fetchSubTeams = createAsyncThunk(
  "organization/fetchSubTeams",
  async ({ id: teamId }: FetchParams = {}, { dispatch, rejectWithValue }) => {
    try {
      const url = teamId
        ? `${AppConfig.serviceUrls.subTeams}?teamId=${teamId}`
        : `${AppConfig.serviceUrls.subTeams}`;
      const resp = await APIService.getInstance().get(url);
      if (!Array.isArray(resp.data)) {
        throw new Error("Invalid response: sub teams should be an array");
      }
      return resp.data as SubTeam[];
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching sub teams"
          : error.response?.data?.message ||
            error.message ||
            "An unknown error occurred while fetching sub teams.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
);

// Fetch Units
export const fetchUnits = createAsyncThunk(
  "organization/fetchUnits",
  async (
    { id: subTeamId }: FetchParams = {},
    { dispatch, rejectWithValue },
  ) => {
    try {
      const url = subTeamId
        ? `${AppConfig.serviceUrls.units}?subTeamId=${subTeamId}`
        : `${AppConfig.serviceUrls.units}`;
      const resp = await APIService.getInstance().get(url);
      if (!Array.isArray(resp.data)) {
        throw new Error("Invalid response: units should be an array");
      }
      return resp.data as Unit[];
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching units"
          : error.response?.data?.message ||
            error.message ||
            "An unknown error occurred while fetching units.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
);

// Fetch Career Functions
export const fetchCareerFunctions = createAsyncThunk(
  "organization/fetchCareerFunctions",
  async (_, { dispatch, rejectWithValue }) => {
    try {
      const resp = await APIService.getInstance().get(
        `${AppConfig.serviceUrls.careerFunctions}`,
      );
      if (!Array.isArray(resp.data)) {
        throw new Error(
          "Invalid response: career functions should be an array",
        );
      }
      return resp.data as CareerFunction[];
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching career functions"
          : error.response?.data?.message ||
            "An unknown error occurred while fetching career functions.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
);

// Fetch Designations
export const fetchDesignations = createAsyncThunk(
  "organization/fetchDesignations",
  async (
    { careerFunctionId }: FetchDesignationsParams = {},
    { dispatch, rejectWithValue },
  ) => {
    try {
      const url = careerFunctionId
        ? `${AppConfig.serviceUrls.designations}?careerFunctionId=${careerFunctionId}`
        : `${AppConfig.serviceUrls.designations}`;
      const resp = await APIService.getInstance().get(url);
      if (!Array.isArray(resp.data)) {
        throw new Error("Invalid response: designations should be an array");
      }
      return resp.data as Designation[];
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching designations"
          : error.response?.data?.message ||
            "An unknown error occurred while fetching designations.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
);

// Fetch Companies
export const fetchCompanies = createAsyncThunk(
  "organization/fetchCompanies",
  async (_, { dispatch, rejectWithValue }) => {
    try {
      const resp = await APIService.getInstance().get(
        `${AppConfig.serviceUrls.companies}`,
      );
      if (!Array.isArray(resp.data)) {
        throw new Error("Invalid response: companies should be an array");
      }
      return resp.data as Company[];
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching companies"
          : error.response?.data?.message ||
            error.message ||
            "An unknown error occurred while fetching companies.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
);

// Fetch Offices
export const fetchOffices = createAsyncThunk(
  "organization/fetchOffices",
  async (
    { id: companyId }: FetchParams = {},
    { dispatch, rejectWithValue },
  ) => {
    try {
      const url = companyId
        ? `${AppConfig.serviceUrls.offices}?companyId=${companyId}`
        : `${AppConfig.serviceUrls.offices}`;
      const resp = await APIService.getInstance().get(url);
      if (!Array.isArray(resp.data)) {
        throw new Error("Invalid response: offices should be an array");
      }
      const offices: Office[] = resp.data.map((office: any) => ({
        id: office.id,
        name: office.name,
        location: office.location,
        workingLocations: Array.isArray(office.workingLocations)
          ? office.workingLocations
          : [],
      }));
      return offices;
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching offices"
          : error.response?.data?.message ||
            error.message ||
            "Failed to fetch offices.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
);

// Fetch Employment Types
export const fetchUniversities = createAsyncThunk(
  "organization/fetchUniversities",
  async (_, { dispatch, rejectWithValue }) => {
    try {
      const resp = await APIService.getInstance().get(
        `${AppConfig.serviceUrls.universities}`,
      );
      if (!Array.isArray(resp.data)) {
        throw new Error("Invalid response: universities should be an array");
      }
      return resp.data as string[];
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching universities"
          : error.response?.data?.message ||
            error.message ||
            "An unknown error occurred while fetching universities.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
);

export const fetchEmploymentTypes = createAsyncThunk(
  "organization/fetchEmploymentTypes",
  async (_, { dispatch, rejectWithValue }) => {
    try {
      const resp = await APIService.getInstance().get(
        `${AppConfig.serviceUrls.employmentTypes}`,
      );
      if (!Array.isArray(resp.data)) {
        throw new Error(
          "Invalid response: employment types should be an array",
        );
      }
      return resp.data as EmploymentType[];
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching employment types"
          : error.response?.data?.message ||
            error.message ||
            "An unknown error occurred while fetching employment types.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
);

// Fetch Houses
export const fetchHouses = createAsyncThunk(
  "organization/fetchHouses",
  async (_, { dispatch, rejectWithValue }) => {
    try {
      const resp = await APIService.getInstance().get(
        `${AppConfig.serviceUrls.houses}`,
      );
      if (!Array.isArray(resp.data)) {
        throw new Error("Invalid response: houses should be an array");
      }
      return resp.data as House[];
    } catch (error: any) {
      if (isCancel(error)) return rejectWithValue("cancelled");
      const errorMessage =
        error.response?.status === HttpStatusCode.InternalServerError
          ? "Error fetching houses"
          : error.response?.data?.message ||
            error.message ||
            "An unknown error occurred while fetching houses.";
      dispatch(
        enqueueSnackbarMessage({
          message: errorMessage,
          type: "error",
        }),
      );
      return rejectWithValue(errorMessage);
    }
  },
);

export const organizationSlice = createSlice({
  name: "organization",
  initialState,
  reducers: {
    updateStateMessage: (state, action: PayloadAction<string | null>) => {
      state.stateMessage = action.payload;
    },
    resetState: (state) => {
      state.state = State.idle;
      state.stateMessage = null;
      state.errorMessage = null;
      state.businessUnits = [];
      state.teams = [];
      state.subTeams = [];
      state.units = [];
      state.careerFunctions = [];
      state.designations = [];
      state.companies = [];
      state.offices = [];
      state.employmentTypes = [];
      state.houses = [];
      state.universities = [];
      state.universitiesState = State.idle;
    },
  },
  extraReducers: (builder) => {
    builder
      .addCase(fetchBusinessUnits.pending, (state) => {
        state.state = State.loading;
        state.stateMessage = "Fetching business units...";
        state.errorMessage = null;
      })
      .addCase(fetchBusinessUnits.fulfilled, (state, action) => {
        state.businessUnits = action.payload;
        state.state = State.success;
        state.stateMessage = "Business units fetched successfully";
        state.errorMessage = null;
      })
      .addCase(fetchBusinessUnits.rejected, (state, action) => {
        state.state = State.failed;
        state.errorMessage = action.payload as string;
        state.stateMessage = null;
      })
      .addCase(fetchTeams.pending, (state) => {
        state.state = State.loading;
        state.stateMessage = "Fetching teams...";
        state.errorMessage = null;
      })
      .addCase(fetchTeams.fulfilled, (state, action) => {
        state.teams = action.payload;
        state.state = State.success;
        state.stateMessage = "Teams fetched successfully";
        state.errorMessage = null;
      })
      .addCase(fetchTeams.rejected, (state, action) => {
        state.state = State.failed;
        state.errorMessage = action.payload as string;
        state.stateMessage = null;
      })
      .addCase(fetchSubTeams.pending, (state) => {
        state.state = State.loading;
        state.stateMessage = "Fetching sub teams...";
        state.errorMessage = null;
      })
      .addCase(fetchSubTeams.fulfilled, (state, action) => {
        state.subTeams = action.payload;
        state.state = State.success;
        state.stateMessage = "Sub teams fetched successfully";
        state.errorMessage = null;
      })
      .addCase(fetchSubTeams.rejected, (state, action) => {
        state.state = State.failed;
        state.errorMessage = action.payload as string;
        state.stateMessage = null;
      })
      .addCase(fetchUnits.pending, (state) => {
        state.state = State.loading;
        state.stateMessage = "Fetching units...";
        state.errorMessage = null;
      })
      .addCase(fetchUnits.fulfilled, (state, action) => {
        state.units = action.payload;
        state.state = State.success;
        state.stateMessage = "Units fetched successfully";
        state.errorMessage = null;
      })
      .addCase(fetchUnits.rejected, (state, action) => {
        state.state = State.failed;
        state.errorMessage = action.payload as string;
        state.stateMessage = null;
      })
      .addCase(fetchCareerFunctions.pending, (state) => {
        state.state = State.loading;
        state.stateMessage = "Fetching career functions...";
        state.errorMessage = null;
      })
      .addCase(fetchCareerFunctions.fulfilled, (state, action) => {
        state.careerFunctions = action.payload;
        state.state = State.success;
        state.stateMessage = "Career functions fetched successfully";
        state.errorMessage = null;
      })
      .addCase(fetchCareerFunctions.rejected, (state, action) => {
        state.state = State.failed;
        state.errorMessage = action.payload as string;
        state.stateMessage = null;
      })
      .addCase(fetchDesignations.pending, (state) => {
        state.state = State.loading;
        state.stateMessage = "Fetching designations...";
        state.errorMessage = null;
      })
      .addCase(fetchDesignations.fulfilled, (state, action) => {
        state.designations = action.payload;
        state.state = State.success;
        state.stateMessage = "Designations fetched successfully";
        state.errorMessage = null;
      })
      .addCase(fetchDesignations.rejected, (state, action) => {
        state.state = State.failed;
        state.errorMessage = action.payload as string;
        state.stateMessage = null;
      })
      .addCase(fetchCompanies.pending, (state) => {
        state.state = State.loading;
        state.stateMessage = "Fetching companies...";
        state.errorMessage = null;
      })
      .addCase(fetchCompanies.fulfilled, (state, action) => {
        state.companies = action.payload;
        state.state = State.success;
        state.stateMessage = "Companies fetched successfully";
        state.errorMessage = null;
      })
      .addCase(fetchCompanies.rejected, (state, action) => {
        state.state = State.failed;
        state.errorMessage = action.payload as string;
        state.stateMessage = null;
      })
      .addCase(fetchOffices.pending, (state) => {
        state.state = State.loading;
        state.offices = [];
        state.stateMessage = "Fetching offices...";
        state.errorMessage = null;
      })
      .addCase(fetchOffices.fulfilled, (state, action) => {
        state.offices = action.payload;
        state.state = State.success;
        state.stateMessage = "Offices fetched successfully";
        state.errorMessage = null;
      })
      .addCase(fetchOffices.rejected, (state, action) => {
        state.state = State.failed;
        state.errorMessage = action.payload as string;
        state.stateMessage = null;
      })
      .addCase(fetchUniversities.pending, (state) => {
        state.universitiesState = State.loading;
      })
      .addCase(fetchUniversities.fulfilled, (state, action) => {
        state.universities = action.payload;
        state.universitiesState = State.success;
      })
      .addCase(fetchUniversities.rejected, (state) => {
        state.universitiesState = State.failed;
      })
      .addCase(fetchEmploymentTypes.pending, (state) => {
        state.state = State.loading;
        state.stateMessage = "Fetching employment types...";
        state.errorMessage = null;
      })
      .addCase(fetchEmploymentTypes.fulfilled, (state, action) => {
        state.employmentTypes = action.payload;
        state.state = State.success;
        state.stateMessage = "Employment types fetched successfully";
        state.errorMessage = null;
      })
      .addCase(fetchEmploymentTypes.rejected, (state, action) => {
        state.state = State.failed;
        state.errorMessage = action.payload as string;
        state.stateMessage = null;
      })
      .addCase(fetchHouses.pending, (state) => {
        state.state = State.loading;
        state.stateMessage = "Fetching houses...";
        state.errorMessage = null;
      })
      .addCase(fetchHouses.fulfilled, (state, action) => {
        state.houses = action.payload;
        state.state = State.success;
        state.stateMessage = "Houses fetched successfully";
        state.errorMessage = null;
      })
      .addCase(fetchHouses.rejected, (state, action) => {
        state.state = State.failed;
        state.errorMessage = action.payload as string;
        state.stateMessage = null;
      });
  },
});

export const { updateStateMessage, resetState } = organizationSlice.actions;
export default organizationSlice.reducer;
