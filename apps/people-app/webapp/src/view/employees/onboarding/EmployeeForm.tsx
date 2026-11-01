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

import {
  useAppDispatch,
  useAppSelector,
  type AppDispatch,
} from "@slices/store";
import { useParams, useNavigate } from "react-router-dom";
import { useState, useEffect, useMemo } from "react";
import { useConfirmationModalContext } from "@context/DialogContext";
import { ConfirmationType, EmployeeStatus, State } from "@/types/types";
import {
  Box,
  Stepper,
  Step,
  StepLabel,
  Button,
  Typography,
  Paper,
  useTheme,
  StepConnector,
  stepConnectorClasses,
  StepIconProps,
  styled,
  alpha,
} from "@mui/material";
import { Formik, Form, useFormikContext } from "formik";
import PersonalInfoStep from "./singleOnboarding/steps/PersonalInfo";
import JobInfoStep from "./singleOnboarding/steps/JobInfo";
import ReviewStep from "./singleOnboarding/steps/Review";
import { Check, ArrowBack, ArrowForward } from "@mui/icons-material";
import { personalInfoValidationSchema } from "./singleOnboarding/steps/PersonalInfo";
import { createJobInfoValidationSchema } from "./singleOnboarding/steps/JobInfo";
import {
  CreateEmployeeFormValues,
  emptyCreateEmployeeValues,
} from "@root/src/types/types";
import { markAllFieldsTouched } from "@root/src/utils/utils";
import {
  createEmployee,
  CreateEmployeePayload,
  resetCreateEmployeeState,
  UpdateEmployeeJobInfoPayload,
  fetchEmployee,
  updateEmployeeJobInfo,
  resetUpdateEmployeeJobInfoState,
  type Employee,
  validateEpf,
  CONTINUOUS_SERVICE_RECORD_CLEAR_SENTINEL,
} from "@slices/employeeSlice/employee";
import { EmployeeFormSteps } from "@root/src/config/constant";
import {
  fetchEmployeePersonalInfo,
  updateEmployeePersonalInfo,
  type EmployeePersonalInfo,
  type EmployeePersonalInfoUpdate,
} from "@root/src/slices/employeeSlice/employeePersonalInfo";
import { resetEmployee } from "@slices/employeeSlice/employee";
import { resetPersonalInfo } from "@root/src/slices/employeeSlice/employeePersonalInfo";

import {
  OFFICE_CLEAR_SENTINEL,
  UNIT_CLEAR_SENTINEL,
} from "@slices/careerFunctionSlice/careerFunction";

const deriveFullName = (
  full: string | null | undefined,
  first?: string,
  last?: string,
): string => (full ?? `${first ?? ""} ${last ?? ""}`).trim();

