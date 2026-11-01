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

import { Button, Typography } from "@mui/material";
import { ArrowLeft } from "lucide-react";
import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import {
  type ApplicationFeedback,
  type ApplicationInterview,
  type DocumentsStatus,
  type OfferAnswer,
  type OfferLetter,
  State,
} from "@/types/types";
import CenteredSpinner from "@component/common/CenteredSpinner";
import PageContainer from "@component/common/PageContainer";
import { ApplicationStatus, OFFER_CONFLICT_ERROR, OFFER_EXPIRED_ERROR, SnackMessage } from "@config/constant";
import { useAppAuthContext } from "@context/AuthContext";
import {
  type ApplicationExtras,
  type LoadedMark,
  extrasVersionOf,
  isExtrasFresh,
  dismissFeedback,
  refreshApplications,
  respondToOffer,
  retryApplications,
  sendFeedback,
  setApplicationExtras,
} from "@slices/careersSlice/careers";
import { enqueueSnackbarMessage } from "@slices/commonSlice/common";
import { RootState, useAppDispatch, useAppSelector } from "@slices/store";
import { jobPath } from "@utils/jobFilterUtils";
import { fetchDocumentsStatus, fetchInterviews, fetchOfferLetter } from "@utils/profileService";
import AcceptOfferDialog from "@view/applications/components/AcceptOfferDialog";
import ApplicationDetails from "@view/applications/components/ApplicationDetails";
import ApplicationList from "@view/applications/components/ApplicationList";
import DeclineOfferDialog from "@view/applications/components/DeclineOfferDialog";
import RejectionFeedbackDialog from "@view/applications/components/RejectionFeedbackDialog";
import WelcomeDialog from "@view/applications/components/WelcomeDialog";

const NO_INTERVIEWS: ApplicationInterview[] = [];

