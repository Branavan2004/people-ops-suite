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
import { AppConfig } from "@root/src/config/config";
import {
  Action,
  AppConfigResponse,
  ApprovalResponse,
  Employee,
  LeadReportRequest,
  LeadReportResponse,
  LeaveEntitlement,
  LeaveHistoryQueryParam,
  LeaveHistoryResponse,
  LeaveSubmissionRequest,
  LeaveSubmissionResponse,
  LeaveValidationRequest,
  LeaveValidationResponse,
  OnBehalfLeavePreview,
  OnBehalfLeaveRequest,
  PeriodType,
  SickNoteSummary,
} from "@root/src/types/types";
import { APIService } from "@root/src/utils/apiService";

/**
 * Validate leave request dates and return working days calculation.
 * @param request - Leave validation request payload
 * @returns Promise with validation response including working days
 */
export const validateLeaveRequest = async (
  request: LeaveValidationRequest,
  isValidationOnlyMode: boolean,
): Promise<LeaveValidationResponse> => {
  const apiInstance = APIService.getInstance();

  const response = await apiInstance.post<LeaveValidationResponse>(
    `${AppConfig.serviceUrls.leaves}?isValidationOnlyMode=${isValidationOnlyMode}`,
    request,
  );

  return response.data;
};

/**
 * Fetch all employees from the backend.
 * @returns Promise with array of employees
 */
export const fetchEmployees = async (): Promise<Employee[]> => {
  const apiInstance = APIService.getInstance();

  const response = await apiInstance.get<Employee[]>(
    `${AppConfig.serviceUrls.employees}?employeeStatuses=Active&employeeStatuses=Marked%20leaver&employeeStatuses=Left`,
  );

  return response.data;
};

/**
 * Submit a leave request.
 * @param request - Leave submission request payload
 * @returns Promise with submission response
 */
export const submitLeaveRequest = async (
  request: LeaveSubmissionRequest,
): Promise<LeaveSubmissionResponse> => {
  const apiInstance = APIService.getInstance();

  const response = await apiInstance.post<LeaveSubmissionResponse>(
    `${AppConfig.serviceUrls.leaves}?isValidationOnlyMode=${false}`,
    request,
  );

  return response.data;
};

/**
 * Submit a sick leave request with its sick note.
 *
 * Sent as multipart/form-data: the leave body as a JSON `leave` part and the
 * file as the `sickNote` part. The Content-Type boundary is left to the browser.
 * @param request - Leave submission request payload
 * @param sickNote - Sick note file
 * @returns Promise with submission response
 */
export const submitSickLeaveRequest = async (
  request: LeaveSubmissionRequest,
  sickNote: File,
): Promise<LeaveSubmissionResponse> => {
  const apiInstance = APIService.getInstance();

  const formData = new FormData();
  formData.append("leave", new Blob([JSON.stringify(request)], { type: "application/json" }));
  formData.append("sickNote", sickNote);

  const response = await apiInstance.post<LeaveSubmissionResponse>(
    AppConfig.serviceUrls.sickLeave,
    formData,
  );

  return response.data;
};

/**
 * Preview an on-behalf leave without recording it.
 *
 * Returns the working-day count the leave would carry and whether it overlaps
 * leave the employee already has, so the form can show both before submitting.
 */
export const previewLeaveOnBehalf = async (
  request: OnBehalfLeaveRequest,
  signal?: AbortSignal,
): Promise<OnBehalfLeavePreview> => {
  const apiInstance = APIService.getInstance();

  const response = await apiInstance.post<OnBehalfLeavePreview>(
    `${AppConfig.serviceUrls.leavesOnBehalf}?isValidationOnlyMode=${true}`,
    request,
    { signal },
  );

  return response.data;
};

/**
 * Record leave on behalf of an employee (People Ops only).
 *
 * Notifications and the calendar event follow the same path as a self-submitted
 * leave, so the employee and the leave group are notified identically.
 */
export const recordLeaveOnBehalf = async (
  request: OnBehalfLeaveRequest,
): Promise<LeaveSubmissionResponse> => {
  const apiInstance = APIService.getInstance();

  const response = await apiInstance.post<LeaveSubmissionResponse>(
    `${AppConfig.serviceUrls.leavesOnBehalf}?isValidationOnlyMode=${false}`,
    request,
  );

  return response.data;
};

/**
 * Cancel a leave request.
 */
export const cancelLeaveRequest = async (id: number) => {
  const apiInstance = APIService.getInstance();
  await apiInstance.delete(`${AppConfig.serviceUrls.leaves}/${id}`);
};

/**
 * Get a list of leave history records.
 * @param request - Leave submission request payload
 * @returns leave history data
 */
