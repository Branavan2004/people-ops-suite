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

import React, {
  useEffect,
  useCallback,
  useMemo,
  useState,
  useRef,
} from "react";
import {
  Box,
  Grid,
  TextField,
  Typography,
  MenuItem,
  useTheme,
  alpha,
  Popover,
  FormControlLabel,
  Checkbox,
  Chip,
  Stack,
  InputAdornment,
  IconButton,
  Autocomplete,
  Alert,
} from "@mui/material";
import { useFormikContext } from "formik";
import * as Yup from "yup";
import { useAppDispatch, useAppSelector } from "@slices/store";
import {
  fetchEmployeesBasicInfo,
  fetchContinuousServiceRecord,
  resetContinuousService,
  validateEpf,
  lookupReturningEmployee,
  type ContinuousServiceRecordInfo,
  type ReturningEmployeeLookup,
} from "@slices/employeeSlice/employee";
import { EmployeeStatus } from "@/types/types";
import {
  RESIGNATION_DATE_ORDER_MESSAGE,
  isPlaceholderWorkEmail,
  isResignationDateOrderValid,
  normalizeEmail,
  sortAndFormatOptions,
} from "@utils/utils";
import { ResignationReasons } from "@config/constant";
import {
  canonicalizeReason,
  shouldOfferCustomReason,
} from "@view/employees/onboarding/singleOnboarding/steps/resignationReason.utils";
import {
  fetchBusinessUnits,
  fetchTeams,
  fetchSubTeams,
  fetchUnits,
  fetchCareerFunctions,
  fetchDesignations,
  fetchCompanies,
  fetchOffices,
  fetchEmploymentTypes,
  fetchHouses,
} from "@slices/organizationSlice/organization";
import { CreateEmployeeFormValues } from "@root/src/types/types";
import { DatePicker } from "@mui/x-date-pickers/DatePicker";
import {
  BadgeOutlined,
  WorkOutline,
  LocationOnOutlined,
  EventOutlined,
  SupervisorAccountOutlined,
  InfoOutlined,
  Close,
  WidgetsOutlined,
  LogoutOutlined,
} from "@mui/icons-material";
import dayjs from "dayjs";
import {
  isEligiblePriorEmployment,
  isStaleContinuousServiceLink,
} from "@utils/continuousService";

import {
  OFFICE_CLEAR_SENTINEL,
  UNIT_CLEAR_SENTINEL,
} from "@slices/careerFunctionSlice/careerFunction";

// Sentinel for the synthetic "Add "<text>"" row offered by the resignation-reason
// Autocomplete's filterOptions. It is a distinct OBJECT type (not a string) so it
// can never collide with real user-typed text, unlike a string-based marker such
// as `Add "${input}"`, which a literal user string could reproduce.
interface AddCustomReasonOption {
  addCustom: true;
  value: string;
}

const SECTION_ICONS = {
  badge: <BadgeOutlined />,
  work: <WorkOutline />,
  location: <LocationOnOutlined />,
  event: <EventOutlined />,
  leaver: <LogoutOutlined />,
  supervisor: <SupervisorAccountOutlined />,
  other: <WidgetsOutlined />,
};

const SECTION_HEADER_BOX_SX = {
  display: "flex",
  alignItems: "center",
  gap: 1.5,
  mb: 3,
  mt: 4,
} as const;

export const createJobInfoValidationSchema = (
  employmentTypes?: { id: number; name: string }[],
  // Onboarding has no House field to fill in, so the requirement below is only applied
  // where there is one to answer it — see the note on houseId.
  {
    requireHouse = true,
    // Onboarding may leave the work email empty for a joiner whose account is not created
    // yet, and must not be given a placeholder by hand. Existing records keep requiring one,
    // and may already hold a placeholder, so that check is onboarding-only.
    requireWorkEmail = true,
  }: { requireHouse?: boolean; requireWorkEmail?: boolean } = {},
) =>
  Yup.object().shape({
    workEmail: requireWorkEmail
      ? Yup.string()
          .required("Work email is required")
          .email("Invalid email format")
          .max(254, "Email must be at most 254 characters")
      : Yup.string()
          .email("Invalid email format")
          .max(254, "Email must be at most 254 characters")
          .test(
            "not-placeholder",
            "Leave the work email empty when the account is not created yet",
            (value) => !value || !isPlaceholderWorkEmail(value),
          ),
    epf: Yup.string()
      .max(45, "EPF must be at most 45 characters")
      .transform((value) => (value === "" ? null : value))
      .nullable(),
    businessUnitId: Yup.number()
      .required("Business unit is required")
      .min(1, "Select a valid business unit"),
    teamId: Yup.number()
      .required("Team is required")
      .min(1, "Select a valid team"),
    subTeamId: Yup.number().optional(),
    unitId: Yup.number().optional(),
    careerFunctionId: Yup.number()
      .required("Career function is required")
      .min(1, "Select a valid career function"),
    designationId: Yup.number()
      .required("Designation is required")
      .min(1, "Select a valid designation"),
    secondaryJobTitle: Yup.string()
      .max(20, "Secondary job title must be at most 20 characters")
      .transform((value) => (value === "" ? null : value))
      .nullable(),
    jobRole: Yup.string()
      .max(100, "Job role must be at most 100 characters")
      .transform((value) => (value === "" ? null : value))
      .nullable(),
    externalDesignation: Yup.string()
      .max(100, "External designation must be at most 100 characters")
      .transform((value) =>
        typeof value === "string" && value.trim() === "" ? null : value,
      )
      .nullable(),
    companyId: Yup.number()
      .required("Company is required")
      .min(1, "Select a valid company"),
    // Every employee belongs to a house. Onboarding assigns one on the server — from the
    // employee's previous employment where they are rejoining, otherwise derived from the
    // employee ID — and shows no House field, so requiring one there would fail a form
    // that offers no way to satisfy it.
    //
    // The profile editor does show the field, and there a missing house means a record
    // predating automatic assignment: it has to be set before the record can be saved
    // again, since a house-less employee cannot have a QR code generated.
    houseId: requireHouse
      ? Yup.number().required("House is required").min(1, "Select a valid house")
      : Yup.number().nullable(),
    officeId: Yup.number()
      .optional()
      .notOneOf([0], 'Select an office or explicitly choose "None"'),
    workLocation: Yup.string()
      .required("Work location is required")
      .min(1, "Select a valid work location"),
    employmentTypeId: Yup.number()
      .required("Employment type is required")
      .min(1, "Select a valid employment type"),
    startDate: Yup.string().required("Start date is required"),
    probationEndDate: Yup.string()
      .transform((value) => (value === "" ? null : value))
      .nullable(),
    agreementEndDate: Yup.string()
      .transform((value) => (value === "" ? null : value))
      .nullable(),
    managerEmail: Yup.string().required("Lead email is required"),
    additionalManagerEmail: Yup.array()
      .of(Yup.string().email("Invalid email format"))
      .nullable(),
    finalDayInOffice: Yup.string()
      .matches(/^\d{4}-\d{2}-\d{2}$/, "Invalid date format")
      .transform((value) => (value === "" ? null : value))
      .nullable()
      .when("employeeStatus", {
        is: (status: string) =>
          status === EmployeeStatus.MarkedLeaver || status === EmployeeStatus.Left,
        then: (schema) =>
          schema.required("Required when status is Marked leaver or Left"),
      }),
    finalDayOfEmployment: Yup.string()
      .matches(/^\d{4}-\d{2}-\d{2}$/, "Invalid date format")
      .transform((value) => (value === "" ? null : value))
      .nullable()
      .when("employeeStatus", {
        is: (status: string) =>
          status === EmployeeStatus.MarkedLeaver || status === EmployeeStatus.Left,
        then: (schema) =>
          schema.required("Required when status is Marked leaver or Left"),
      })
      // Employment cannot end before someone stops coming in. The same day is valid.
      .test(
        "after-final-day-in-office",
        RESIGNATION_DATE_ORDER_MESSAGE,
        function (value) {
          return isResignationDateOrderValid(
            this.parent.finalDayInOffice,
            value,
          );
        },
      ),
    resignationReason: Yup.string()
      .max(300, "Resignation reason must be at most 300 characters")
      .transform((value) =>
        typeof value === "string" && value.trim() === "" ? null : value,
      )
      .nullable()
      .when("employeeStatus", {
        is: (status: string) =>
          status === EmployeeStatus.MarkedLeaver || status === EmployeeStatus.Left,
        then: (schema) =>
          schema.required("Required when status is Marked leaver or Left"),
      }),
    employeeId: Yup.string()
      .trim()
      .transform((value) => (value === "" ? null : value))
      .nullable()
      .when(
        "employmentTypeId",
        (employmentTypeId: number | undefined, schema: any) => {
          if (!employmentTypeId) return schema;
          if (!employmentTypes || employmentTypes.length === 0) return schema;
          const selected = employmentTypes.find(
            (et) => et.id === employmentTypeId,
          );
          const isFixed = selected
            ? FIXED_TERM_EMPLOYMENT_TYPE.test((selected.name || "").trim())
            : false;
          return isFixed
            ? schema.required(
              "Employee ID is required for fixed-term employment",
            )
            : schema;
        },
      ),
  });

