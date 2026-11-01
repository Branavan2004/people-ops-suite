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

import ScheduleIcon from "@mui/icons-material/Schedule";
import { Box, Button, Typography } from "@mui/material";
import { alpha } from "@mui/material/styles";

import { ConfirmationType } from "@/types/types";
import { useConfirmationModalContext } from "@context/DialogContext";
import {
  ScheduledChange,
  cancelScheduledChange,
} from "@slices/employeeSlice/scheduledChanges";
import { useAppDispatch } from "@slices/store";

/** Database column to the name a reader knows it by. */
const COLUMN_LABELS: Record<string, string> = {
  epf: "EPF",
  company_id: "Company",
  work_location: "Work Location",
  work_email: "Work Email",
  start_date: "Start Date",
  secondary_job_title: "Secondary Job Title",
  job_role: "Job Role",
  external_designation: "External Designation",
  manager_email: "Lead",
  probation_end_date: "Probation End Date",
  agreement_end_date: "Agreement End Date",
  employment_type_id: "Employment Type",
  designation_id: "Designation",
  office_id: "Office",
  team_id: "Team",
  sub_team_id: "Sub Team",
  business_unit_id: "Business Unit",
  unit_id: "Unit",
  house_id: "House",
  additional_manager_emails: "Additional Leads",
};

// Effective dates are calendar days where the employee works: the sweep applies a change
// dated the 16th once the 16th begins at their work location, whoever is reading. Rendered
// with timeZone: "UTC" only so the day shown is the day stored — a date-only string parses
// as midnight UTC, and formatting that in the reader's own zone would show the 15th
// anywhere west of UTC.
export const formatDate = (date: string) =>
  new Date(date).toLocaleDateString(undefined, {
    day: "numeric",
    month: "short",
    year: "numeric",
    timeZone: "UTC",
  });

/**
 * The changes queued against this section, shown above it.
 *
 * Without this the record reads as settled when it is not: a change scheduled months
 * ahead would be invisible until the day it lands, and whoever reads the profile in
 * between would be working from a value that is about to change.
 */
const PendingChangesBanner = ({
  employeeId,
  changes,
  canCancel,
}: {
  employeeId: string;
  changes: ScheduledChange[];
  /** Cancelling is the same permission as editing, so it follows the section's own gate. */
  canCancel: boolean;
}) => {
  const dispatch = useAppDispatch();
  const { showConfirmation } = useConfirmationModalContext();

  if (changes.length === 0) return null;

  const handleCancel = (change: ScheduledChange) => {
    const fields = Object.keys(change.changes ?? {})
      .map((column) => COLUMN_LABELS[column] ?? column)
      .join(", ");

    showConfirmation(
      "Cancel scheduled change?",
      <Typography variant="body1">
        {fields} will no longer change on {formatDate(change.effectiveDate)}.
        The record stays as it is.
      </Typography>,
      ConfirmationType.discard,
      () => {
        void dispatch(
          cancelScheduledChange({ employeeId, changeId: change.id }),
        );
      },
      "Cancel change",
      "Keep it",
    );
  };

  return (
    <Box sx={{ mb: 2 }}>
      {changes.map((change) => (
        <Box
          key={change.id}
          sx={(theme) => ({
            display: "flex",
            alignItems: "center",
            gap: 1.5,
            px: 2,
            py: 1.25,
            mb: 1,
            borderRadius: 2,
            border: 1,
            borderColor: alpha(theme.palette.secondary.contrastText, 0.35),
            backgroundColor: alpha(
              theme.palette.secondary.contrastText,
              theme.palette.mode === "dark" ? 0.12 : 0.07,
            ),
          })}
        >
          <ScheduleIcon
            sx={(theme) => ({
              fontSize: 18,
              color: theme.palette.secondary.contrastText,
            })}
          />
          <Box sx={{ flex: 1, minWidth: 0 }}>
            <Typography sx={{ fontSize: 13.5, fontWeight: 600 }}>
              {Object.keys(change.changes ?? {})
                .map((column) => COLUMN_LABELS[column] ?? column)
                .join(", ")}{" "}
              changes on {formatDate(change.effectiveDate)}
            </Typography>
            <Typography sx={{ fontSize: 12, color: "text.secondary" }}>
              Scheduled by {change.createdBy}
            </Typography>
          </Box>
          {canCancel && (
            <Button
              size="small"
              variant="text"
              onClick={() => handleCancel(change)}
              sx={{ textTransform: "none", color: "text.secondary" }}
            >
              Cancel
            </Button>
          )}
        </Box>
      ))}
    </Box>
  );
};

export default PendingChangesBanner;