const Applications = () => {
  const navigate = useNavigate();
  const dispatch = useAppDispatch();
  const { getToken } = useAppAuthContext();
  const applications = useAppSelector((state: RootState) => state.careers.applications);
  const applicationsState = useAppSelector((state: RootState) => state.careers.applicationsState);
  const jobs = useAppSelector((state: RootState) => state.careers.jobs);
  const jobsState = useAppSelector((state: RootState) => state.careers.jobsState);

  // The list, or one application's details when the URL has an id.
  const { id: applicationId } = useParams<{ id: string }>();

  const selectedApplication = applicationId ? applications.find((a) => a.id === applicationId) : undefined;
  const stillLoading = applicationsState === State.idle || applicationsState === State.loading;

  const dismissedFeedbackIds = useAppSelector((state: RootState) => state.careers.dismissedFeedbackIds);
  const [sendingFeedback, setSendingFeedback] = useState(false);
  const feedbackDue =
    selectedApplication?.status === ApplicationStatus.Rejected &&
    !selectedApplication.feedbackSubmitted &&
    !dismissedFeedbackIds.includes(selectedApplication.id);

  const handleSendFeedback = async (feedback: ApplicationFeedback) => {
    if (!selectedApplication) return;
    setSendingFeedback(true);
    try {
      const token = await getToken();
      await dispatch(sendFeedback({ accessToken: token, applicationId: selectedApplication.id, feedback })).unwrap();
      dispatch(enqueueSnackbarMessage({ message: SnackMessage.success.feedbackSent, type: "success" }));
    } catch {
      dispatch(enqueueSnackbarMessage({ message: SnackMessage.error.sendFeedback, type: "error" }));
    } finally {
      setSendingFeedback(false);
    }
  };

  // What was loaded for the opened application, kept in the store so the page shows it at once when opened again.
  const selectedId = selectedApplication?.id;
  const extras = useAppSelector((state: RootState) => (selectedId ? state.careers.applicationExtras[selectedId] : undefined));
  const generation = useAppSelector((state: RootState) => state.careers.sessionGeneration);
  const interviews = extras?.interviews ?? NO_INTERVIEWS;
  // Undefined while the check is loading, null when it failed.
  const documentsStatus: DocumentsStatus | null | undefined = extras?.documentsStatus;
  const keep = (id: string, loaded: ApplicationExtras) =>
    dispatch(setApplicationExtras({ id, generation, extras: loaded }));

  // What was loaded is used as it is until the application moves on or the time limit passes; any other visit only
  // shows it, and the page asks the backend again when it is missing, failed or out of date.
  const version = selectedApplication ? extrasVersionOf(selectedApplication) : "";
  const markLoaded = (): LoadedMark => ({ at: Date.now(), version });

  const hasOffer =
    selectedApplication?.status === ApplicationStatus.Offer ||
    selectedApplication?.status === ApplicationStatus.OfferAccepted;
  // The stored letter is hidden once the offer is declined or the application moves on, since it stays in the store.
  const offerLetter: OfferLetter | null = hasOffer ? (extras?.offerLetter ?? null) : null;

  // The offer letter, shown once the candidate has an offer or has accepted one; a failed load shows nothing.
  useEffect(() => {
    if (!selectedId || !hasOffer || isExtrasFresh(extras, "offerLetter", version)) return;
    let cancelled = false;
    getToken()
      .then((token) => fetchOfferLetter(token, selectedId))
      .then((letter) => {
        if (!cancelled) keep(selectedId, { offerLetter: letter, loaded: { offerLetter: markLoaded() } });
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedId, hasOffer, getToken, generation, version]);

  // The interviews of the opened application, past and upcoming; none when they cannot be loaded.
  useEffect(() => {
    if (!selectedId || isExtrasFresh(extras, "interviews", version)) return;
    let cancelled = false;
    getToken()
      .then((token) => fetchInterviews(token, selectedId))
      .then((loaded) => {
        if (!cancelled) keep(selectedId, { interviews: loaded, loaded: { interviews: markLoaded() } });
      })
      .catch(() => undefined);
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedId, getToken, generation, version]);

  // Raised to ask for the documents check again after it failed.
  const [documentsStatusAttempt, setDocumentsStatusAttempt] = useState(0);
  const hasAcceptedOffer = selectedApplication?.status === ApplicationStatus.OfferAccepted;

  // A retry shows the loading state again, for the opened application only.
  const retryDocumentsStatus = () => {
    if (selectedId) keep(selectedId, { documentsStatus: undefined });
    setDocumentsStatusAttempt((current) => current + 1);
  };

  // Whether the documents were already submitted. A status already known stays on screen while it is checked again.
  useEffect(() => {
    if (!selectedId || !hasAcceptedOffer || isExtrasFresh(extras, "documentsStatus", version)) return;
    let cancelled = false;
    getToken()
      .then((token) => fetchDocumentsStatus(token, selectedId))
      .then((loaded) => {
        if (!cancelled) keep(selectedId, { documentsStatus: loaded, loaded: { documentsStatus: markLoaded() } });
      })
      // A failed check is kept apart from "not submitted", and can be tried again.
      .catch(() => {
        if (!cancelled) keep(selectedId, { documentsStatus: null });
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedId, hasAcceptedOffer, getToken, generation, documentsStatusAttempt, version]);

  const [offerDialog, setOfferDialog] = useState<"accept" | "decline" | "welcome" | null>(null);
  const [respondingToOffer, setRespondingToOffer] = useState(false);

  const handleOfferAnswer = async (answer: OfferAnswer) => {
    if (!selectedApplication) return;
    setRespondingToOffer(true);
    try {
      const token = await getToken();
      await dispatch(respondToOffer({ accessToken: token, applicationId: selectedApplication.id, answer })).unwrap();
      if (answer.response === "accepted") {
        setOfferDialog("welcome");
      } else {
        setOfferDialog(null);
        dispatch(enqueueSnackbarMessage({ message: SnackMessage.success.offerDeclined, type: "success" }));
      }
    } catch (error) {
      const name = (error as { name?: string }).name;
      if (name === OFFER_CONFLICT_ERROR || name === OFFER_EXPIRED_ERROR) {
        // Closes the dialog and loads the real state.
        setOfferDialog(null);
        dispatch(refreshApplications());
        const message = name === OFFER_EXPIRED_ERROR ? SnackMessage.error.offerExpired : SnackMessage.error.offerConflict;
        dispatch(enqueueSnackbarMessage({ message, type: "error" }));
      } else {
        dispatch(enqueueSnackbarMessage({ message: SnackMessage.error.respondToOffer, type: "error" }));
      }
    } finally {
      setRespondingToOffer(false);
    }
  };

  return (
    <PageContainer>
      {selectedApplication && offerDialog === "accept" && (
        <AcceptOfferDialog
          jobTitle={selectedApplication.jobTitle}
          sending={respondingToOffer}
          onConfirm={() => handleOfferAnswer({ response: "accepted" })}
          onClose={() => setOfferDialog(null)}
        />
      )}
      {selectedApplication && offerDialog === "decline" && (
        <DeclineOfferDialog
          jobTitle={selectedApplication.jobTitle}
          sending={respondingToOffer}
          onDecline={handleOfferAnswer}
          onClose={() => setOfferDialog(null)}
        />
      )}
      {selectedApplication && offerDialog === "welcome" && (
        <WelcomeDialog
          jobTitle={selectedApplication.jobTitle}
          onSubmitDocuments={() => navigate(`/applications/${selectedApplication.id}/documents`)}
          onClose={() => setOfferDialog(null)}
        />
      )}
      {selectedApplication && feedbackDue && (
        <RejectionFeedbackDialog
          jobTitle={selectedApplication.jobTitle}
          sending={sendingFeedback}
          onSend={handleSendFeedback}
          onClose={() => dispatch(dismissFeedback(selectedApplication.id))}
        />
      )}
      {applicationId ? (
        <>
          <Button
            startIcon={<ArrowLeft size={16} />}
            onClick={() => navigate("/applications")}
            sx={{ mb: 2, ml: -1, fontWeight: 600 }}
          >
            Applications
          </Button>

          {selectedApplication ? (
            <ApplicationDetails
              application={selectedApplication}
              jobOpen={jobsState !== State.success || jobs.some((job) => job.id === selectedApplication.jobId)}
              onOpenJob={(jobId) => {
                const job = jobs.find((j) => j.id === jobId);
                navigate(job ? jobPath(job) : `/jobs/${jobId}`);
              }}
              canAcceptOffer={!applications.some((a) => a.status === ApplicationStatus.OfferAccepted)}
              onAcceptOffer={() => setOfferDialog("accept")}
              onDeclineOffer={() => setOfferDialog("decline")}
              onSubmitDocuments={() => navigate(`/applications/${selectedApplication.id}/documents`)}
              offerLetter={offerLetter}
              interviews={interviews}
              documentsStatus={documentsStatus}
              onRetryDocumentsStatus={retryDocumentsStatus}
            />
          ) : stillLoading ? (
            <CenteredSpinner />
          ) : (
            <Typography color="text.secondary">We couldn&apos;t find this application.</Typography>
          )}
        </>
      ) : (
        <ApplicationList
          applications={applications}
          applicationsState={applicationsState}
          onView={(id) => navigate(`/applications/${id}`)}
          onBrowseJobs={() => navigate("/jobs")}
          onRetry={() => dispatch(retryApplications())}
        />
      )}
    </PageContainer>
  );
};

export default Applications;