const SectionHeader = React.memo(
  ({ icon, title, headerBoxSx, iconBoxSx }: any) => {
    return (
      <Box
        sx={{
          display: "flex",
          alignItems: "center",
          gap: 1.5,
          ...headerBoxSx,
        }}
      >
        <Box sx={iconBoxSx}>{icon}</Box>
        <Typography variant="h6" fontWeight={600}>
          {title}
        </Typography>
      </Box>
    );
  },
);

const ContinuousServicePopoverContent = React.memo(
  ({ record }: { record: ContinuousServiceRecordInfo | null | undefined }) => {
    if (!record) return null;

    const fields = [
      { label: "Employee ID", value: record.employeeId },
      {
        label: "Name",
        value: `${record.firstName || ""} ${record.lastName || ""}`.trim(),
      },
      { label: "Designation", value: record.designation },
      { label: "Company", value: record.company },
      { label: "Work Location", value: record.workLocation },
      {
        label: "Start Date",
        value: record.startDate
          ? dayjs(record.startDate).format("YYYY-MM-DD")
          : null,
      },
      { label: "Lead Email", value: record.managerEmail },
      { label: "Additional Leads", value: record.additionalManagerEmails },
      { label: "Business Unit", value: record.businessUnit },
      { label: "Team", value: record.team },
      ...(record.subTeam ? [{ label: "Sub Team", value: record.subTeam }] : []),
      ...(record.unit ? [{ label: "Unit", value: record.unit }] : []),
    ].filter((f) => f.value !== null && f.value !== undefined);

    return (
      <Box sx={{ minWidth: 300, maxWidth: 380 }}>
        <Box
          sx={{
            display: "flex",
            alignItems: "center",
            gap: 1,
            mb: 2,
          }}
        >
          <Box
            sx={{
              width: 3,
              height: 18,
              borderRadius: 1,
              bgcolor: "secondary.contrastText",
              flexShrink: 0,
            }}
          />
          <Typography
            sx={{
              fontWeight: 600,
              color: "secondary.contrastText",
              fontSize: "0.8rem",
              letterSpacing: "0.03em",
            }}
          >
            Continuous Service Record
          </Typography>
        </Box>

        <Box sx={{ display: "flex", flexDirection: "column", gap: 0.5 }}>
          {fields.map((f, i) => (
            <Box
              key={f.label}
              sx={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "baseline",
                gap: 3,
                px: 1.25,
                py: 0.75,
                borderRadius: 1,
                bgcolor: (t) =>
                  i % 2 === 0
                    ? alpha(t.palette.action.hover, 0.04)
                    : "transparent",
              }}
            >
              <Typography
                sx={{
                  color: "text.disabled",
                  fontSize: "0.72rem",
                  flexShrink: 0,
                  lineHeight: 1.5,
                }}
              >
                {f.label}
              </Typography>
              <Typography
                sx={{
                  fontSize: "0.78rem",
                  fontWeight: 600,
                  textAlign: "right",
                  wordBreak: "break-word",
                  lineHeight: 1.5,
                  color: "text.primary",
                }}
              >
                {f.value}
              </Typography>
            </Box>
          ))}
        </Box>
      </Box>
    );
  },
);

const InfoPopoverAdornment = React.memo(
  ({ record }: { record: ContinuousServiceRecordInfo | null | undefined }) => {
    const theme = useTheme();
    const [anchorEl, setAnchorEl] = useState<HTMLButtonElement | null>(null);

    return (
      <InputAdornment position="end">
        <IconButton
          size="small"
          onClick={(e) => setAnchorEl(e.currentTarget)}
          sx={{
            p: 0.5,
            color: alpha(theme.palette.secondary.contrastText, 0.7),
            "&:hover": {
              color: theme.palette.secondary.contrastText,
              bgcolor: alpha(theme.palette.secondary.contrastText, 0.08),
            },
            transition: "color 0.15s, background-color 0.15s",
          }}
          aria-label="Show continuous service record details"
        >
          <InfoOutlined fontSize="small" />
        </IconButton>

        <Popover
          open={Boolean(anchorEl)}
          anchorEl={anchorEl}
          onClose={() => setAnchorEl(null)}
          anchorOrigin={{ vertical: "bottom", horizontal: "right" }}
          transformOrigin={{ vertical: "top", horizontal: "right" }}
          slotProps={{
            paper: {
              sx: {
                mt: 1,
                p: 2,
                bgcolor: "background.form",
                border: `1px solid ${alpha(theme.palette.secondary.contrastText, 0.2)}`,
                borderRadius: 2,
                boxShadow: `0 4px 20px ${alpha(theme.palette.common.black, 0.15)}`,
              },
            },
          }}
        >
          <ContinuousServicePopoverContent record={record} />
        </Popover>
      </InputAdornment>
    );
  },
);

export const AUTO_ID_EMPLOYMENT_TYPES =
  /^(permanent|internship|consultancy|advisory consultancy|part time consultancy|probation)$/i;

export const FIXED_TERM_EMPLOYMENT_TYPE = /^fixed\s+term\s+contract$/i;

export const PROBATION_EMPLOYMENT_TYPE = /^probation$/i;

