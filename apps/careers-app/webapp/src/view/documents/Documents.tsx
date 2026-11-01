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

import { Box, Button, Card, CircularProgress, LinearProgress, Stack, Typography } from "@mui/material";
import { ArrowLeft, Check } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import { type DocumentRequirements, type DocumentsStatus, type PersonalDetails, State } from "@/types/types";
import Callout from "@component/common/Callout";
import PageContainer from "@component/common/PageContainer";
import { ApplicationStatus, SnackMessage } from "@config/constant";
import { useAppAuthContext } from "@context/AuthContext";
import { loadProfile, retryApplications, setApplicationExtras } from "@slices/careersSlice/careers";
import { enqueueSnackbarMessage } from "@slices/commonSlice/common";
import { RootState, useAppDispatch, useAppSelector } from "@slices/store";
import { fetchDocumentRequirements, fetchDocumentsStatus, submitDocuments } from "@utils/profileService";
import { cardSx, pillButtonSx } from "@utils/styles";
import {
  type DetailErrors,
  detailErrorsOf,
  detailsFromProfile,
  emptyDetails,
} from "@view/documents/detailValidation";
import DocumentFileRows from "@view/documents/DocumentFileRows";
import {
  DETAILS_STEP,
  DOCUMENTS_STEP,
  PHOTOS_STEP,
  REVIEW_STEP,
  STEPS,
  deadlineText,
  isSessionEnded,
  problemWith,
  squareProblem,
  submitFailureMessage,
  without,
} from "@view/documents/documentFiles";
import DocumentsSkeleton from "@view/documents/DocumentsSkeleton";
import PersonalDetailsForm from "@view/documents/PersonalDetailsForm";
import ReviewStep from "@view/documents/ReviewStep";

