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
import SendRoundedIcon from "@mui/icons-material/SendRounded";
import { Box, Button, CircularProgress, Divider, Stack, Typography, useTheme } from "@mui/material";
import { Dayjs } from "dayjs";
import { useSnackbar } from "notistack";

import { useEffect, useState } from "react";

import { SnackMessage } from "@root/src/config/constant";
import { PAGE_MAX_WIDTH } from "@root/src/config/ui";
import { useConfirmationModalContext } from "@root/src/context/DialogContext";
import {
  formatDateForApi,
  getLeaveEntitlement,
  submitLeaveRequest,
  submitSickLeaveRequest,
} from "@root/src/services/leaveService";
import { useAppSelector } from "@root/src/slices/store";
import {
  ConfirmationType,
  DayPortion,
  EmployeeLocation,
  LeaveLabel,
  LeavePolicy,
  LeaveType,
  PeriodType,
} from "@root/src/types/types";
import { needsReason, needsSickNote, sickNoteProblem } from "@root/src/utils/leaveRules";
import AdditionalComment from "@root/src/view/GeneralLeave/component/AdditionalComment";
import LeaveBalanceSummary from "@root/src/view/GeneralLeave/component/LeaveBalanceSummary";
import LeaveDateSelection from "@root/src/view/GeneralLeave/component/LeaveDateSelection";
import LeaveSelection from "@root/src/view/GeneralLeave/component/LeaveSelection";
import NotifyPeople from "@root/src/view/GeneralLeave/component/NotifyPeople";
import SickNoteUpload from "@root/src/view/GeneralLeave/component/SickNoteUpload";

