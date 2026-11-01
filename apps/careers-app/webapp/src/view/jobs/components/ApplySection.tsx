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

import { Box, Typography } from "@mui/material";

import { useEffect, useRef, useState } from "react";

import { State } from "@/types/types";
import { SnackMessage } from "@config/constant";
import { useAppAuthContext } from "@context/AuthContext";
import { refreshApplications } from "@slices/careersSlice/careers";
import { enqueueSnackbarMessage } from "@slices/commonSlice/common";
import { RootState, useAppDispatch, useAppSelector } from "@slices/store";
import { isApplyFormComplete } from "@utils/applyForm";
import { COUNTRY_OPTIONS, splitE164 } from "@utils/phone";
import { trackSubmittedApplication } from "@utils/profileService";
import { type VacancyDetail, submitApplicationForm } from "@utils/vacancyService";
import ApplicationSubmittedDialog from "@view/jobs/components/ApplicationSubmittedDialog";
import ApplyForm, { type ApplyFormValues } from "@view/jobs/components/ApplyForm";
import GuestSignInPrompt from "@view/jobs/components/GuestSignInPrompt";

interface ApplySectionProps {
  detail: VacancyDetail;
}

// The job type of an internship.
const INTERNSHIP = "Internship";

const EMPTY_FORM: ApplyFormValues = {
  firstName: "",
  lastName: "",
  email: "",
  countryIso: "",
  phone: "",
  address: "",
  university: "",
};

// The "Apply Now" card: the application form, its submit logic and the confirmation dialog.
const ApplySection = ({ detail }: ApplySectionProps) => {
  const dispatch = useAppDispatch();
  const { getToken: getAccessToken, isSignedIn, appSignIn } = useAppAuthContext();

  const isInternship = detail.jobType === INTERNSHIP;
  const [form, setForm] = useState<ApplyFormValues>(EMPTY_FORM);
  const profile = useAppSelector((state: RootState) => state.careers.profile);
  const profileState = useAppSelector((state: RootState) => state.careers.profileState);
  const sessionGeneration = useAppSelector((state: RootState) => state.careers.sessionGeneration);

  // Prefills the empty fields from the profile.
  const prefilled = useRef(false);
  useEffect(() => {
    if (!isSignedIn || profileState !== State.success || prefilled.current) return;
    prefilled.current = true;
    const phone = splitE164(profile.contactNo);
    setForm((current) => ({
      firstName: current.firstName || profile.firstName,
      lastName: current.lastName || profile.lastName,
      email: current.email || profile.personalEmail,
      countryIso: current.countryIso || phone?.countryIso || "",
      phone: current.phone || phone?.national || "",
      address: current.address || (profile.address ?? ""),
      university: current.university || (profile.university ?? ""),
    }));
  }, [isSignedIn, profileState, profile]);

  const [authorized, setAuthorized] = useState<"yes" | "no" | "">("");
  const [consentData, setConsentData] = useState(false);
  const [consentChecks, setConsentChecks] = useState(false);
  const [consentMarketing, setConsentMarketing] = useState(false);
  const [submitting, setSubmitting] = useState(false);
  const [submittedOpen, setSubmittedOpen] = useState(false);
  const [cvFile, setCvFile] = useState<File | null>(null);

  // Empties the form when the candidate's data is cleared.
  const seenGeneration = useRef(sessionGeneration);
  useEffect(() => {
    if (seenGeneration.current === sessionGeneration) return;
    seenGeneration.current = sessionGeneration;
    prefilled.current = false;
    setForm(EMPTY_FORM);
    setCvFile(null);
    setAuthorized("");
    setConsentData(false);
    setConsentChecks(false);
    setConsentMarketing(false);
  }, [sessionGeneration]);

  const applyFormValid = isApplyFormComplete({
    ...form,
    isInternship,
    hasCv: !!cvFile,
    authorized,
    consentData,
    consentChecks,
  });

  const handleSubmitApplication = async () => {
    if (!applyFormValid || !cvFile) return;
    setSubmitting(true);
    try {
      const dialCode = COUNTRY_OPTIONS.find((o) => o.iso === form.countryIso)?.dialCode ?? "";
      await submitApplicationForm(
        await getAccessToken(),
        detail.id,
        {
          firstName: form.firstName.trim(),
          lastName: form.lastName.trim(),
          email: form.email.trim(),
          // E.164 phone number; a leading 0 is dropped.
          phone: `${dialCode}${form.phone.replace(/\D/g, "").replace(/^0+/, "")}`,
          address: isInternship ? "N/A" : form.address.trim(),
          university: isInternship ? form.university.trim() : undefined,
          authorizedToWork: authorized === "yes",
          marketingEmails: consentMarketing,
        },
        cvFile,
      );
      setSubmittedOpen(true);
      if (isSignedIn) {
        trackSubmittedApplication(detail.id, detail.title, detail.team);
        dispatch(refreshApplications());
      } else {
        // A guest's details are cleared after sending.
        setForm(EMPTY_FORM);
      }
      setCvFile(null);
      setAuthorized("");
      setConsentData(false);
      setConsentChecks(false);
      setConsentMarketing(false);
    } catch (err) {
      // The reply's message explains a rejection.
      const data = (err as { response?: { data?: { detail?: string; message?: string } } })?.response?.data;
      const detailMessage = data?.detail ?? data?.message;
      dispatch(enqueueSnackbarMessage({ message: detailMessage ?? SnackMessage.error.submitApplication, type: "error" }));
    } finally {
      setSubmitting(false);
    }
  };

  return (
    <>
      <Box
        id="Apply-Now"
        sx={{
          mt: 6,
          scrollMarginTop: "24px",
          p: { xs: 2.5, md: 4 },
          border: "1px solid",
          // The shadow marks the card edge; dark mode keeps a line.
          borderColor: (theme) => (theme.palette.mode === "dark" ? theme.palette.divider : "transparent"),
          borderRadius: "16px",
          boxShadow: "0 4px 24px rgb(23 34 58 / 28%)",
          "& .MuiInputBase-root, & .MuiInputLabel-root": { fontSize: "1rem" },
          backgroundColor: "background.glass",
        }}
      >
        <Typography variant="h4" fontWeight={800} sx={{ color: "text.primary" }} mb={3}>
          Apply Now
        </Typography>
        {!isSignedIn && <GuestSignInPrompt onSignIn={appSignIn} />}

        <ApplyForm
          form={form}
          isInternship={isInternship}
          onFormChange={setForm}
          cvFile={cvFile}
          onCvChosen={setCvFile}
          authorized={authorized}
          onAuthorizedChange={setAuthorized}
          consentData={consentData}
          onConsentDataChange={setConsentData}
          consentChecks={consentChecks}
          onConsentChecksChange={setConsentChecks}
          consentMarketing={consentMarketing}
          onConsentMarketingChange={setConsentMarketing}
          canSubmit={applyFormValid}
          submitting={submitting}
          onSubmit={handleSubmitApplication}
        />
      </Box>

      <ApplicationSubmittedDialog
        open={submittedOpen}
        jobTitle={detail.title}
        isSignedIn={isSignedIn}
        onClose={() => setSubmittedOpen(false)}
        onSignIn={appSignIn}
      />
    </>
  );
};

export default ApplySection;