export const toFormValues = (
  employee: Employee | null,
  personal: EmployeePersonalInfo | null,
): CreateEmployeeFormValues => {
  const base: CreateEmployeeFormValues = JSON.parse(
    JSON.stringify(emptyCreateEmployeeValues),
  );

  if (employee) {
    base.workEmail = employee.workEmail ?? "";
    // An existing link opens the relocation box ticked, so it can be seen and removed.
    base.isRelocation = employee.continuousServiceRecord != null;
    base.continuousServiceRecord = employee.continuousServiceRecord ?? null;
    base.epf = employee.epf ?? "";
    base.businessUnitId = employee.businessUnitId ?? 0;
    base.teamId = employee.teamId ?? 0;
    base.subTeamId = employee.subTeamId ?? 0;
    base.unitId = employee.unitId ?? UNIT_CLEAR_SENTINEL;
    base.companyId = employee.companyId ?? 0;
    base.officeId = employee.officeId ?? OFFICE_CLEAR_SENTINEL;
    base.workLocation = employee.workLocation ?? "";
    base.employmentTypeId = employee.employmentTypeId ?? 0;
    base.startDate = employee.startDate ?? "";
    base.probationEndDate = employee.probationEndDate ?? null;
    base.agreementEndDate = employee.agreementEndDate ?? null;
    base.managerEmail = employee.managerEmail ?? "";
    base.additionalManagerEmail = employee.additionalManagerEmails
      ? employee.additionalManagerEmails
        .split(",")
        .map((s) => s.trim())
        .filter(Boolean)
      : [];
    base.careerFunctionId = employee.careerFunctionId ?? 0;
    base.designationId = employee.designationId ?? 0;
    base.secondaryJobTitle = employee.secondaryJobTitle ?? "";
    base.jobRole = employee.jobRole ?? "";
    base.externalDesignation = employee.externalDesignation ?? "";
    base.houseId = employee.houseId ?? 0;
    base.leadershipGroupIds = employee.leadershipGroupIds ?? [];
    base.employeeId = employee.employeeId ?? "";
    base.employeeStatus = employee.employeeStatus ?? null;
    base.finalDayInOffice = employee.finalDayInOffice ?? null;
    base.finalDayOfEmployment = employee.finalDayOfEmployment ?? null;
    base.resignationReason = employee.resignationReason ?? null;
  }

  if (personal) {
    base.personalInfo = {
      nicOrPassport: personal.nicOrPassport ?? "",
      firstName: personal.firstName ?? "",
      fullName: deriveFullName(
        personal.fullName,
        employee?.firstName,
        employee?.lastName,
      ),
      lastName: personal.lastName ?? "",
      title: personal.title ?? "",
      dob: personal.dob ?? null,
      gender: personal.gender ?? "",
      personalEmail: personal.personalEmail ?? null,
      personalPhone: personal.personalPhone ?? null,
      residentNumber: personal.residentNumber ?? null,
      addressLine1: personal.addressLine1 ?? null,
      addressLine2: personal.addressLine2 ?? null,
      city: personal.city ?? null,
      stateOrProvince: personal.stateOrProvince ?? null,
      postalCode: personal.postalCode ?? null,
      country: personal.country ?? null,
      nationality: personal.nationality ?? "",
      emergencyContacts: personal.emergencyContacts ?? [],
    };
  } else if (employee) {
    base.personalInfo.firstName = employee.firstName ?? "";
    base.personalInfo.lastName = employee.lastName ?? "";
    base.personalInfo.fullName = deriveFullName(
      undefined,
      employee.firstName,
      employee.lastName,
    );
  }

  return base;
};

export const toJobUpdatePayload = (
  values: CreateEmployeeFormValues,
): UpdateEmployeeJobInfoPayload => ({
  epf: values.epf === "" ? null : values.epf,
  workLocation: values.workLocation,
  workEmail: values.workEmail,
  startDate: values.startDate,
  secondaryJobTitle: values.secondaryJobTitle,
  jobRole: values.jobRole,
  externalDesignation: values.externalDesignation,
  managerEmail: values.managerEmail,
  additionalManagerEmails: values.additionalManagerEmail ?? [],
  probationEndDate: values.probationEndDate ?? "",
  agreementEndDate: values.agreementEndDate ?? null,
  employmentTypeId:
    values.employmentTypeId > 0 ? values.employmentTypeId : null,
  designationId: values.designationId > 0 ? values.designationId : null,
  companyId: values.companyId > 0 ? values.companyId : null,
  // Belt-and-suspenders: by submit time officeId/unitId should never legitimately be a
  // non-positive value other than the sentinel (0 is blocked by Yup's notOneOf([0]) on
  // officeId, and cascade resets always write the sentinel directly for unitId — see
  // handleBusinessUnitChange/handleTeamChange/handleSubTeamChange). This guard just makes
  // sure nothing malformed reaches the wire regardless.
  officeId:
    values.officeId > 0
      ? values.officeId
      : values.officeId === OFFICE_CLEAR_SENTINEL
        ? OFFICE_CLEAR_SENTINEL
        : null,
  teamId: values.teamId > 0 ? values.teamId : null,
  subTeamId: values.subTeamId > 0 ? values.subTeamId : null,
  businessUnitId: values.businessUnitId > 0 ? values.businessUnitId : null,
  unitId:
    values.unitId > 0
      ? values.unitId
      : values.unitId === UNIT_CLEAR_SENTINEL
        ? UNIT_CLEAR_SENTINEL
        : null,
  houseId: values.houseId > 0 ? values.houseId : null,
  leadershipGroupIds: values.leadershipGroupIds ?? [],
  // Unticked sends the clear sentinel. It only reaches the request when the box was
  // ticked before (the diff drops it otherwise), which is exactly when a link is removed.
  continuousServiceRecord: values.isRelocation
    ? (values.continuousServiceRecord ?? null)
    : CONTINUOUS_SERVICE_RECORD_CLEAR_SENTINEL,
  employeeStatus: values.employeeStatus ?? null,
  finalDayInOffice: values.finalDayInOffice ?? null,
  finalDayOfEmployment: values.finalDayOfEmployment ?? null,
  resignationReason: values.resignationReason ?? null,
});