export default function GeneralLeave() {
  const theme = useTheme();
  const { enqueueSnackbar } = useSnackbar();
  const { showConfirmation } = useConfirmationModalContext();
  const userInfo = useAppSelector((state) => state.user.userInfo);
  const userLocation = userInfo?.location ?? null;
  const email = userInfo?.workEmail ?? "";
  const appConfig = useAppSelector((state) => state.appConfig.config);

  const getDefaultLeaveType = (location: string | null): LeaveType => {
    switch (location) {
      case EmployeeLocation.FR:
        return LeaveType.CONGES_PAYES;
      case EmployeeLocation.ES:
        return LeaveType.ANNUAL;
      case EmployeeLocation.IN:
        return LeaveType.ANNUAL;
      default:
        return LeaveType.CASUAL;
    }
  };

  const LEAVE_TYPE_KEY_MAP: Record<string, string> = {
    [LeaveType.CONGES_PAYES]: "congesPayes",
    [LeaveType.RTT]: "rtt",
    [LeaveType.SICK]: "sick",
    [LeaveType.CASUAL]: "casual",
    [LeaveType.ANNUAL]: "annual",
  };

  const LEAVE_TYPE_LABEL_MAP: Record<string, string> = {
    [LeaveType.CONGES_PAYES]: LeaveLabel.CONGES_PAYES,
    [LeaveType.RTT]: LeaveLabel.RTT,
    [LeaveType.SICK]: LeaveLabel.SICK,
    [LeaveType.CASUAL]: LeaveLabel.CASUAL,
    [LeaveType.ANNUAL]: LeaveLabel.CASUAL,
    [LeaveType.COMPASSIONATE]: LeaveLabel.COMPASSIONATE,
    [LeaveType.OTHER_AUTHORIZED]: LeaveLabel.OTHER_AUTHORIZED,
  };

  const [daysSelected, setDaysSelected] = useState(0);
  const [workingDays, setWorkingDays] = useState(0);
  const [startDate, setStartDate] = useState<Dayjs | null>(null);
  const [endDate, setEndDate] = useState<Dayjs | null>(null);
  const [selectedLeaveType, setSelectedLeaveType] = useState<LeaveType>(
    getDefaultLeaveType(userLocation),
  );
  const [selectedDayPortion, setSelectedDayPortion] = useState<DayPortion | null>(null);
  const [emailRecipients, setEmailRecipients] = useState<string[]>([]);
  const [mandatoryEmails, setMandatoryEmails] = useState<string[]>([]);
  const [comment, setComment] = useState("");
  const [isPublicComment, setIsPublicComment] = useState(false);
  const [isSubmitting, setIsSubmitting] = useState(false);
  const [isDateValidating, setIsDateValidating] = useState(false);
  const [dateError, setDateError] = useState(false);
  const [balanceKey, setBalanceKey] = useState(0);
  const [sickNote, setSickNote] = useState<File | null>(null);

  const sickNoteRequired = needsSickNote(userLocation, selectedLeaveType);
  const sickNoteLimitsLoaded = !!appConfig;
  const sickNoteError =
    sickNoteRequired && sickNote && appConfig
      ? sickNoteProblem(sickNote, appConfig.sickNoteMaxBytes, appConfig.sickNoteContentTypes)
      : "";
  const sickNoteReady = !sickNoteRequired || (!!sickNote && sickNoteLimitsLoaded && !sickNoteError);
  const reasonRequired = needsReason(selectedLeaveType);
  const reasonMissing = reasonRequired && !comment.trim();

  useEffect(() => {
    setSelectedLeaveType(getDefaultLeaveType(userLocation));
  }, [userLocation]);

  // The reason for Other Authorized Leave is for the lead, so it is never public.
  useEffect(() => {
    if (reasonRequired) setIsPublicComment(false);
  }, [reasonRequired]);

  // A sick note belongs to a sick leave request only.
  useEffect(() => {
    if (!sickNoteRequired) setSickNote(null);
  }, [sickNoteRequired]);

  const executeSubmit = async (periodType: PeriodType, isMorningLeave: boolean | null) => {
    try {
      setIsSubmitting(true);

      const filteredEmailRecipients = emailRecipients.filter(
        (recipientEmail) => !mandatoryEmails.includes(recipientEmail),
      );

      const payload = {
        periodType,
        startDate: formatDateForApi(startDate!),
        endDate: formatDateForApi(endDate!),
        isMorningLeave,
        comment,
        leaveType: selectedLeaveType as any,
        emailRecipients: filteredEmailRecipients,
        isPublicComment: reasonRequired ? false : isPublicComment,
      };

      if (userLocation === EmployeeLocation.FR || userLocation === EmployeeLocation.ES) {
        try {
          const entitlements = await getLeaveEntitlement(email);
          if (entitlements.length > 0) {
            const ent = entitlements[0];
            const leaveTypeKey = LEAVE_TYPE_KEY_MAP[selectedLeaveType] ?? null;
            if (leaveTypeKey) {
              const policyKey = leaveTypeKey as keyof LeavePolicy;
              const entitled = ent.leavePolicy[policyKey] ?? 0;
              const consumed = ent.policyAdjustedLeave[policyKey] ?? 0;
              if (entitled > 0 && consumed + workingDays > entitled) {
                const label = LEAVE_TYPE_LABEL_MAP[selectedLeaveType] ?? selectedLeaveType;
                enqueueSnackbar(
                  `This request will exceed your ${label} entitlement (${consumed + workingDays}/${entitled} days)`,
                  { variant: "warning" },
                );
              }
            }
          }
        } catch {}
      }

      if (sickNoteRequired && sickNote) {
        await submitSickLeaveRequest(payload, sickNote);
      } else {
        await submitLeaveRequest(payload);
      }

      enqueueSnackbar(
        selectedLeaveType === LeaveType.OTHER_AUTHORIZED
          ? SnackMessage.success.submitOtherAuthorizedLeaveMessage
          : "Leave request submitted successfully!",
        { variant: "success" },
      );
      setBalanceKey((k) => k + 1);

      setStartDate(null);
      setEndDate(null);
      setSelectedLeaveType(getDefaultLeaveType(userLocation));
      setSelectedDayPortion(null);
      setComment("");
      setIsPublicComment(false);
      setSickNote(null);
    } catch (error: any) {
      const errorMessage =
        error?.response?.data?.message || "Failed to submit leave request. Please try again.";
      enqueueSnackbar(errorMessage, { variant: "error" });
    } finally {
      setIsSubmitting(false);
    }
  };

  const handleSubmit = () => {
    setDateError(false);
    if (!startDate || !endDate) {
      setDateError(true);
      enqueueSnackbar("Please select start and end dates", { variant: "error" });
      return;
    }

    if (workingDays <= 0) {
      setDateError(true);
      enqueueSnackbar("Working days must be at least 1 to submit a leave request", {
        variant: "error",
      });
      return;
    }

    if (!selectedDayPortion) {
      enqueueSnackbar("Please select a portion of the day", { variant: "error" });
      return;
    }

    if (!selectedLeaveType) {
      enqueueSnackbar("Please select a leave type", { variant: "error" });
      return;
    }

    if (!sickNoteReady) {
      enqueueSnackbar("Please attach a valid sick note", { variant: "error" });
      return;
    }

    if (reasonMissing) {
      enqueueSnackbar("Please tell your lead why you need this leave", { variant: "error" });
      return;
    }

    let periodType: PeriodType;
    let isMorningLeave: boolean | null = null;

    switch (selectedDayPortion) {
      case DayPortion.FULL:
        periodType = daysSelected === 1 ? PeriodType.ONE : PeriodType.MULTIPLE;
        break;
      case DayPortion.FIRST:
        periodType = PeriodType.HALF;
        isMorningLeave = true;
        break;
      case DayPortion.SECOND:
        periodType = PeriodType.HALF;
        isMorningLeave = false;
        break;
      default:
        periodType = daysSelected === 1 ? PeriodType.ONE : PeriodType.MULTIPLE;
        break;
    }

    const leaveLabel = LEAVE_TYPE_LABEL_MAP[selectedLeaveType] ?? selectedLeaveType;
    const portionLabel =
      selectedDayPortion === DayPortion.FULL
        ? "Full day"
        : selectedDayPortion === DayPortion.FIRST
          ? "Morning"
          : "Afternoon";
    const dateRange = startDate!.isSame(endDate, "day")
      ? startDate!.format("MMM D, YYYY")
      : `${startDate!.format("MMM D")} – ${endDate!.format("MMM D, YYYY")}`;

    showConfirmation(
      "Do you want to submit this leave?",
      selectedLeaveType === LeaveType.OTHER_AUTHORIZED
        ? `This will send an ${leaveLabel} request for ${workingDays} working day${workingDays !== 1 ? "s" : ""} (${dateRange}, ${portionLabel}) to your lead for approval.`
        : `This will submit a ${leaveLabel} request for ${workingDays} working day${workingDays !== 1 ? "s" : ""} (${dateRange}, ${portionLabel}).`,
      ConfirmationType.send,
      () => executeSubmit(periodType, isMorningLeave),
      "Yes",
      "No",
    );
  };

  const sectionCard = {
    backgroundColor: theme.palette.background.paper,
    border: `1px solid ${theme.palette.customBorder.territory.active}`,
    borderRadius: "12px",
    p: { xs: 2, md: 3 },
  };

  return (
    <Stack direction="column" gap={2.5} maxWidth={PAGE_MAX_WIDTH} mx="auto">
      {/* Page Header */}
      <Box>
        <Typography
          variant="h4"
          sx={{
            color: theme.palette.customText.primary.p1.active,
            fontWeight: 600,
          }}
        >
          <Box component="span" sx={{ color: theme.palette.primary.main }}>
            General
          </Box>{" "}
          Leave Submission
        </Typography>
        <Typography
          variant="body2"
          sx={{ color: theme.palette.customText.primary.p3.active, mt: 0.5 }}
        >
          Submit your leave request by filling in the details below
        </Typography>
      </Box>

      {/* Leave Balance (France/Spain only) */}
      <LeaveBalanceSummary key={balanceKey} />

      {/* Date & Leave Type Section */}
      <Box sx={sectionCard}>
        <Stack
          direction={{ xs: "column", lg: "row" }}
          gap={3}
          divider={
            <Divider
              orientation="vertical"
              flexItem
              sx={{
                display: { xs: "none", lg: "block" },
                borderColor: theme.palette.customBorder.territory.active,
              }}
            />
          }
        >
          <LeaveDateSelection
            onDaysChange={setDaysSelected}
            selectedDayPortion={selectedDayPortion}
            onDatesChange={(start, end) => {
              setStartDate(start);
              setEndDate(end);
            }}
            onWorkingDaysChange={setWorkingDays}
            onValidatingChange={setIsDateValidating}
            hasError={dateError}
            onErrorClear={() => setDateError(false)}
            selectedLeaveType={selectedLeaveType}
          />

          {/* Mobile-only horizontal divider */}
          <Divider
            sx={{
              display: { xs: "block", lg: "none" },
              borderColor: theme.palette.customBorder.territory.active,
            }}
          />

          <LeaveSelection
            daysSelected={daysSelected}
            selectedLeaveType={selectedLeaveType}
            onLeaveTypeChange={setSelectedLeaveType}
            selectedDayPortion={selectedDayPortion}
            onDayPortionChange={setSelectedDayPortion}
            location={userLocation}
          />
        </Stack>
      </Box>

      {/* Sick note (France sick leave only) */}
      {sickNoteRequired && (
        <Box sx={sectionCard}>
          <SickNoteUpload
            file={sickNote}
            problem={sickNoteError}
            maxBytes={appConfig?.sickNoteMaxBytes ?? 0}
            contentTypes={appConfig?.sickNoteContentTypes ?? []}
            onChange={setSickNote}
          />
        </Box>
      )}

      {/* Notify & Comment Section */}
      <Box sx={sectionCard}>
        <Stack gap={3}>
          <NotifyPeople
            selectedEmails={emailRecipients}
            onEmailsChange={setEmailRecipients}
            onMandatoryEmailsChange={setMandatoryEmails}
          />

          <Divider sx={{ borderColor: theme.palette.customBorder.territory.active }} />

          <AdditionalComment
            comment={comment}
            onCommentChange={setComment}
            isPublicComment={isPublicComment}
            onPublicCommentChange={setIsPublicComment}
            reasonRequired={reasonRequired}
          />
        </Stack>
      </Box>

      {/* Submit Bar */}
      <Box
        sx={{
          ...sectionCard,
          display: "flex",
          justifyContent: "flex-end",
          alignItems: "center",
          gap: 2,
        }}
      >
        <Typography variant="caption" sx={{ color: theme.palette.customText.primary.p4.active }}>
          {reasonRequired
            ? "Your reason goes to your lead for approval and is never made public."
            : isPublicComment
              ? "Your comment will be visible to all email recipients."
              : "Your comment will be visible to all email recipients except the WSO2 Vacation Group."}
        </Typography>
        <Button
          variant="contained"
          onClick={handleSubmit}
          disabled={isSubmitting || isDateValidating || !sickNoteReady || reasonMissing}
          startIcon={
            isSubmitting || isDateValidating ? (
              <CircularProgress size={18} color="inherit" />
            ) : (
              <SendRoundedIcon sx={{ fontSize: 18 }} />
            )
          }
          sx={{
            px: 4,
            py: 1,
            borderRadius: "10px",
            fontWeight: 600,
            textTransform: "none",
            minWidth: 140,
          }}
        >
          {isSubmitting
            ? "Submitting\u2026"
            : isDateValidating
              ? "Validating\u2026"
              : "Submit Leave"}
        </Button>
      </Box>
    </Stack>
  );
}