export const getLeaveHistory = async (
  params: LeaveHistoryQueryParam,
  signal?: AbortSignal,
): Promise<LeaveHistoryResponse> => {
  const apiInstance = APIService.getInstance();
  const {
    email,
    approverEmail,
    startDate,
    endDate,
    statuses,
    leaveCategory,
    orderBy,
    limit,
    offset,
    employeeStatuses,
    subordinatesLeaves,
  } = params;

  // Build query parameters
  const queryParts: string[] = [];

  if (email !== undefined && email !== null && email !== "") {
    queryParts.push(`email=${email}`);
  }
  if (approverEmail !== undefined && approverEmail !== null && approverEmail !== "") {
    queryParts.push(`approverEmail=${encodeURIComponent(approverEmail)}`);
  }
  if (startDate) {
    queryParts.push(`startDate=${encodeURIComponent(startDate)}`);
  }
  if (endDate) {
    queryParts.push(`endDate=${encodeURIComponent(endDate)}`);
  }

  // Build array parameters
  if (Array.isArray(statuses) && statuses.length > 0) {
    statuses.forEach((status) => queryParts.push(`statuses=${encodeURIComponent(String(status))}`));
  }
  if (Array.isArray(leaveCategory) && leaveCategory.length > 0) {
    leaveCategory.forEach((category) =>
      queryParts.push(`leaveCategory=${encodeURIComponent(String(category))}`),
    );
  }

  if (orderBy) {
    queryParts.push(`orderBy=${encodeURIComponent(String(orderBy))}`);
  }
  if (limit !== undefined && limit !== null) {
    queryParts.push(`limit=${encodeURIComponent(String(limit))}`);
  }
  if (offset !== undefined && offset !== null) {
    queryParts.push(`offset=${encodeURIComponent(String(offset))}`);
  }
  if (Array.isArray(employeeStatuses) && employeeStatuses.length > 0) {
    employeeStatuses.forEach((s) =>
      queryParts.push(`employeeStatuses=${encodeURIComponent(String(s))}`),
    );
  }
  if (subordinatesLeaves) {
    queryParts.push(`subordinatesLeaves=true`);
  }

  const queryString = queryParts.length > 0 ? `?${queryParts.join("&")}` : "";

  const response = await apiInstance.get<LeaveHistoryResponse>(
    `${AppConfig.serviceUrls.leaves}${queryString}`,
    { signal },
  );

  return response.data;
};

/**
 * Get a lead report.
 * @param request - request payload
 * @returns Promise with submission response
 */
export const getLeadReport = async (request: LeadReportRequest): Promise<LeadReportResponse> => {
  const apiInstance = APIService.getInstance();

  const response = await apiInstance.post<LeadReportResponse>(
    AppConfig.serviceUrls.leadReport,
    request,
  );

  return response.data;
};

/**
 * Approve or reject a leave request.
 * @param id - Leave ID
 * @param action - Approve or reject
 * @param reason - Optional reason; sent only when given (required to reject Other Authorized Leave)
 * @returns Promise with approval response
 */
export const approveLeave = async (
  id: string,
  action: Action,
  reason?: string,
): Promise<ApprovalResponse> => {
  const apiInstance = APIService.getInstance();

  const response = await apiInstance.post<ApprovalResponse>(
    `${AppConfig.serviceUrls.leaves}/${id}/${action}`,
    reason ? { reason } : undefined,
  );

  return response.data;
};

/**
 * Download the sick note file of a leave.
 * @param leaveId - Leave ID
 * @returns Promise with the file as a Blob
 */
export const downloadSickNote = async (leaveId: number): Promise<Blob> => {
  const apiInstance = APIService.getInstance();

  const response = await apiInstance.get<Blob>(
    `${AppConfig.serviceUrls.leaves}/${leaveId}/sick-note`,
    { responseType: "blob" },
  );

  return response.data;
};

/**
 * Get sick note summaries for leaves within a date range.
 * @param startDate - Range start (YYYY-MM-DD)
 * @param endDate - Range end (YYYY-MM-DD)
 * @returns Promise with array of sick note summaries
 */
export const getSickNotes = async (
  startDate: string,
  endDate: string,
): Promise<SickNoteSummary[]> => {
  const apiInstance = APIService.getInstance();

  const response = await apiInstance.get<SickNoteSummary[]>(
    `${AppConfig.serviceUrls.sickNotes}?startDate=${encodeURIComponent(startDate)}&endDate=${encodeURIComponent(endDate)}`,
  );

  return response.data;
};

/**
 * Get the application configurations.
 * @returns application configuration data
 */
export const getAppConfig = async (): Promise<AppConfigResponse> => {
  const apiInstance = APIService.getInstance();

  const response = await apiInstance.get<AppConfigResponse>(AppConfig.serviceUrls.appConfig);

  return response.data;
};

/**
 * Helper function to format date for API (YYYY-MM-DD)
 * @param date - Dayjs date object
 * @returns Formatted date string
 */
export const formatDateForApi = (date: any): string => {
  return date.format("YYYY-MM-DD");
};

/**
 * Helper function to determine period type based on days count
 * @param daysCount - Number of days selected
 * @returns Period type "one" or "multiple"
 */
export const getPeriodType = (daysCount: number): PeriodType.ONE | PeriodType.MULTIPLE => {
  return daysCount === 1 ? PeriodType.ONE : PeriodType.MULTIPLE;
};

/**
 * Fetch leave entitlement for a given employee.
 * @param email - Employee email
 * @param years - Optional array of years (defaults to current year on backend)
 * @returns Promise with array of leave entitlement records
 */
export const getLeaveEntitlement = async (
  email: string,
  years?: number[],
): Promise<LeaveEntitlement[]> => {
  const apiInstance = APIService.getInstance();

  const queryParts: string[] = [];
  if (Array.isArray(years) && years.length > 0) {
    years.forEach((y) => queryParts.push(`years=${encodeURIComponent(y)}`));
  }
  const queryString = queryParts.length > 0 ? `?${queryParts.join("&")}` : "";

  const response = await apiInstance.get<LeaveEntitlement[]>(
    `${AppConfig.serviceUrls.leaveEntitlement}/${encodeURIComponent(email)}/leave-entitlement${queryString}`,
  );

  return response.data;
};