export const toPersonalUpdatePayload = (
  values: CreateEmployeeFormValues,
): EmployeePersonalInfoUpdate => ({
  nicOrPassport: values.personalInfo.nicOrPassport ?? null,
  firstName: values.personalInfo.firstName ?? null,
  lastName: values.personalInfo.lastName ?? null,
  fullName: deriveFullName(
    values.personalInfo.fullName,
    values.personalInfo.firstName,
    values.personalInfo.lastName,
  ) || null,
  title: values.personalInfo.title ?? null,
  dob: values.personalInfo.dob ?? null,
  gender: values.personalInfo.gender ?? null,
  personalEmail:
    values.personalInfo.personalEmail === ""
      ? null
      : values.personalInfo.personalEmail,
  personalPhone:
    values.personalInfo.personalPhone === ""
      ? null
      : values.personalInfo.personalPhone,
  residentNumber:
    values.personalInfo.residentNumber === ""
      ? null
      : values.personalInfo.residentNumber,
  addressLine1:
    values.personalInfo.addressLine1 === ""
      ? null
      : values.personalInfo.addressLine1,
  addressLine2:
    values.personalInfo.addressLine2 === ""
      ? null
      : values.personalInfo.addressLine2,
  city: values.personalInfo.city === "" ? null : values.personalInfo.city,
  stateOrProvince:
    values.personalInfo.stateOrProvince === ""
      ? null
      : values.personalInfo.stateOrProvince,
  postalCode:
    values.personalInfo.postalCode === ""
      ? null
      : values.personalInfo.postalCode,
  country:
    values.personalInfo.country === "" ? null : values.personalInfo.country,
  nationality: values.personalInfo.nationality ?? null,
  emergencyContacts:
    values.personalInfo.emergencyContacts &&
      values.personalInfo.emergencyContacts.length > 0
      ? values.personalInfo.emergencyContacts
      : null,
});

const OrangeConnector = styled(StepConnector)(({ theme }) => ({
  [`&.${stepConnectorClasses.alternativeLabel}`]: { top: 18 },
  [`&.${stepConnectorClasses.active}`]: {
    [`& .${stepConnectorClasses.line}`]: {
      backgroundImage: `linear-gradient(90deg, ${theme.palette.secondary.contrastText
        }, ${alpha(theme.palette.secondary.contrastText, 0.5)})`,
    },
  },
  [`&.${stepConnectorClasses.completed}`]: {
    [`& .${stepConnectorClasses.line}`]: {
      backgroundImage: `linear-gradient(90deg, ${theme.palette.secondary.contrastText}, ${theme.palette.secondary.contrastText
        })`,
    },
  },
  [`& .${stepConnectorClasses.line}`]: {
    height: 3,
    border: 0,
    backgroundColor:
      theme.palette.mode === "dark" ? theme.palette.grey[800] : "#eaeaf0",
    borderRadius: 1,
  },
}));