// The page where a candidate who accepted an offer sends their details and the documents needed for onboarding.
const Documents = () => {
  const navigate = useNavigate();
  const dispatch = useAppDispatch();
  const { getToken, renewToken } = useAppAuthContext();
  const { id: applicationId } = useParams<{ id: string }>();
  const applications = useAppSelector((state: RootState) => state.careers.applications);
  const generation = useAppSelector((state: RootState) => state.careers.sessionGeneration);
  const applicationsState = useAppSelector((state: RootState) => state.careers.applicationsState);
  const profile = useAppSelector((state: RootState) => state.careers.profile);
  const profileState = useAppSelector((state: RootState) => state.careers.profileState);

  // What the candidate types and chooses is kept in this page only, not in the app state.
  const [step, setStep] = useState(DETAILS_STEP);
  const [details, setDetails] = useState<PersonalDetails>(emptyDetails());
  // Raised when the details are replaced, so the form's inputs start again from them.
  const [detailsVersion, setDetailsVersion] = useState(0);
  const [showDetailErrors, setShowDetailErrors] = useState(false);
  const [prefilled, setPrefilled] = useState(false);
  const [files, setFiles] = useState<Record<string, File>>({});
  const [problems, setProblems] = useState<Record<string, string>>({});
  const [requirements, setRequirements] = useState<DocumentRequirements | null>(null);
  const [requirementsState, setRequirementsState] = useState<State>(State.idle);
  const [submitting, setSubmitting] = useState(false);
  const [submitted, setSubmitted] = useState(false);
  const [declared, setDeclared] = useState(false);
  // The earlier submission: undefined until the backend answers, null when it could not.
  const [status, setStatus] = useState<DocumentsStatus | null | undefined>(undefined);
  // Raised to ask for the earlier submission again after it failed to load.
  const [statusAttempt, setStatusAttempt] = useState(0);

  // Fills the form from the candidate's profile once it has loaded.
  useEffect(() => {
    if (prefilled || profileState !== State.success) return;
    setDetails((current) => detailsFromProfile(current, profile));
    setDetailsVersion((current) => current + 1);
    setPrefilled(true);
  }, [prefilled, profile, profileState]);

  const application = applications.find((a) => a.id === applicationId);
  const eligible = application?.status === ApplicationStatus.OfferAccepted;

  // Loads the list of documents, which is the same for everyone.
  useEffect(() => {
    if (requirementsState !== State.idle) return;
    setRequirementsState(State.loading);
    getToken()
      .then(fetchDocumentRequirements)
      .then((loaded) => {
        setRequirements(loaded);
        setRequirementsState(State.success);
      })
      .catch(() => {
        setRequirementsState(State.failed);
        dispatch(enqueueSnackbarMessage({ message: SnackMessage.error.fetchDocumentRequirements, type: "error" }));
      });
  }, [requirementsState, dispatch, getToken]);

  // Loads the earlier submission, which decides between a first submission, a change to it, or neither. Its saved
  // details replace what was filled in from the profile.
  // The application whose saved details were put in the form, so a later response never replaces what is being edited.
  const savedDetailsFor = useRef<string | null>(null);
  useEffect(() => {
    if (!applicationId) return;
    let cancelled = false;
    getToken()
      .then((token) => fetchDocumentsStatus(token, applicationId))
      .then((loaded) => {
        if (cancelled) return;
        setStatus(loaded);
        if (loaded.details && savedDetailsFor.current !== applicationId) {
          savedDetailsFor.current = applicationId;
          // Details an older submission lacks are filled in as empty.
          setDetails({ ...emptyDetails(), ...loaded.details });
          setDetailsVersion((current) => current + 1);
          setPrefilled(true);
        }
      })
      .catch(() => {
        if (!cancelled) setStatus(null);
      });
    return () => {
      cancelled = true;
    };
  }, [applicationId, getToken, statusAttempt]);

  const retryStatus = () => {
    setStatus(undefined);
    setStatusAttempt((current) => current + 1);
  };

  const sentKeys = status?.files ?? [];
  const editing = Boolean(status?.submitted && status.canEdit);
  const closed = Boolean(status?.submitted && !status.canEdit);

  // Whether the page is still waiting for the applications and, for an accepted offer, the profile, the document list
  // and the earlier submission.
  const stillLoading =
    applicationsState === State.idle ||
    applicationsState === State.loading ||
    (eligible &&
      (profileState === State.idle ||
        profileState === State.loading ||
        requirementsState === State.idle ||
        requirementsState === State.loading ||
        status === undefined));

  // The personal email comes only from the profile and cannot be changed here, so the form waits for the profile.
  const profileReady = profileState === State.success;

  const retryProfile = async () => {
    dispatch(loadProfile(await getToken()));
  };

  const chooseFile = async (key: string, file: File | undefined) => {
    if (!file || !requirements) return;
    const requested = requirements.documents.find((document) => document.key === key);
    if (!requested) return;
    let problem = problemWith(file, requirements, requested);
    if (!problem && requested.minSquareSide) problem = await squareProblem(file, requested.minSquareSide);
    setProblems((current) => ({ ...current, [key]: problem }));
    if (problem) return;
    setFiles((current) => ({ ...current, [key]: file }));
  };

  const removeFile = (key: string) => {
    setFiles((current) => without(current, key));
    setProblems((current) => without(current, key));
  };

  const totalBytes = Object.values(files).reduce((sum, file) => sum + file.size, 0);
  const tooLarge = requirements ? totalBytes > requirements.maxTotalBytes : false;
  const documentsIn = (group: string) => requirements?.documents.filter((document) => document.group === group) ?? [];
  // A document counts as sent when a file was chosen now or one was sent earlier.
  const isSent = (key: string) => Boolean(files[key]) || sentKeys.includes(key);
  const missingIn = (group: string) => documentsIn(group).filter((document) => document.required && !isSent(document.key));
  const allDocumentsReady = missingIn("documents").length === 0 && missingIn("photos").length === 0;

  // Opens a step; what is missing is shown on the last step.
  const goTo = (target: number) => {
    if (!submitting) setStep(target);
  };

  // The problems with the personal details, empty when they are all fine.
  const currentDetailErrors: DetailErrors = requirements ? detailErrorsOf(details, requirements) : {};
  const detailsReady = requirements !== null && Object.keys(currentDetailErrors).length === 0;

  // Opens the details step with its problems shown.
  const showDetailProblems = () => {
    setShowDetailErrors(true);
    setStep(DETAILS_STEP);
  };

  const handleSubmit = async () => {
    if (!application || !requirements || submitting) return;
    if (!detailsReady) {
      showDetailProblems();
      return;
    }
    if (!allDocumentsReady || tooLarge || !declared) return;
    setSubmitting(true);
    try {
      const token = await getToken();
      try {
        await submitDocuments(token, application.id, files, details, editing);
      } catch (error) {
        if (!isSessionEnded(error)) throw error;
        // The token expired while the candidate was filling in the form. A new one is got without leaving the page, so
        // what they entered is kept, and the submission is sent once more.
        let fresh: string;
        try {
          fresh = await renewToken();
        } catch {
          throw error;
        }
        await submitDocuments(fresh, application.id, files, details, editing);
      }
      setFiles({});
      setSubmitted(true);
      // The status the application page kept is out of date now, so it is dropped and the page checks again.
      dispatch(setApplicationExtras({ id: application.id, generation, extras: { documentsStatus: undefined } }));
      const message = editing ? SnackMessage.success.documentsUpdated : SnackMessage.success.documentsSent;
      dispatch(enqueueSnackbarMessage({ message, type: "success" }));
    } catch (error) {
      dispatch(enqueueSnackbarMessage({ message: submitFailureMessage(error), type: "error" }));
    } finally {
      setSubmitting(false);
    }
  };

  const backToApplication = () => navigate(applicationId ? `/applications/${applicationId}` : "/applications");

  const fileRows = (group: string) => (
    <DocumentFileRows
      documents={documentsIn(group)}
      files={files}
      sentKeys={sentKeys}
      problems={problems}
      submitting={submitting}
      onChoose={(key, file) => void chooseFile(key, file)}
      onRemove={removeFile}
    />
  );

  return (
    <PageContainer>
      <Button startIcon={<ArrowLeft size={16} />} onClick={backToApplication} sx={{ mb: 2, ml: -1, fontWeight: 600 }}>
        Application
      </Button>

      {stillLoading && <DocumentsSkeleton />}

      {!stillLoading && applicationsState === State.failed && (
        <Stack alignItems="flex-start" gap={1.5}>
          <Typography color="text.secondary">{SnackMessage.error.fetchApplications}</Typography>
          <Button variant="outlined" onClick={() => dispatch(retryApplications())} sx={pillButtonSx}>
            Try again
          </Button>
        </Stack>
      )}

      {!stillLoading && applicationsState !== State.failed && !eligible && (
        <Typography color="text.secondary">
          Documents can be submitted once you have accepted the offer for this application.
        </Typography>
      )}

      {!stillLoading && eligible && closed && !submitted && (
        <Callout tone="brand">
          <Typography fontWeight={700} fontSize="0.95rem" color="text.primary">
            Your documents were submitted.
          </Typography>
          <Typography fontSize="0.9rem" color="text.primary">
            {status?.editableUntil ? "The time to change them has ended. " : ""}Please contact the hiring team if
            something needs to change.
          </Typography>
        </Callout>
      )}

      {!stillLoading && eligible && !profileReady && (
        <Stack alignItems="flex-start" gap={1.5}>
          <Typography color="text.secondary">We couldn&apos;t load your profile, which has your email.</Typography>
          <Button variant="outlined" onClick={retryProfile} sx={pillButtonSx}>
            Try again
          </Button>
        </Stack>
      )}

      {!stillLoading && eligible && profileReady && status === null && (
        <Stack alignItems="flex-start" gap={1.5}>
          <Typography color="text.secondary">We couldn&apos;t check whether your documents were submitted.</Typography>
          <Button variant="outlined" onClick={retryStatus} sx={pillButtonSx}>
            Try again
          </Button>
        </Stack>
      )}

      {!stillLoading && eligible && profileReady && requirementsState === State.failed && (
        <Stack alignItems="flex-start" gap={1.5}>
          <Typography color="text.secondary">We couldn&apos;t load the list of documents.</Typography>
          <Button variant="outlined" onClick={() => setRequirementsState(State.idle)} sx={pillButtonSx}>
            Try again
          </Button>
        </Stack>
      )}

      {!stillLoading && eligible && profileReady && application && requirements && submitted && (
        <Callout tone="success" icon={<Check size={20} color="#059669" />}>
          <Typography fontWeight={700} fontSize="0.95rem" color="text.primary">
            {editing ? "Your changes were saved." : "We received your details and documents."}
          </Typography>
          <Typography fontSize="0.9rem" color="text.primary">
            The hiring team will contact you with the next steps.
          </Typography>
          <Button variant="contained" onClick={backToApplication} sx={{ ...pillButtonSx, px: 3, mt: 1.5 }}>
            Back to application
          </Button>
        </Callout>
      )}

      {!stillLoading &&
        eligible &&
        profileReady &&
        status !== null &&
        !closed &&
        application &&
        requirements &&
        !submitted && (
        <Card elevation={0} sx={cardSx}>
          <Box sx={{ p: 3, pb: 0 }}>
            <Typography
              component="h1"
              sx={{ fontSize: { xs: "1.5rem", md: "1.9rem" }, lineHeight: 1.3, fontWeight: 400, color: "text.primary" }}
            >
              {editing ? "Change your submission" : `Join ${application.jobTitle}`}
            </Typography>
            <Typography fontSize="0.9rem" color="text.secondary" mt={0.5} mb={2.5}>
              {editing
                ? status?.editableUntil
                  ? `You can change your details and replace files until ${deadlineText(status.editableUntil)}.`
                  : "You can change your details and replace files."
                : "Check everything on the last step before you submit."}
            </Typography>
            <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr 1fr", md: "repeat(4, 1fr)" }, gap: 1.5 }}>
              {STEPS.map((label, index) => (
                <Button
                  key={label}
                  onClick={() => goTo(index)}
                  disabled={submitting}
                  variant={index === step ? "contained" : "outlined"}
                  color="primary"
                  sx={{
                    ...pillButtonSx,
                    py: 1.25,
                    ...(index !== step && { color: "text.primary", borderColor: "primary.main" }),
                  }}
                >
                  {index + 1}. {label}
                </Button>
              ))}
            </Box>
          </Box>

          {step === DETAILS_STEP && (
            <PersonalDetailsForm
              key={detailsVersion}
              details={details}
              onChange={setDetails}
              errors={showDetailErrors ? currentDetailErrors : {}}
              options={requirements}
              disabled={submitting}
            />
          )}
          {step === DOCUMENTS_STEP && fileRows("documents")}
          {step === PHOTOS_STEP && fileRows("photos")}
          {step === REVIEW_STEP && (
            <ReviewStep
              requirements={requirements}
              details={details}
              files={files}
              sentKeys={sentKeys}
              detailsReady={detailsReady}
              totalBytes={totalBytes}
              tooLarge={tooLarge}
              declared={declared}
              submitting={submitting}
              onDeclaredChange={setDeclared}
              onShowDetailProblems={showDetailProblems}
              onGoTo={goTo}
            />
          )}

          <Stack
            direction="row"
            alignItems="center"
            justifyContent="space-between"
            gap={1.5}
            sx={{ p: 3, borderTop: "1px solid", borderColor: "divider" }}
          >
            <Button onClick={() => goTo(step - 1)} disabled={step === DETAILS_STEP || submitting} sx={{ fontWeight: 600 }}>
              Back
            </Button>
            {step < REVIEW_STEP ? (
              <Button variant="contained" onClick={() => goTo(step + 1)} sx={{ ...pillButtonSx, px: 3 }}>
                Next
              </Button>
            ) : (
              <Button
                variant="contained"
                onClick={handleSubmit}
                disabled={submitting || !detailsReady || !allDocumentsReady || tooLarge || !declared}
                startIcon={submitting ? <CircularProgress size={18} color="inherit" /> : undefined}
                sx={{ ...pillButtonSx, px: 3 }}
              >
                {submitting ? (editing ? "Saving..." : "Submitting...") : editing ? "Save changes" : "Submit"}
              </Button>
            )}
          </Stack>
          {submitting && (
            <Box role="status" aria-live="polite" sx={{ px: 3, pb: 3 }}>
              <LinearProgress sx={{ borderRadius: "999px", mb: 1 }} />
              <Typography fontSize="0.9rem" color="text.secondary">
                {editing ? "Saving your changes" : "Sending your details and files"}. This can take a few seconds, so
                please keep this page open.
              </Typography>
            </Box>
          )}
        </Card>
      )}
    </PageContainer>
  );
};

export default Documents;