export default function JobInfoStep({ isEditMode }: { isEditMode: boolean }) {
  const theme = useTheme();
  const dispatch = useAppDispatch();
  const {
    values,
    handleChange,
    handleBlur,
    touched,
    errors,
    setFieldValue,
    setFieldError,
    setFieldTouched,
  } = useFormikContext<CreateEmployeeFormValues>();
  const {
    employeesBasicInfo,
    employeeBasicInfoState,
    continuousServiceRecord: serviceRecords,
    continuousServiceRecordEmail: serviceRecordsEmail,
    errorMessage,
  } = useAppSelector((s) => s.employee);
  // Only an earlier employment under this address that has ended or is ending (Left or
  // Marked leaver, as in a relocation) can be carried over; the backend enforces the same
  // rule on create.
  const continuousServiceRecord = useMemo(
    () =>
      serviceRecords.filter((record) =>
        isEligiblePriorEmployment(record, values.startDate),
      ),
    [serviceRecords, values.startDate],
  );
  // Clears a link whose record is no longer offered (e.g. the start date moved before
  // it), so a stale id is never sent and a hidden checkbox never stays ticked. It only
  // acts on a list fetched for this form's work email, never on one still loading or
  // left over from another page.
  const recordsLoadedForThisEmail =
    serviceRecordsEmail != null &&
    serviceRecordsEmail === normalizeEmail(values.workEmail ?? "");
  useEffect(() => {
    if (
      recordsLoadedForThisEmail &&
      isStaleContinuousServiceLink(
        continuousServiceRecord,
        values.continuousServiceRecord,
      )
    ) {
      setFieldValue("continuousServiceRecord", null);
      setFieldValue("isRelocation", false);
    }
  }, [
    recordsLoadedForThisEmail,
    continuousServiceRecord,
    values.continuousServiceRecord,
    setFieldValue,
  ]);

  // This step clears the prior records when it is left (see the unmount cleanup below)
  // and otherwise loads them only when Work Email loses focus. Coming back to the step
  // with an email already entered would then show "No Record" while the form still held
  // a ticked relocation link, so the records are loaded again as the step opens.
  useEffect(() => {
    const email = normalizeEmail(values.workEmail ?? "");
    if (email && Yup.string().email().isValidSync(email)) {
      dispatch(fetchContinuousServiceRecord(email));
    }
    // Once, on open; later email edits re-fetch on blur as before.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // Who the NIC/Passport from the previous step belongs to, so a returning employee is
  // recognised before submitting: the backend refuses someone still employed, and requires
  // a rehire to keep a work email they held. Onboarding only — an existing record being
  // edited is not someone returning.
  const [returningEmployee, setReturningEmployee] =
    useState<ReturningEmployeeLookup | null>(null);
  const nicOrPassport = values.personalInfo?.nicOrPassport?.trim() ?? "";
  useEffect(() => {
    if (isEditMode || !nicOrPassport) {
      setReturningEmployee(null);
      return;
    }
    let cancelled = false;
    dispatch(lookupReturningEmployee(nicOrPassport))
      .unwrap()
      .then((result) => {
        if (cancelled) return;
        setReturningEmployee(result);
        // Fill in the email a rehire has to use, unless one has been typed already.
        const formerEmail = result.formerWorkEmail;
        if (formerEmail && !result.isCurrentEmployee && !(values.workEmail ?? "").trim()) {
          setFieldValue("workEmail", formerEmail);
          dispatch(fetchContinuousServiceRecord(formerEmail));
        }
      })
      .catch(() => {
        if (!cancelled) setReturningEmployee(null);
      });
    return () => {
      cancelled = true;
    };
    // Looked up as the step opens; the NIC is entered on the previous step.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [isEditMode, nicOrPassport]);

  const identityNotice = useMemo((): {
    severity: "error" | "warning" | "info";
    message: string;
  } | null => {
    const nameAndId = (m: {
      firstName: string | null;
      lastName: string | null;
      employeeId: string;
    }) =>
      `${`${m.firstName ?? ""} ${m.lastName ?? ""}`.trim() || "N/A"} (${m.employeeId})`;
    // Matches the backend: only an Active or New joiner employee holds on to their email. A
    // Marked leaver's email is free, so an employee who relocates can keep it.
    const isCurrent = (status: string) =>
      status === EmployeeStatus.Active || status === EmployeeStatus.NewJoiner;

    const former = returningEmployee?.latestEmployment ?? null;
    if (former && returningEmployee?.isCurrentEmployee) {
      return {
        severity: "error",
        message: `This NIC/Passport belongs to ${nameAndId(former)}, who is ${former.employeeStatus}. They can't be onboarded again.`,
      };
    }
    if (former && returningEmployee?.formerWorkEmail) {
      return {
        severity: "info",
        message: `Returning employee: ${nameAndId(former)}. To rehire them, use a work email they held before — ${returningEmployee.formerWorkEmail}.`,
      };
    }
    if (former) {
      return {
        severity: "info",
        message: `Returning employee: ${nameAndId(former)}. Their previous work email isn't on record — enter their work email, or leave it empty if the account isn't created yet.`,
      };
    }

    // The NIC matched nobody, but the email did: either it is taken, or a former employee is
    // coming back under a different NIC, whose earlier employment can still be linked.
    if (!recordsLoadedForThisEmail || serviceRecords.length === 0) return null;
    const currentHolder = serviceRecords.find((r) => isCurrent(r.employeeStatus));
    if (currentHolder) {
      return {
        severity: "warning",
        message: `${values.workEmail} is already in use by ${nameAndId(currentHolder)}.`,
      };
    }
    return {
      severity: "info",
      message: `This work email belonged to ${nameAndId(serviceRecords[0])}. If this is the same person, link their earlier employment with the Relocation option.`,
    };
  }, [returningEmployee, recordsLoadedForThisEmail, serviceRecords, values.workEmail]);

  const {
    state: organizationState,
    businessUnits,
    teams,
    subTeams,
    units,
    careerFunctions,
    designations,
    companies,
    offices,
    employmentTypes,
    houses,
  } = useAppSelector((state) => state.organization);

  const [selectedRecordIndex, setSelectedRecordIndex] = useState<number | null>(
    null,
  );

  const initialLoadRef = useRef({
    teams: false,
    subTeams: false,
    units: false,
    designations: false,
    offices: false,
  });

  const latestEpfRef = useRef<string>("");

  const textFieldSx = useMemo(
    () => ({
      "& .MuiOutlinedInput-root": {
        "&:not(.Mui-disabled):hover fieldset": {
          borderColor: alpha(theme.palette.secondary.contrastText, 0.5),
        },
        "&.Mui-focused fieldset": {
          borderColor: theme.palette.secondary.contrastText,
        },
      },
      "& .MuiInputLabel-root.Mui-focused": {
        color: theme.palette.secondary.contrastText,
      },
    }),
    [theme],
  );

  const iconBoxSx = useMemo(
    () => ({
      display: "flex",
      alignItems: "center",
      justifyContent: "center",
      width: 40,
      height: 40,
      borderRadius: 2,
      background: `linear-gradient(135deg, ${alpha(
        theme.palette.secondary.contrastText,
        0.2,
      )}, ${alpha(theme.palette.secondary.contrastText, 0.1)})`,
      color: theme.palette.secondary.contrastText,
    }),
    [theme],
  );

  const disabledSx = useMemo(
    () => ({
      "& .MuiOutlinedInput-root.Mui-disabled": {
        backgroundColor: alpha(theme.palette.action.disabledBackground, 0.05),
      },
    }),
    [theme],
  );

  const managerEmailOptions = useMemo(() => {
    const list = sortAndFormatOptions(
      employeesBasicInfo.map((e) => e.workEmail).filter(Boolean),
      (email) => email,
    );
    if (values.managerEmail && !list.includes(values.managerEmail)) {
      return [values.managerEmail, ...list];
    }
    return list;
  }, [employeesBasicInfo, values.managerEmail]);

  const additionalManagerOptions = useMemo(() => {
    const list = sortAndFormatOptions(
      employeesBasicInfo.map((e) => e.workEmail).filter(Boolean),
      (email) => email,
    );
    const selected = values.additionalManagerEmail ?? [];
    const missing = selected.filter((email) => email && !list.includes(email));
    return [...missing, ...list];
  }, [employeesBasicInfo, values.additionalManagerEmail]);

  useEffect(() => {
    dispatch(fetchBusinessUnits());
    dispatch(fetchCompanies());
    dispatch(fetchCareerFunctions());
    dispatch(fetchEmployeesBasicInfo());
    dispatch(fetchEmploymentTypes());
    dispatch(fetchHouses());

    return () => {
      dispatch(resetContinuousService());
    };
  }, [dispatch]);

  useEffect(() => {
    const hasInitialValues =
      values.businessUnitId > 0 ||
      values.careerFunctionId > 0 ||
      values.companyId > 0;

    if (!hasInitialValues) return;

    if (values.businessUnitId > 0 && !initialLoadRef.current.teams) {
      dispatch(fetchTeams({ id: values.businessUnitId }));
      initialLoadRef.current.teams = true;
    }
    if (values.teamId > 0 && !initialLoadRef.current.subTeams) {
      dispatch(fetchSubTeams({ id: values.teamId }));
      initialLoadRef.current.subTeams = true;
    }
    if (values.subTeamId > 0 && !initialLoadRef.current.units) {
      dispatch(fetchUnits({ id: values.subTeamId }));
      initialLoadRef.current.units = true;
    }
    if (values.careerFunctionId > 0 && !initialLoadRef.current.designations) {
      dispatch(
        fetchDesignations({ careerFunctionId: values.careerFunctionId }),
      );
      initialLoadRef.current.designations = true;
    }
    if (values.companyId > 0 && !initialLoadRef.current.offices) {
      dispatch(fetchOffices({ id: values.companyId }));
      initialLoadRef.current.offices = true;
    }
  }, [
    dispatch,
    values.businessUnitId,
    values.teamId,
    values.subTeamId,
    values.careerFunctionId,
    values.companyId,
  ]);

  useEffect(() => {
    const recordCount = continuousServiceRecord?.length ?? 0;

    if (recordCount === 0) {
      setSelectedRecordIndex(null);
    } else if (
      selectedRecordIndex === null ||
      selectedRecordIndex >= recordCount
    ) {
      setSelectedRecordIndex(0);
    }
  }, [continuousServiceRecord, selectedRecordIndex]);

  const selectedRecord = useMemo(() => {
    if (!continuousServiceRecord?.length) return null;
    const index = selectedRecordIndex ?? 0;
    return continuousServiceRecord[index] ?? null;
  }, [continuousServiceRecord, selectedRecordIndex]);

  const internshipTypeId = useMemo(() => {
    const t = employmentTypes.find((et) => /^internship$/i.test(et.name));
    return t?.id ?? null;
  }, [employmentTypes]);

  // Only active types are selectable for onboarding, but keep the currently
  // selected type (edit mode may load an employee on a now-inactive type).
  const selectableEmploymentTypes = useMemo(
    () =>
      employmentTypes.filter(
        (t) => t.isActive || t.id === values.employmentTypeId,
      ),
    [employmentTypes, values.employmentTypeId],
  );

  const [internshipDurationMonths, setInternshipDurationMonths] =
    useState<number>(0);

  const computeAgreementEndDate = useCallback(
    (startDate: string | null, months: number) => {
      if (!startDate || !months) return null;
      try {
        return dayjs(startDate).add(months, "month").format("YYYY-MM-DD");
      } catch {
        return null;
      }
    },
    [],
  );
  const isPermanent = useMemo(() => {
    const selectedType = employmentTypes.find(
      (et) => et.id === values.employmentTypeId,
    );
    return /^permanent$/i.test(selectedType?.name?.trim() ?? "");
  }, [employmentTypes, values.employmentTypeId]);

  const isInternship = useMemo(() => {
    return (
      internshipTypeId !== null && values.employmentTypeId === internshipTypeId
    );
  }, [internshipTypeId, values.employmentTypeId]);

  const isLeaverStatus =
    values.employeeStatus === EmployeeStatus.Left ||
    values.employeeStatus === EmployeeStatus.MarkedLeaver;

  const isFixedTerm = useMemo(() => {
    const selectedType = employmentTypes.find(
      (et) => et.id === values.employmentTypeId,
    );
    if (!selectedType) return false;
    return FIXED_TERM_EMPLOYMENT_TYPE.test(selectedType.name.trim());
  }, [employmentTypes, values.employmentTypeId]);

  const isProbationType = useMemo(() => {
    const selectedType = employmentTypes.find(
      (et) => et.id === values.employmentTypeId,
    );
    if (!selectedType) return false;
    return PROBATION_EMPLOYMENT_TYPE.test(selectedType.name.trim());
  }, [employmentTypes, values.employmentTypeId]);

  const showAgreementEndDate = useMemo(() => {
    const normalized = employmentTypes
      .find((e) => e.id === values.employmentTypeId)
      ?.name?.trim()
      .toLowerCase();
    if (!normalized) return false;
    return /\b(internship|consult(ancy|ant)?|fixed\s+term)\b/.test(normalized);
  }, [employmentTypes, values.employmentTypeId]);

  const computedAgreementDate = useMemo(() => {
    if (!isInternship || !internshipDurationMonths) return null;
    return computeAgreementEndDate(
      values.startDate ?? null,
      internshipDurationMonths,
    );
  }, [
    isInternship,
    values.startDate,
    internshipDurationMonths,
    computeAgreementEndDate,
  ]);

  const [addProbationEndDate, setAddProbationEndDate] = useState(false);

  useEffect(() => {
    if (values.probationEndDate) setAddProbationEndDate(true);
  }, [values.probationEndDate]);

  const matchedProbationLocation = useMemo(() => {
    if (!values.companyId || !values.workLocation || !companies.length)
      return null;

    const company = companies.find((c) => c.id === values.companyId);
    return (
      company?.allowedLocations?.find(
        (item) =>
          item.location.trim().toUpperCase() ===
          values.workLocation.trim().toUpperCase(),
      ) ?? null
    );
  }, [values.companyId, values.workLocation, companies]);

  const probationHelperText = (() => {
    if (touched.probationEndDate && errors.probationEndDate) {
      return errors.probationEndDate;
    }
    if (!matchedProbationLocation) return undefined;

    const probationMonths = matchedProbationLocation.probationPeriod ?? null;
    return probationMonths === null
      ? "N/A — No probation for this location"
      : `Auto-calculated: ${probationMonths} months from start date`;
  })();

  useEffect(() => {
    // Wait for employment types to load — isPermanent/isProbationType both read
    // false on an empty list, which would otherwise clear an edit-mode value
    // (loaded from the employee record) before the preservation guard below runs.
    if (employmentTypes.length === 0) return;

    // Permanent and Probation both derive their probation end date from the
    // work location's configured probation period; other types do so once added.
    if (!isPermanent && !isProbationType && !addProbationEndDate) return;

    if (isEditMode && values.probationEndDate) return;

    if (!values.startDate || !matchedProbationLocation) {
      setFieldValue("probationEndDate", null);
      return;
    }

    const probationMonths = matchedProbationLocation.probationPeriod ?? null;

    if (probationMonths === null) {
      setFieldValue("probationEndDate", null);
      return;
    }

    const startDate = dayjs(values.startDate);
    if (!startDate.isValid()) {
      setFieldValue("probationEndDate", null);
      return;
    }
    const computed = startDate
      .add(probationMonths, "month")
      .format("YYYY-MM-DD");
    setFieldValue("probationEndDate", computed);
    // values.probationEndDate is read above (edit-mode guard) but deliberately
    // excluded here — including it re-fires this effect on every manual edit
    // (including from the picker below) and immediately overwrites it.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    employmentTypes.length,
    isPermanent,
    isProbationType,
    addProbationEndDate,
    isEditMode,
    values.startDate,
    matchedProbationLocation,
    setFieldValue,
  ]);

  const handleEmploymentTypeChange = useCallback(
    (newEmploymentTypeId: number) => {
      setFieldValue("employmentTypeId", newEmploymentTypeId);

      const selectedType = employmentTypes.find(
        (e) => e.id === newEmploymentTypeId,
      );
      const typeName = selectedType?.name?.trim() ?? "";
      const isNewInternship = /^internship$/i.test(typeName);
      const isNewPermanent = /^permanent$/i.test(typeName);
      const isNewFixedTerm = FIXED_TERM_EMPLOYMENT_TYPE.test(typeName);
      const isNewConsultancy = /consultancy/i.test(typeName);
      const isAutoIdType = AUTO_ID_EMPLOYMENT_TYPES.test(typeName);

      const isNewProbation = PROBATION_EMPLOYMENT_TYPE.test(typeName);

      if (
        (!isNewPermanent && !isNewProbation) ||
        (!isPermanent && !isProbationType)
      ) {
        setFieldValue("probationEndDate", null);
        setAddProbationEndDate(false);
      }

      if (isNewInternship) {
        setInternshipDurationMonths(6);
        setFieldValue("employeeId", "");
        const computed = computeAgreementEndDate(values.startDate ?? null, 6);
        if (computed) setFieldValue("agreementEndDate", computed);
      } else {
        setInternshipDurationMonths(0);
        if (isNewPermanent) setFieldValue("agreementEndDate", null);
        if (isNewConsultancy || isNewFixedTerm)
          setFieldValue("agreementEndDate", null);
        if (isAutoIdType) setFieldValue("employeeId", "");
      }
    },
    [
      setFieldValue,
      employmentTypes,
      computeAgreementEndDate,
      values.startDate,
      isPermanent,
      isProbationType,
    ],
  );

  const handleInternshipDurationChange = useCallback(
    (months: number) => {
      setInternshipDurationMonths(months);
      const computed = computeAgreementEndDate(
        values.startDate ?? null,
        months,
      );
      if (computed) {
        setFieldValue("agreementEndDate", computed);
      }
    },
    [setFieldValue, values.startDate, computeAgreementEndDate],
  );

  const handleStartDateChange = useCallback(
    (val: any) => {
      const newStartDate = val ? val.format("YYYY-MM-DD") : "";
      setFieldValue("startDate", newStartDate);

      if (isInternship && internshipDurationMonths && newStartDate) {
        const computed = computeAgreementEndDate(
          newStartDate,
          internshipDurationMonths,
        );
        if (computed) {
          setFieldValue("agreementEndDate", computed);
        }
      }
    },
    [
      setFieldValue,
      isInternship,
      internshipDurationMonths,
      computeAgreementEndDate,
    ],
  );

  const handleCareerFunctionChange = useCallback(
    (newCareerFunctionId: number) => {
      setFieldValue("careerFunctionId", newCareerFunctionId);
      setFieldValue("designationId", 0);

      if (newCareerFunctionId > 0) {
        dispatch(fetchDesignations({ careerFunctionId: newCareerFunctionId }));
        initialLoadRef.current.designations = true;
      }
    },
    [dispatch, setFieldValue],
  );

  const handleCompanyChange = useCallback(
    (newCompanyId: number) => {
      const currentCompanyId = values.companyId;
      setFieldValue("companyId", newCompanyId);

      if (newCompanyId > 0) {
        dispatch(fetchOffices({ id: newCompanyId }));
        initialLoadRef.current.offices = true;

        if (!currentCompanyId || currentCompanyId !== newCompanyId) {
          setFieldValue("officeId", OFFICE_CLEAR_SENTINEL);
          setFieldValue("workLocation", "");
        }
      }
    },
    [dispatch, setFieldValue, values.companyId],
  );

  const handleBusinessUnitChange = useCallback(
    (newBusinessUnitId: number) => {
      const prevBusinessUnitId = values.businessUnitId;
      setFieldValue("businessUnitId", newBusinessUnitId);

      if (newBusinessUnitId > 0) {
        dispatch(fetchTeams({ id: newBusinessUnitId }));
        initialLoadRef.current.teams = true;

        if (prevBusinessUnitId !== newBusinessUnitId) {
          setFieldValue("teamId", 0);
          setFieldValue("subTeamId", 0);
          setFieldValue("unitId", UNIT_CLEAR_SENTINEL);
          initialLoadRef.current.subTeams = false;
          initialLoadRef.current.units = false;
        }
      } else {
        setFieldValue("teamId", 0);
        setFieldValue("subTeamId", 0);
        setFieldValue("unitId", UNIT_CLEAR_SENTINEL);
      }
    },
    [dispatch, setFieldValue, values.businessUnitId],
  );

  const handleTeamChange = useCallback(
    (newTeamId: number) => {
      const prevTeamId = values.teamId;
      setFieldValue("teamId", newTeamId);

      if (newTeamId > 0) {
        dispatch(fetchSubTeams({ id: newTeamId }));
        initialLoadRef.current.subTeams = true;

        if (prevTeamId !== newTeamId) {
          setFieldValue("subTeamId", 0);
          setFieldValue("unitId", UNIT_CLEAR_SENTINEL);
          initialLoadRef.current.units = false;
        }
      } else {
        setFieldValue("subTeamId", 0);
        setFieldValue("unitId", UNIT_CLEAR_SENTINEL);
      }
    },
    [dispatch, setFieldValue, values.teamId],
  );

  const handleSubTeamChange = useCallback(
    (newSubTeamId: number) => {
      const prevSubTeamId = values.subTeamId;
      setFieldValue("subTeamId", newSubTeamId);

      if (newSubTeamId > 0) {
        dispatch(fetchUnits({ id: newSubTeamId }));
        initialLoadRef.current.units = true;

        if (prevSubTeamId !== newSubTeamId) {
          setFieldValue("unitId", UNIT_CLEAR_SENTINEL);
        }
      } else {
        setFieldValue("unitId", UNIT_CLEAR_SENTINEL);
      }
    },
    [dispatch, setFieldValue, values.subTeamId],
  );

  const handleOfficeChange = useCallback(
    (newOfficeId: number) => {
      setFieldValue("officeId", newOfficeId);
    },
    [setFieldValue],
  );

  const handleRelocationChange = useCallback(
    (checked: boolean) => {
      setFieldValue("isRelocation", checked);

      if (!checked) {
        setFieldValue("continuousServiceRecord", null);
        return;
      }

      const record =
        selectedRecordIndex !== null
          ? continuousServiceRecord?.[selectedRecordIndex]
          : continuousServiceRecord?.[0];
      setFieldValue("continuousServiceRecord", record?.id ?? null);
    },
    [setFieldValue, selectedRecordIndex, continuousServiceRecord],
  );

  return (
    <Box sx={{ width: "100%", px: 0 }}>
      <Box>
        <SectionHeader
          icon={SECTION_ICONS.badge}
          title="Identity"
          headerBoxSx={SECTION_HEADER_BOX_SX}
          iconBoxSx={iconBoxSx}
        />
        {identityNotice && (
          <Alert severity={identityNotice.severity} sx={{ mb: 3 }}>
            {identityNotice.message}
          </Alert>
        )}
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={4}>
            <TextField
              fullWidth
              required={isEditMode}
              name="workEmail"
              label="Work Email"
              value={values.workEmail ?? ""}
              onChange={handleChange}
              onBlur={(e: { target: { value: string } }) => {
                handleBlur(e);
                // Normalise on blur rather than per keystroke, so the field does not
                // fight someone typing a capital letter mid-address.
                const email = normalizeEmail(e.target.value ?? "");
                if (email !== (values.workEmail ?? "")) {
                  setFieldValue("workEmail", email);
                }
                if (email && Yup.string().email().isValidSync(email)) {
                  dispatch(fetchContinuousServiceRecord(email));
                } else {
                  dispatch(resetContinuousService());
                  setSelectedRecordIndex(null);
                }
              }}
              error={Boolean(touched.workEmail && errors.workEmail)}
              helperText={
                (touched.workEmail && errors.workEmail) ||
                (isEditMode
                  ? undefined
                  : "Leave empty if the account isn't created yet")
              }
              sx={textFieldSx}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <Box>
              {continuousServiceRecord?.length === 1 ? (
                <TextField
                  fullWidth
                  label="Employee ID (Previous)"
                  value={continuousServiceRecord[0]?.employeeId || ""}
                  disabled
                  sx={{
                    ...textFieldSx,
                    ...disabledSx,
                  }}
                  InputProps={{
                    endAdornment:
                      selectedRecord && !errorMessage ? (
                        <InfoPopoverAdornment record={selectedRecord} />
                      ) : undefined,
                  }}
                />
              ) : continuousServiceRecord?.length > 1 ? (
                <TextField
                  select
                  fullWidth
                  label="Employee ID (Previous)"
                  value={selectedRecordIndex ?? ""}
                  onChange={(e) => {
                    const index = Number(e.target.value);
                    setSelectedRecordIndex(index);
                    setFieldValue(
                      "continuousServiceRecord",
                      continuousServiceRecord[index].id,
                    );
                  }}
                  disabled={!!errorMessage}
                  sx={{ ...textFieldSx }}
                  helperText={
                    errorMessage ? "Failed to fetch record" : undefined
                  }
                  error={!!errorMessage}
                  InputProps={{
                    endAdornment:
                      selectedRecord && !errorMessage ? (
                        <InfoPopoverAdornment record={selectedRecord} />
                      ) : undefined,
                  }}
                >
                  {continuousServiceRecord.map((rec, idx) => (
                    <MenuItem key={idx} value={idx}>
                      {rec.employeeId} -{" "}
                      {`${rec.firstName || ""} ${rec.lastName || ""}`.trim() ||
                        "N/A"}
                    </MenuItem>
                  ))}
                </TextField>
              ) : (
                <TextField
                  fullWidth
                  label="Employee ID (Previous)"
                  value={errorMessage ? "Error" : "No Record"}
                  disabled
                  error={!!errorMessage}
                  helperText={errorMessage || ""}
                  sx={{
                    ...textFieldSx,
                    ...disabledSx,
                  }}
                />
              )}
              {!errorMessage && !!continuousServiceRecord?.length && (
                <Box sx={{ mt: 1 }}>
                  <FormControlLabel
                    control={
                      <Checkbox
                        checked={!!values.isRelocation}
                        onChange={(e) =>
                          handleRelocationChange(e.target.checked)
                        }
                      />
                    }
                    label="Relocation"
                  />
                </Box>
              )}
            </Box>
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <TextField
              fullWidth
              label="EPF"
              name="epf"
              value={values.epf ?? ""}
              onChange={handleChange}
              onBlur={async (e: { target: { value: string } }) => {
                handleBlur(e);
                const epf = e.target.value?.trim();
                latestEpfRef.current = epf;
                if (!epf) {
                  setFieldError("epf", undefined);
                  return;
                }

                try {
                  const exists = await dispatch(validateEpf(epf)).unwrap();
                  if (latestEpfRef.current !== epf) return;
                  if (exists) {
                    setFieldError("epf", "EPF already exists");
                  } else {
                    setFieldError("epf", undefined);
                  }
                } catch (err) {
                  if (latestEpfRef.current !== epf) return;
                  setFieldError("epf", "Failed to validate EPF");
                }
              }}
              error={Boolean(touched.epf && errors.epf)}
              helperText={touched.epf && errors.epf}
              sx={textFieldSx}
            />
          </Grid>
        </Grid>
      </Box>
      <Box>
        <SectionHeader
          icon={SECTION_ICONS.work}
          title="Job & Team"
          headerBoxSx={SECTION_HEADER_BOX_SX}
          iconBoxSx={iconBoxSx}
        />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              select
              fullWidth
              required
              label="Business Unit"
              name="businessUnitId"
              value={values.businessUnitId || ""}
              onChange={(e) => handleBusinessUnitChange(Number(e.target.value))}
              onBlur={handleBlur}
              error={Boolean(touched.businessUnitId && errors.businessUnitId)}
              helperText={touched.businessUnitId && errors.businessUnitId}
              sx={textFieldSx}
            >
              {businessUnits.length ? (
                sortAndFormatOptions(businessUnits, (b) => b.name).map((b) => (
                  <MenuItem key={b.id} value={b.id}>
                    {b.name}
                  </MenuItem>
                ))
              ) : (
                <MenuItem disabled>
                  {organizationState === "loading"
                    ? "Loading business units..."
                    : "No business units found"}
                </MenuItem>
              )}
            </TextField>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              select
              fullWidth
              required
              label="Team"
              name="teamId"
              value={values.teamId || ""}
              onChange={(e) => handleTeamChange(Number(e.target.value))}
              onBlur={handleBlur}
              error={Boolean(touched.teamId && errors.teamId)}
              helperText={touched.teamId && errors.teamId}
              disabled={!values.businessUnitId || values.businessUnitId === 0}
              sx={{
                ...textFieldSx,
                ...disabledSx,
              }}
            >
              {teams.length ? (
                sortAndFormatOptions(teams, (t) => t.name).map((t) => (
                  <MenuItem key={t.id} value={t.id}>
                    {t.name}
                  </MenuItem>
                ))
              ) : (
                <MenuItem disabled>
                  {!values.businessUnitId || values.businessUnitId === 0
                    ? "Select business unit first"
                    : "No teams found"}
                </MenuItem>
              )}
            </TextField>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              select
              fullWidth
              label="Sub Team"
              name="subTeamId"
              value={values.subTeamId || ""}
              onChange={(e) => handleSubTeamChange(Number(e.target.value))}
              onBlur={handleBlur}
              error={Boolean(touched.subTeamId && errors.subTeamId)}
              helperText={touched.subTeamId && errors.subTeamId}
              disabled={!values.teamId || values.teamId === 0}
              sx={{
                ...textFieldSx,
                ...disabledSx,
              }}
            >
              <MenuItem value={0}>
                <em>None</em>
              </MenuItem>
              {subTeams.length ? (
                sortAndFormatOptions(subTeams, (st) => st.name).map((st) => (
                  <MenuItem key={st.id} value={st.id}>
                    {st.name}
                  </MenuItem>
                ))
              ) : (
                <MenuItem disabled>
                  {!values.teamId || values.teamId === 0
                    ? "Select team first"
                    : "No sub teams found"}
                </MenuItem>
              )}
            </TextField>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              select
              fullWidth
              label="Unit"
              name="unitId"
              value={values.unitId || ""}
              onChange={(e) => setFieldValue("unitId", Number(e.target.value))}
              onBlur={handleBlur}
              error={Boolean(touched.unitId && errors.unitId)}
              helperText={touched.unitId && errors.unitId}
              disabled={!values.subTeamId || values.subTeamId === 0}
              sx={{
                ...textFieldSx,
                ...disabledSx,
              }}
            >
              <MenuItem value={UNIT_CLEAR_SENTINEL}>
                <em>None</em>
              </MenuItem>
              {units.length ? (
                sortAndFormatOptions(units, (u) => u.name).map((u) => (
                  <MenuItem key={u.id} value={u.id}>
                    {u.name}
                  </MenuItem>
                ))
              ) : (
                <MenuItem disabled>
                  {!values.subTeamId || values.subTeamId === 0
                    ? "Select sub team first"
                    : "No units found"}
                </MenuItem>
              )}
            </TextField>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              select
              fullWidth
              required
              label="Career Function"
              name="careerFunctionId"
              value={values.careerFunctionId || ""}
              onChange={(e) =>
                handleCareerFunctionChange(Number(e.target.value))
              }
              onBlur={handleBlur}
              error={Boolean(
                touched.careerFunctionId && errors.careerFunctionId,
              )}
              helperText={touched.careerFunctionId && errors.careerFunctionId}
              sx={textFieldSx}
            >
              {careerFunctions.length ? (
                sortAndFormatOptions(careerFunctions, (cf) => cf.careerFunction).map((cf) => (
                  <MenuItem key={cf.id} value={cf.id}>
                    {cf.careerFunction}
                  </MenuItem>
                ))
              ) : (
                <MenuItem disabled>
                  {organizationState === "loading"
                    ? "Loading career functions..."
                    : "No career functions found"}
                </MenuItem>
              )}
            </TextField>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              select
              fullWidth
              required
              label="Designation"
              name="designationId"
              value={values.designationId || ""}
              onChange={(e) =>
                setFieldValue("designationId", Number(e.target.value))
              }
              onBlur={handleBlur}
              error={Boolean(touched.designationId && errors.designationId)}
              helperText={touched.designationId && errors.designationId}
              disabled={
                !values.careerFunctionId || values.careerFunctionId === 0
              }
              sx={{
                ...textFieldSx,
                ...disabledSx,
              }}
            >
              {designations.length ? (
                [...designations]
                  .sort((a, b) => {
                    if (a.jobBand == null && b.jobBand == null) return 0;
                    if (a.jobBand == null) return 1;
                    if (b.jobBand == null) return -1;
                    return a.jobBand - b.jobBand;
                  })
                  .map((d) => (
                    <MenuItem key={d.id} value={d.id}>
                      {d.designation}
                      {d.jobBand != null ? ` (JB ${d.jobBand})` : ""}
                    </MenuItem>
                  ))
              ) : (
                <MenuItem disabled>
                  {!values.careerFunctionId || values.careerFunctionId === 0
                    ? "Select career function first"
                    : organizationState === "loading"
                      ? "Loading designations..."
                      : "No designations found"}
                </MenuItem>
              )}
            </TextField>
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              fullWidth
              label="Job Role"
              name="jobRole"
              value={values.jobRole ?? ""}
              onChange={handleChange}
              onBlur={handleBlur}
              error={Boolean(touched.jobRole && errors.jobRole)}
              helperText={touched.jobRole && errors.jobRole}
              sx={textFieldSx}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              fullWidth
              label="Secondary Job Title"
              name="secondaryJobTitle"
              value={values.secondaryJobTitle ?? ""}
              onChange={handleChange}
              onBlur={handleBlur}
              error={Boolean(
                touched.secondaryJobTitle && errors.secondaryJobTitle,
              )}
              helperText={touched.secondaryJobTitle && errors.secondaryJobTitle}
              sx={textFieldSx}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              fullWidth
              label="External Designation"
              name="externalDesignation"
              value={values.externalDesignation ?? ""}
              onChange={handleChange}
              onBlur={handleBlur}
              error={Boolean(
                touched.externalDesignation && errors.externalDesignation,
              )}
              helperText={
                touched.externalDesignation && errors.externalDesignation
              }
              inputProps={{ maxLength: 100 }}
              sx={textFieldSx}
            />
          </Grid>
        </Grid>
      </Box>

      <Box>
        <SectionHeader
          icon={SECTION_ICONS.location}
          title="Location & Office"
          headerBoxSx={SECTION_HEADER_BOX_SX}
          iconBoxSx={iconBoxSx}
        />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={4}>
            <TextField
              select
              fullWidth
              required
              label="Company"
              name="companyId"
              value={values.companyId || ""}
              onChange={(e) => handleCompanyChange(Number(e.target.value))}
              onBlur={handleBlur}
              error={Boolean(touched.companyId && errors.companyId)}
              helperText={touched.companyId && errors.companyId}
              sx={textFieldSx}
            >
              {companies.length ? (
                sortAndFormatOptions(companies, (company) => company.name).map((company) => (
                  <MenuItem key={company.id} value={company.id}>
                    {company.name}
                  </MenuItem>
                ))
              ) : (
                <MenuItem disabled>
                  {organizationState === "loading"
                    ? "Loading companies..."
                    : "No companies found"}
                </MenuItem>
              )}
            </TextField>
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <TextField
              select
              fullWidth
              label="Office"
              name="officeId"
              value={values.officeId || ""}
              onChange={(e) => handleOfficeChange(Number(e.target.value))}
              onBlur={handleBlur}
              error={Boolean(touched.officeId && errors.officeId)}
              helperText={touched.officeId && errors.officeId}
              sx={textFieldSx}
            >
              <MenuItem value={OFFICE_CLEAR_SENTINEL}>
                <em>None</em>
              </MenuItem>
              {offices.length ? (
                sortAndFormatOptions(offices, (office) => office.name).map((office) => (
                  <MenuItem key={office.id} value={office.id}>
                    {office.name}
                  </MenuItem>
                ))
              ) : (
                <MenuItem disabled>
                  {organizationState === "loading"
                    ? "Loading offices..."
                    : "No offices found"}
                </MenuItem>
              )}
            </TextField>
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <TextField
              select
              fullWidth
              required
              label="Work Location"
              name="workLocation"
              value={values.workLocation || ""}
              onChange={(e) => setFieldValue("workLocation", e.target.value)}
              onBlur={handleBlur}
              error={Boolean(touched.workLocation && errors.workLocation)}
              helperText={touched.workLocation && errors.workLocation}
              sx={textFieldSx}
            >
              {values.companyId && companies.length ? (
                (() => {
                  const allowedLocations =
                    companies.find((company) => company.id === values.companyId)
                      ?.allowedLocations ?? [];

                  return allowedLocations.length ? (
                    sortAndFormatOptions(
                      allowedLocations,
                      (locationItem) => locationItem.location,
                    ).map((locationItem) => (
                      <MenuItem
                        key={locationItem.location}
                        value={locationItem.location}
                      >
                        {locationItem.location}
                      </MenuItem>
                    ))
                  ) : (
                    <MenuItem disabled>No locations available</MenuItem>
                  );
                })()
              ) : (
                <MenuItem disabled>
                  {!values.companyId || values.companyId === 0
                    ? "Select company first"
                    : organizationState === "loading"
                      ? "Loading companies..."
                      : "No locations found"}
                </MenuItem>
              )}
            </TextField>
          </Grid>
        </Grid>
      </Box>

      <Box>
        <SectionHeader
          icon={SECTION_ICONS.event}
          title="Dates & Status"
          headerBoxSx={SECTION_HEADER_BOX_SX}
          iconBoxSx={iconBoxSx}
        />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={3}>
            <TextField
              select
              fullWidth
              required
              label="Employment Type"
              name="employmentTypeId"
              value={values.employmentTypeId || ""}
              onChange={(e) =>
                handleEmploymentTypeChange(Number(e.target.value))
              }
              onBlur={handleBlur}
              error={Boolean(
                touched.employmentTypeId && errors.employmentTypeId,
              )}
              helperText={touched.employmentTypeId && errors.employmentTypeId}
              disabled={organizationState === "loading"}
              sx={textFieldSx}
            >
              {selectableEmploymentTypes.length > 0 ? (
                sortAndFormatOptions(selectableEmploymentTypes, (type) => type.name).map((type) => (
                  <MenuItem key={type.id} value={type.id}>
                    {type.name}
                  </MenuItem>
                ))
              ) : (
                <MenuItem disabled>
                  {organizationState === "loading"
                    ? "Loading employment types..."
                    : "No active employment types available"}
                </MenuItem>
              )}
            </TextField>
          </Grid>
          {isEditMode ? (
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                select
                fullWidth
                label="Employee Status"
                name="employeeStatus"
                value={values.employeeStatus ?? ""}
                onChange={(e) => {
                  const newStatus = e.target.value;
                  setFieldValue("employeeStatus", newStatus);
                  // Clear resignation details whenever the status isn't Left, and also when
                  // entering Marked leaver — even switching directly from Left starts a fresh
                  // leave event, so a prior event's details should never carry over.
                  if (newStatus !== EmployeeStatus.Left) {
                    setFieldValue("finalDayInOffice", null);
                    setFieldValue("finalDayOfEmployment", null);
                    setFieldValue("resignationReason", null);
                  }
                }}
                onBlur={handleBlur}
                sx={textFieldSx}
              >
                {Object.values(EmployeeStatus).map((s) => (
                  <MenuItem key={s} value={s}>
                    {s}
                  </MenuItem>
                ))}
              </TextField>
            </Grid>
          ) : null}
          {isInternship ? (
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                select
                fullWidth
                label="Internship Duration"
                value={internshipDurationMonths || ""}
                onChange={(e) =>
                  handleInternshipDurationChange(Number(e.target.value))
                }
                sx={textFieldSx}
                helperText={
                  isInternship && internshipDurationMonths
                    ? "Agreement end date will be calculated from start date"
                    : ""
                }
              >
                {Array.from({ length: 10 }, (_, i) => i + 3).map((m) => (
                  <MenuItem key={m} value={m}>
                    {m} months
                  </MenuItem>
                ))}
              </TextField>
            </Grid>
          ) : null}
          {isFixedTerm ? (
            <Grid item xs={12} sm={6} md={3}>
              <TextField
                fullWidth
                required
                label="Employee ID"
                name="employeeId"
                value={values.employeeId ?? ""}
                onChange={(e) => setFieldValue("employeeId", e.target.value)}
                onBlur={handleBlur}
                error={Boolean(touched.employeeId && errors.employeeId)}
                helperText={touched.employeeId && (errors.employeeId as string)}
                sx={textFieldSx}
                InputProps={{ readOnly: Boolean(isEditMode) }}
              />
            </Grid>
          ) : null}
          <Grid item xs={12} sm={6} md={3}>
            <DatePicker
              label="Start Date"
              value={values.startDate ? dayjs(values.startDate) : null}
              onChange={handleStartDateChange}
              slotProps={{
                textField: {
                  fullWidth: true,
                  required: true,
                  error: Boolean(touched.startDate && errors.startDate),
                  helperText: touched.startDate && errors.startDate,
                  sx: textFieldSx,
                },
              }}
            />
          </Grid>
          {isPermanent || isProbationType ? (
            <Grid item xs={12} sm={6} md={3}>
              <DatePicker
                label="Probation End Date"
                value={
                  values.probationEndDate
                    ? dayjs(values.probationEndDate)
                    : null
                }
                onChange={(val) =>
                  setFieldValue(
                    "probationEndDate",
                    val ? val.format("YYYY-MM-DD") : null,
                  )
                }
                slotProps={{
                  field: { clearable: true },
                  textField: {
                    fullWidth: true,
                    error: Boolean(
                      touched.probationEndDate && errors.probationEndDate,
                    ),
                    helperText: probationHelperText,
                    sx: textFieldSx,
                  },
                }}
              />
            </Grid>
          ) : null}
          {showAgreementEndDate ? (
            <Grid item xs={12} sm={6} md={3}>
              <DatePicker
                label="Agreement End Date"
                value={
                  values.agreementEndDate
                    ? dayjs(values.agreementEndDate)
                    : null
                }
                onChange={(val) => {
                  if (isInternship && internshipDurationMonths) return;
                  setFieldValue(
                    "agreementEndDate",
                    val ? val.format("YYYY-MM-DD") : null,
                  );
                }}
                disabled={isInternship && !!internshipDurationMonths}
                slotProps={{
                  field: { clearable: true },
                  textField: {
                    fullWidth: true,
                    error: Boolean(
                      touched.agreementEndDate && errors.agreementEndDate,
                    ),
                    helperText:
                      isInternship && internshipDurationMonths
                        ? computedAgreementDate
                          ? `Auto: ${computedAgreementDate}`
                          : "Select start date to compute agreement end date"
                        : touched.agreementEndDate && errors.agreementEndDate,
                    sx: textFieldSx,
                  },
                }}
              />
            </Grid>
          ) : null}
          {!isPermanent && !isProbationType && values.employmentTypeId > 0 ? (
            <Grid
              item
              xs={12}
              sm={6}
              md={3}
              sx={{ display: "flex", alignItems: "center" }}
            >
              {addProbationEndDate ? (
                <DatePicker
                  label="Probation End Date"
                  value={
                    values.probationEndDate
                      ? dayjs(values.probationEndDate)
                      : null
                  }
                  onChange={(val) => {
                    setFieldValue(
                      "probationEndDate",
                      val ? val.format("YYYY-MM-DD") : null,
                    );
                    if (!val) setAddProbationEndDate(false);
                  }}
                  slotProps={{
                    field: { clearable: true },
                    textField: {
                      fullWidth: true,
                      error: Boolean(
                        touched.probationEndDate && errors.probationEndDate,
                      ),
                      helperText: probationHelperText,
                      sx: textFieldSx,
                    },
                  }}
                />
              ) : (
                <FormControlLabel
                  control={
                    <Checkbox
                      checked={false}
                      onChange={() => setAddProbationEndDate(true)}
                    />
                  }
                  label="Probation"
                />
              )}
            </Grid>
          ) : null}
        </Grid>
      </Box>

      <Box>
        <SectionHeader
          icon={SECTION_ICONS.supervisor}
          title="Lead & Reports"
          headerBoxSx={SECTION_HEADER_BOX_SX}
          iconBoxSx={iconBoxSx}
        />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={4}>
            <TextField
              select
              fullWidth
              required
              label="Lead Email"
              name="leadEmail"
              value={values.managerEmail || ""}
              onChange={(e) => setFieldValue("managerEmail", e.target.value)}
              onBlur={handleBlur}
              error={Boolean(touched.managerEmail && errors.managerEmail)}
              helperText={
                touched.managerEmail ? (errors.managerEmail ?? "") : ""
              }
              sx={textFieldSx}
            >
              {managerEmailOptions.length ? (
                managerEmailOptions.map((email) => (
                  <MenuItem key={email} value={email}>
                    {email}
                  </MenuItem>
                ))
              ) : (
                <MenuItem disabled>
                  {employeeBasicInfoState === "loading"
                    ? "Loading employees..."
                    : "No employees found"}
                </MenuItem>
              )}
            </TextField>
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <TextField
              select
              fullWidth
              label="Additional Lead Emails"
              name="additionalLeadEmail"
              value={values.additionalManagerEmail || []}
              onChange={(e) => {
                const value = e.target.value;
                setFieldValue(
                  "additionalManagerEmail",
                  typeof value === "string" ? value.split(",") : value,
                );
              }}
              onBlur={handleBlur}
              error={Boolean(
                touched.additionalManagerEmail && errors.additionalManagerEmail,
              )}
              helperText={
                touched.additionalManagerEmail && errors.additionalManagerEmail
              }
              SelectProps={{
                multiple: true,
                renderValue: (selected) => (
                  <Stack
                    direction="row"
                    spacing={0.5}
                    sx={{ flexWrap: "wrap", gap: 0.5 }}
                  >
                    {(selected as string[]).map((email) => (
                      <Chip
                        key={email}
                        label={email}
                        size="small"
                        onMouseDown={(e) => e.stopPropagation()}
                        onDelete={(e) => {
                          e.stopPropagation();
                          const updated = (
                            values.additionalManagerEmail || []
                          ).filter((em) => em !== email);
                          setFieldValue("additionalManagerEmail", updated);
                        }}
                        deleteIcon={
                          <Close
                            fontSize="small"
                            sx={{ color: "error.main" }}
                            aria-label={`Remove ${email}`}
                          />
                        }
                        sx={{
                          maxWidth: 200,
                          "& .MuiChip-label": {
                            overflow: "hidden",
                            textOverflow: "ellipsis",
                          },
                        }}
                      />
                    ))}
                  </Stack>
                ),
              }}
              sx={textFieldSx}
            >
              {additionalManagerOptions.length ? (
                additionalManagerOptions
                  .filter((email) => email !== values.managerEmail)
                  .map((email) => (
                    <MenuItem key={email} value={email}>
                      {email}
                    </MenuItem>
                  ))
              ) : (
                <MenuItem disabled>
                  {employeeBasicInfoState === "loading"
                    ? "Loading employees..."
                    : values.managerEmail
                      ? "No other leads available"
                      : "Select primary lead first"}
                </MenuItem>
              )}
            </TextField>
          </Grid>
        </Grid>
      </Box>

      {isEditMode ? (
        <Box>
          <SectionHeader
            icon={SECTION_ICONS.other}
            title="Other"
            headerBoxSx={SECTION_HEADER_BOX_SX}
            iconBoxSx={iconBoxSx}
          />
          <Grid container spacing={3}>
            <Grid item xs={12} sm={6} md={4}>
              <TextField
                select
                fullWidth
                label="House"
                name="houseId"
                value={values.houseId || 0}
                onChange={(e) => setFieldValue("houseId", Number(e.target.value))}
                onBlur={handleBlur}
                helperText="Assign the house for this employee"
                sx={textFieldSx}
              >
                {houses.length ? (
                  sortAndFormatOptions(houses, (h) => h.name).map((h) => (
                    <MenuItem key={h.id} value={h.id}>
                      {h.name}
                    </MenuItem>
                  ))
                ) : (
                  <MenuItem disabled>
                    {organizationState === "loading"
                      ? "Loading houses..."
                      : "No houses found"}
                  </MenuItem>
                )}
              </TextField>
            </Grid>
          </Grid>
        </Box>
      ) : null}

      {isEditMode ? (
        <Box>
          <SectionHeader
            icon={SECTION_ICONS.leaver}
            title="Resignation Details"
            headerBoxSx={SECTION_HEADER_BOX_SX}
            iconBoxSx={iconBoxSx}
          />
          <Grid container spacing={3}>
            <Grid item xs={12} sm={6} md={4}>
              <DatePicker
                label="Final Day in Office"
                disabled={!isLeaverStatus}
                value={
                  values.finalDayInOffice
                    ? dayjs(values.finalDayInOffice)
                    : null
                }
                onChange={(val) => {
                  setFieldTouched("finalDayInOffice", true);
                  setFieldValue(
                    "finalDayInOffice",
                    val ? val.format("YYYY-MM-DD") : null,
                  );
                }}
                slotProps={{
                  field: { clearable: true },
                  textField: {
                    fullWidth: true,
                    error: Boolean(touched.finalDayInOffice && errors.finalDayInOffice),
                    helperText:
                      touched.finalDayInOffice && errors.finalDayInOffice
                        ? errors.finalDayInOffice
                        : "Last day the employee was in office",
                    sx: textFieldSx,
                  },
                }}
              />
            </Grid>
            <Grid item xs={12} sm={6} md={4}>
              <DatePicker
                label="Final Day of Employment"
                disabled={!isLeaverStatus}
                value={
                  values.finalDayOfEmployment
                    ? dayjs(values.finalDayOfEmployment)
                    : null
                }
                onChange={(val) => {
                  setFieldTouched("finalDayOfEmployment", true);
                  setFieldValue(
                    "finalDayOfEmployment",
                    val ? val.format("YYYY-MM-DD") : null,
                  );
                }}
                slotProps={{
                  field: { clearable: true },
                  textField: {
                    fullWidth: true,
                    error: Boolean(touched.finalDayOfEmployment && errors.finalDayOfEmployment),
                    helperText:
                      touched.finalDayOfEmployment && errors.finalDayOfEmployment
                        ? errors.finalDayOfEmployment
                        : "Official last day of employment",
                    sx: textFieldSx,
                  },
                }}
              />
            </Grid>
            <Grid item xs={12} sm={6} md={4}>
              <Autocomplete<string | AddCustomReasonOption, false, false, true>
                freeSolo
                disabled={!isLeaverStatus}
                options={ResignationReasons}
                value={values.resignationReason ?? ""}
                // A stored reason that predates this list stays editable as typed
                // text; admins are not forced to re-pick one from the list.
                onChange={(_event, newValue) => {
                  // newValue is a plain string for a predefined pick or a
                  // freeSolo Enter-key commit, or the Add-row sentinel object
                  // when that synthetic row is clicked. The sentinel itself
                  // must never reach Formik — only its clean `value` may.
                  const raw =
                    typeof newValue === "string"
                      ? newValue
                      : newValue
                        ? newValue.value
                        : null;
                  setFieldValue("resignationReason", canonicalizeReason(raw), true);
                }}
                onInputChange={(_event, newInputValue, changeReason) => {
                  // Ignore the reset MUI fires while committing a selection; onChange
                  // already stored the canonical value for that path.
                  if (changeReason === "reset") return;
                  setFieldValue("resignationReason", newInputValue || null, true);
                }}
                onBlur={(event) => {
                  setFieldValue(
                    "resignationReason",
                    canonicalizeReason(values.resignationReason ?? null),
                    true,
                  );
                  handleBlur(event);
                }}
                filterOptions={(_options, state) => {
                  const input = state.inputValue;
                  // Filter against the predefined list directly (not the generic
                  // `_options` param) since the Autocomplete's Value type now also
                  // covers the non-string Add-row sentinel, which has no `.toLowerCase`.
                  const filtered: (string | AddCustomReasonOption)[] = ResignationReasons.filter(
                    (option) => option.toLowerCase().includes(input.trim().toLowerCase()),
                  );
                  // Make off-list entry deliberate: a half-typed option like "Retire"
                  // gets an explicit Add row rather than being silently saved. The
                  // Add row is a sentinel OBJECT, not a string, so it can never be
                  // confused with real user text (unlike a string-based marker,
                  // which would collide with user text containing the same syntax).
                  if (shouldOfferCustomReason(input)) {
                    filtered.push({ addCustom: true, value: input.trim() });
                  }
                  return filtered;
                }}
                // For a real option, show it as-is. For the Add-row sentinel,
                // show the bare custom text (not the "Add ..." wrapper) so the
                // displayed text always matches what will be stored.
                getOptionLabel={(option) =>
                  typeof option === "string" ? option : option.value
                }
                // The visible ROW label may still read `Add "..."`; only the
                // stored VALUE (handled in onChange/getOptionLabel) must be clean.
                renderOption={(props, option) => {
                  const { key, ...optionProps } = props;
                  return (
                    <li key={key} {...optionProps}>
                      {typeof option === "string" ? option : `Add "${option.value}"`}
                    </li>
                  );
                }}
                renderInput={(params) => (
                  <TextField
                    {...params}
                    fullWidth
                    label="Reason for Leaving"
                    name="resignationReason"
                    error={Boolean(touched.resignationReason && errors.resignationReason)}
                    helperText={
                      touched.resignationReason && errors.resignationReason
                        ? errors.resignationReason
                        : "Select a reason or type a custom one"
                    }
                    inputProps={{ ...params.inputProps, maxLength: 300 }}
                    sx={textFieldSx}
                  />
                )}
              />
            </Grid>
          </Grid>
        </Box>
      ) : null}
    </Box>
  );
}