const StepIconRoot = styled("div")<{
  ownerState: { completed?: boolean; active?: boolean };
}>(({ theme, ownerState }) => ({
  backgroundColor:
    theme.palette.mode === "dark" ? theme.palette.grey[700] : "#ccc",
  zIndex: 1,
  color: "#fff",
  width: 32,
  height: 32,
  display: "flex",
  borderRadius: "50%",
  justifyContent: "center",
  alignItems: "center",
  fontSize: "0.75rem",
  fontWeight: 600,

  ...(ownerState.active && {
    backgroundImage: `linear-gradient(135deg, ${theme.palette.secondary.contrastText
      }, ${alpha(theme.palette.secondary.contrastText, 0.8)})`,
    boxShadow: `0 4px 10px 0 ${alpha(
      theme.palette.secondary.contrastText,
      0.3,
    )}`,
  }),

  ...(ownerState.completed && {
    backgroundImage: `linear-gradient(135deg, ${theme.palette.secondary.contrastText
      }, ${alpha(theme.palette.secondary.contrastText, 0.8)})`,
  }),
}));

function CustomStepIcon(props: StepIconProps) {
  const { active, completed, className, icon } = props;

  return (
    <StepIconRoot ownerState={{ completed, active }} className={className}>
      {completed ? <Check sx={{ fontSize: 20 }} /> : icon}
    </StepIconRoot>
  );
}

export const diffObject = <T extends Record<string, any>>(
  prev: T,
  next: T,
): Partial<T> => {
  const out: Partial<T> = {};

  (Object.keys(next) as (keyof T)[]).forEach((k) => {
    const a = prev[k];
    const b = next[k];
    if (Array.isArray(a) || Array.isArray(b)) {
      const aa = Array.isArray(a) ? a : [];
      const bb = Array.isArray(b) ? b : [];
      if (JSON.stringify(aa) !== JSON.stringify(bb)) out[k] = b;
      return;
    }

    if (a !== b && b !== undefined) out[k] = b;
  });

  return out;
};

export type Mode = "edit" | "create";

type FormActionsBarProps = {
  activeStep: number;
  isEditMode: boolean;
  initialEditValues: CreateEmployeeFormValues | null;
  employeeId: string | undefined;
  employeeSlice: { state: State; updateJobInfoState: State };
  onBack: () => void;
  onNext: () => void;
  dispatch: AppDispatch;
};

function FormActionsBar({
  activeStep,
  isEditMode,
  initialEditValues,
  employeeId,
  employeeSlice,
  onBack,
  onNext,
  dispatch,
}: FormActionsBarProps) {
  const {
    values,
    isSubmitting,
    validateForm,
    setTouched,
    submitForm,
    setFieldError,
    setFieldTouched,
  } = useFormikContext<CreateEmployeeFormValues>();

  const hasActualChanges = useMemo(() => {
    if (!isEditMode || !initialEditValues || !employeeId) return true;
    const jobPatch = diffObject(
      toJobUpdatePayload(initialEditValues),
      toJobUpdatePayload(values),
    );
    const personalPatch = diffObject(
      toPersonalUpdatePayload(initialEditValues),
      toPersonalUpdatePayload(values),
    );
    return (
      Object.keys(jobPatch).length > 0 || Object.keys(personalPatch).length > 0
    );
  }, [isEditMode, initialEditValues, employeeId, values]);

  return (
    <Box mt={3} width="100%" display="flex" justifyContent="flex-end" gap={2}>
      {activeStep > 0 && (
        <Button
          startIcon={<ArrowBack />}
          sx={{ textTransform: "none" }}
          variant="outlined"
          color="primary"
          onClick={onBack}
        >
          Back
        </Button>
      )}

      <Button
        endIcon={
          activeStep === EmployeeFormSteps.length - 1 ? null : <ArrowForward />
        }
        sx={{ textTransform: "none" }}
        variant="contained"
        color="secondary"
        type="button"
        disabled={
          isSubmitting ||
          employeeSlice.state === State.loading ||
          employeeSlice.updateJobInfoState === State.loading ||
          (isEditMode &&
            activeStep === EmployeeFormSteps.length - 1 &&
            !hasActualChanges)
        }
        onClick={async () => {
          if (activeStep === 1) {
            const epf = (values.epf ?? "").toString().trim();
            const initialEpf = (initialEditValues?.epf ?? "").toString().trim();
            if (epf && (!isEditMode || epf !== initialEpf)) {
              const fieldErrors = await validateForm();
              if (fieldErrors.epf) {
                setFieldTouched("epf", true, false);
                document
                  .querySelector<HTMLElement>('[name="epf"]')
                  ?.scrollIntoView({ behavior: "smooth", block: "center" });
                return;
              }

              try {
                const exists = await dispatch(validateEpf(epf)).unwrap();
                if (exists) {
                  setFieldError("epf", "EPF already exists");
                  setFieldTouched("epf", true, false);
                  document
                    .querySelector<HTMLElement>('[name="epf"]')
                    ?.scrollIntoView({ behavior: "smooth", block: "center" });
                  return;
                }
              } catch {
                setFieldError("epf", "Failed to validate EPF");
                setFieldTouched("epf", true, false);
                document
                  .querySelector<HTMLElement>('[name="epf"]')
                  ?.scrollIntoView({ behavior: "smooth", block: "center" });
                return;
              }
            }
          }

          const validationErrors = await validateForm();
          if (Object.keys(validationErrors).length === 0) {
            if (activeStep === EmployeeFormSteps.length - 1) {
              submitForm();
            } else {
              onNext();
            }
          } else {
            setTouched(markAllFieldsTouched(validationErrors));
          }
        }}
      >
        {employeeSlice.state === State.loading ||
          employeeSlice.updateJobInfoState === State.loading
          ? "Saving..."
          : activeStep === EmployeeFormSteps.length - 1
            ? isEditMode
              ? "Update"
              : "Submit"
            : "Next"}
      </Button>
    </Box>
  );
}

type EmployeeFormProps = {
  mode: Mode;
};

export default function EmployeeForm({ mode }: EmployeeFormProps) {
  const { employeeId } = useParams();
  const theme = useTheme();
  const navigate = useNavigate();
  const dispatch = useAppDispatch();
  const { showConfirmation } = useConfirmationModalContext();

  // Currently always false: employeeEdit.tsx was removed and employeeOnboarding.tsx's
  // mode="create" is the only call site left, so every isEditMode branch here and in
  // JobInfo/Review is unreachable. Editing an existing employee now happens in the
  // profile's inline section editors (view/me/sectionEdit).
  //
  // Left in place rather than deleted: the branches span three large files with no tests
  // over the wizard, and the create path shares that code, so removing them belongs in
  // its own change where breaking onboarding would be obvious. Treat what they contain as
  // stale, not as reference — the leaver-fields rule in the edit submit path below is the
  // pre-fix version of the one corrected in useSectionSave.
  const isEditMode = mode === "edit" && !!employeeId;

  const employeeSlice = useAppSelector((s) => s.employee);
  const employee = employeeSlice.employee;

  const personalSlice = useAppSelector((s) => s.employeePersonalInfo);
  const personalInfo = personalSlice.personalInfo;
  const employmentTypes = useAppSelector((s) => s.organization.employmentTypes);

  const [activeStep, setActiveStep] = useState(0);
  const [formKey, setFormKey] = useState(0);

  const handleNext = () => setActiveStep((prev) => prev + 1);
  const handleBack = () => setActiveStep((prev) => prev - 1);

  useEffect(() => {
    return () => {
      dispatch(resetEmployee());
      dispatch(resetPersonalInfo());
      if (isEditMode) {
        dispatch(resetUpdateEmployeeJobInfoState());
      }
    };
  }, [dispatch, isEditMode]);

  useEffect(() => {
    if (!isEditMode || !employeeId) return;

    dispatch(fetchEmployee(employeeId));
    dispatch(fetchEmployeePersonalInfo(employeeId));
  }, [dispatch, isEditMode, employeeId]);

  const initialEditValues = useMemo(() => {
    if (!isEditMode || !employee || !personalInfo) return null;
    return toFormValues(employee, personalInfo);
  }, [isEditMode, employee, personalInfo]);

  const initialValues = useMemo(() => {
    if (initialEditValues) return initialEditValues;
    return emptyCreateEmployeeValues;
  }, [initialEditValues]);

  const isFailedEditData =
    isEditMode &&
    (employeeSlice.state === State.failed ||
      personalSlice.state === State.failed);

  const isLoadingEditData =
    isEditMode &&
    !isFailedEditData &&
    (employeeSlice.state === State.loading ||
      personalSlice.state === State.loading ||
      !employee ||
      !personalInfo);

  const handleCreateEmployeeWithConfirm = async (
    payload: CreateEmployeePayload,
    actions: { resetForm: () => void; setSubmitting: (v: boolean) => void },
  ) => {
    showConfirmation(
      "Confirm Employee Creation",
      "Are you sure you want to create this employee?",
      ConfirmationType.accept,
      async () => {
        const resultAction = await dispatch(createEmployee(payload));

        if (createEmployee.fulfilled.match(resultAction)) {
          actions.resetForm();
          dispatch(resetCreateEmployeeState());
          setActiveStep(0);
          setFormKey((prev) => prev + 1);
        }

        actions.setSubmitting(false);
      },
      "Confirm",
      "Cancel",
    );
  };

  const renderStepContent = (step: number) => {
    switch (step) {
      case 0:
        return <PersonalInfoStep />;
      case 1:
        return <JobInfoStep isEditMode={isEditMode} />;
      case 2:
        return <ReviewStep isEditMode={isEditMode} />;
      default:
        return <Typography>Unknown step</Typography>;
    }
  };

  if (isEditMode && isFailedEditData) {
    return (
      <Box sx={{ p: 3 }}>
        <Typography color="error">
          Failed to load employee data. Please try again.
        </Typography>
      </Box>
    );
  }

  if (isEditMode && isLoadingEditData) {
    return (
      <Box sx={{ p: 3 }}>
        <Typography>Loading employee data...</Typography>
      </Box>
    );
  }

  return (
    <Box
      sx={{
        minHeight: "100vh",
        py: { xs: 1, sm: 1.5 },
        px: { xs: 1, sm: 1.5 },
        display: "flex",
        flexDirection: "column",
        alignItems: "center",
        backgroundColor: theme.palette.background.default,
      }}
    >
      <Paper
        sx={{
          p: { xs: 1.5, sm: 3, md: 4 },
          width: "100%",
          maxWidth: 1600,
          borderRadius: 3,
          boxShadow: 2,
          backgroundColor: theme.palette.background.paper,
        }}
      >
        <Box sx={{ mb: 1 }}>
          <Typography variant="h4" fontWeight={700} gutterBottom>
            {isEditMode ? "Edit Employee" : "Onboarding"}
          </Typography>
          <Typography
            variant="body1"
            sx={{ color: theme.palette.text.secondary }}
          >
            {isEditMode
              ? "Update the employee details using the steps below"
              : "Complete the steps below to add a new employee to the system"}
          </Typography>
        </Box>

        <Stepper
          activeStep={activeStep}
          alternativeLabel
          connector={<OrangeConnector />}
          sx={{ mb: 1, py: 0 }}
        >
          {EmployeeFormSteps.map((label) => (
            <Step key={label}>
              <StepLabel
                StepIconComponent={CustomStepIcon}
                sx={{
                  "& .MuiStepLabel-label": {
                    mt: 0.5,
                    fontSize: "0.85rem",
                    fontWeight: 400,
                  },
                  "& .MuiStepLabel-label.Mui-active": {
                    color: "secondary.contrastText",
                    fontWeight: 400,
                    fontSize: "0.85rem",
                  },
                  "& .MuiStepLabel-label.Mui-completed": { fontWeight: 600 },
                }}
              >
                {label}
              </StepLabel>
            </Step>
          ))}
        </Stepper>

        <Formik<CreateEmployeeFormValues>
          key={formKey}
          initialValues={initialValues}
          enableReinitialize
          validationSchema={
            activeStep === 0
              ? personalInfoValidationSchema
              : // requireHouse tracks isEditMode because the House field itself is only
                // rendered in edit mode; the server assigns the house when onboarding.
                createJobInfoValidationSchema(employmentTypes, {
                  requireHouse: isEditMode,
                  // Onboarding may leave it empty for a joiner whose account is not
                  // created yet; the backend stores a placeholder until it is.
                  requireWorkEmail: isEditMode,
                })
          }
          onSubmit={async (values, actions) => {
            if (activeStep !== EmployeeFormSteps.length - 1) {
              handleNext();
              actions.setSubmitting(false);
              return;
            }

            if (!isEditMode) {
              const payload: CreateEmployeePayload = {
                firstName: values.personalInfo.firstName || "",
                lastName: values.personalInfo.lastName || "",
                epf: values.epf || undefined,
                secondaryJobTitle: values.secondaryJobTitle || "",
                jobRole: values.jobRole || "",
                externalDesignation: values.externalDesignation || "",
                workLocation: values.workLocation,
                workEmail: values.workEmail?.trim() || undefined,
                startDate: values.startDate,
                managerEmail: values.managerEmail,
                additionalManagerEmails: values.additionalManagerEmail?.length
                  ? values.additionalManagerEmail
                  : [],
                probationEndDate: values.probationEndDate || undefined,
                agreementEndDate: values.agreementEndDate || undefined,
                employmentTypeId:
                  values.employmentTypeId > 0
                    ? values.employmentTypeId
                    : undefined,
                designationId: values.designationId,
                companyId: values.companyId,
                // Create is a single POST, not a PATCH diff — there's no "leave unchanged"
                // concept here, so no sentinel is needed; -1 (if it ever appeared) would
                // still correctly fall through to undefined via the >0 check.
                officeId:
                  values.officeId && values.officeId > 0
                    ? values.officeId
                    : undefined,
                teamId: values.teamId,
                subTeamId: values.subTeamId > 0 ? values.subTeamId : undefined,
                businessUnitId: values.businessUnitId,
                unitId: values.unitId > 0 ? values.unitId : undefined,
                employeeId: values.employeeId?.trim() || undefined,
                ...(values.isRelocation && values.continuousServiceRecord
                  ? { continuousServiceRecord: values.continuousServiceRecord }
                  : {}),
                personalInfo: {
                  nicOrPassport: values.personalInfo.nicOrPassport,
                  fullName:
                    deriveFullName(
                      values.personalInfo.fullName,
                      values.personalInfo.firstName,
                      values.personalInfo.lastName,
                    ) || undefined,
                  firstName: values.personalInfo.firstName || undefined,
                  lastName: values.personalInfo.lastName || undefined,
                  title: values.personalInfo.title || undefined,
                  dob: values.personalInfo.dob || undefined,
                  gender: values.personalInfo.gender || undefined,
                  personalEmail: values.personalInfo.personalEmail || undefined,
                  personalPhone: values.personalInfo.personalPhone || undefined,
                  residentNumber:
                    values.personalInfo.residentNumber || undefined,
                  addressLine1: values.personalInfo.addressLine1 || undefined,
                  addressLine2: values.personalInfo.addressLine2 || undefined,
                  city: values.personalInfo.city || undefined,
                  stateOrProvince:
                    values.personalInfo.stateOrProvince || undefined,
                  postalCode: values.personalInfo.postalCode || undefined,
                  country: values.personalInfo.country || undefined,
                  nationality: values.personalInfo.nationality || undefined,
                  emergencyContacts: values.personalInfo.emergencyContacts,
                },
              };
              handleCreateEmployeeWithConfirm(payload, {
                resetForm: () => actions.resetForm(),
                setSubmitting: (v) => actions.setSubmitting(v),
              });

              return;
            }
            if (isEditMode) {
              if (!employeeId || !initialEditValues) {
                actions.setSubmitting(false);
                return;
              }
              const initialJob = toJobUpdatePayload(initialEditValues);
              const currentJob = toJobUpdatePayload(values);

              const initialPersonal =
                toPersonalUpdatePayload(initialEditValues);
              const currentPersonal = toPersonalUpdatePayload(values);

              const jobPatch: Partial<UpdateEmployeeJobInfoPayload> =
                diffObject(initialJob, currentJob);

              // Always send resignation details when the resulting status is a leaver status,
              // regardless of whether they differ from the pre-edit values — the diff alone
              // isn't reliable here since these fields are reset to null on entering the status.
              if (
                currentJob.employeeStatus === EmployeeStatus.MarkedLeaver ||
                currentJob.employeeStatus === EmployeeStatus.Left
              ) {
                jobPatch.finalDayInOffice = currentJob.finalDayInOffice;
                jobPatch.finalDayOfEmployment = currentJob.finalDayOfEmployment;
                jobPatch.resignationReason = currentJob.resignationReason;
              }
              const personalPatch = diffObject(
                initialPersonal,
                currentPersonal,
              );

              const hasJobChanges = Object.keys(jobPatch).length > 0;
              const hasPersonalChanges = Object.keys(personalPatch).length > 0;

              if (!hasJobChanges && !hasPersonalChanges) {
                actions.setSubmitting(false);
                return;
              }

              showConfirmation(
                "Confirm Update",
                <Typography variant="body1">
                  Are you sure you want to update this employee?
                </Typography>,
                ConfirmationType.accept,
                async () => {
                  try {
                    let jobUpdateFailed = false;
                    let personalUpdateFailed = false;
                    const failedUpdates: string[] = [];

                    if (hasJobChanges) {
                      const jobResult = await dispatch(
                        updateEmployeeJobInfo({
                          employeeId,
                          payload: {
                            ...jobPatch,
                          } as UpdateEmployeeJobInfoPayload,
                        }),
                      );
                      if (updateEmployeeJobInfo.rejected.match(jobResult)) {
                        jobUpdateFailed = true;
                        failedUpdates.push("Job Information");
                      }
                    }

                    if (hasPersonalChanges) {
                      const personalResult = await dispatch(
                        updateEmployeePersonalInfo({
                          employeeId,
                          data: personalPatch as EmployeePersonalInfoUpdate,
                        }),
                      );
                      if (
                        updateEmployeePersonalInfo.rejected.match(
                          personalResult,
                        )
                      ) {
                        personalUpdateFailed = true;
                        failedUpdates.push("Personal Information");
                      }
                    }

                    if (jobUpdateFailed || personalUpdateFailed) {
                      const errorMessage =
                        failedUpdates.length === 1
                          ? `Failed to update ${failedUpdates[0]}.`
                          : `Failed to update ${failedUpdates.join(" and ")}.`;

                      showConfirmation(
                        "Update Failed",
                        <Typography variant="body1">{errorMessage}</Typography>,
                        ConfirmationType.accept,
                        () => { },
                        "OK",
                      );
                    } else {
                      navigate(`/employees/${employeeId}`, { replace: true });
                    }
                  } catch (error) {
                    console.error("Update failed:", error);
                    showConfirmation(
                      "Update Error",
                      <Typography variant="body1">
                        An unexpected error occurred during the update.
                      </Typography>,
                      ConfirmationType.accept,
                      () => { },
                      "OK",
                    );
                  } finally {
                    actions.setSubmitting(false);
                  }
                },
                "Yes",
                "No",
              );
              return;
            }
          }}
          validateOnChange={false}
          validateOnBlur={true}
        >
          {() => (
            <Form
              onKeyDown={(e) => {
                if (e.key === "Enter") e.preventDefault();
              }}
            >
              {renderStepContent(activeStep)}
              <FormActionsBar
                activeStep={activeStep}
                isEditMode={isEditMode}
                initialEditValues={initialEditValues}
                employeeId={employeeId}
                employeeSlice={employeeSlice}
                onBack={handleBack}
                onNext={handleNext}
                dispatch={dispatch}
              />
            </Form>
          )}
        </Formik>
      </Paper>
    </Box>
  );
}
