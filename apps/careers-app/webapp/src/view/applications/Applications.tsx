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

import { Button, Typography } from "@wso2/oxygen-ui";
import { ArrowLeft } from "@wso2/oxygen-ui-icons-react";
import { useEffect, useState } from "react";
import { useNavigate, useParams } from "react-router-dom";

import {
  type ApplicationInterview,
  type DocumentsStatus,
  type OfferAnswer,
  State,
} from "@/types/types";
import CenteredSpinner from "@component/common/CenteredSpinner";
import PageContainer from "@component/common/PageContainer";
import { CareersSiteUrl } from "@config/config";
import {
  ApplicationStatus,
  DOCUMENTS_SUBMISSION_ENABLED,
  OFFER_CONFLICT_ERROR,
  OFFER_EXPIRED_ERROR,
  OFFER_INVALID_ERROR,
  OFFER_NOT_FOUND_ERROR,
  SnackMessage,
} from "@config/constant";
import { useAppAuthContext } from "@context/AuthContext";
import {
  type ApplicationExtras,
  type LoadedMark,
  extrasVersionOf,
  isExtrasFresh,
  refreshApplications,
  respondToOffer,
  retryApplications,
  setApplicationExtras,
} from "@slices/careersSlice/careers";
import { enqueueSnackbarMessage } from "@slices/commonSlice/common";
import { RootState, useAppDispatch, useAppSelector } from "@slices/store";
import { fetchDocumentsStatus, fetchInterviews } from "@utils/profileService";
import { pillButtonSx } from "@utils/styles";
import AcceptOfferDialog from "@view/applications/components/AcceptOfferDialog";
import ApplicationDetails from "@view/applications/components/ApplicationDetails";
import ApplicationList from "@view/applications/components/ApplicationList";
import DeclineOfferDialog from "@view/applications/components/DeclineOfferDialog";
import WelcomeDialog from "@view/applications/components/WelcomeDialog";

const NO_INTERVIEWS: ApplicationInterview[] = [];

const Applications = () => {
  const navigate = useNavigate();
  const dispatch = useAppDispatch();
  const { getToken } = useAppAuthContext();
  const applications = useAppSelector((state: RootState) => state.careers.applications);
  const applicationsState = useAppSelector((state: RootState) => state.careers.applicationsState);
  // The email the candidate signed in with, which the applications are found by.
  const signedInEmail = useAppSelector((state: RootState) => state.auth.userInfo?.email ?? state.auth.userInfo?.username);

  // The list, or one application's details when the URL has an id.
  const { id: applicationId } = useParams<{ id: string }>();

  const selectedApplication = applicationId ? applications.find((a) => a.id === applicationId) : undefined;
  const stillLoading = applicationsState === State.idle || applicationsState === State.loading;

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
  // The documents status is only asked for while the documents step is open.
  const hasAcceptedOffer =
    DOCUMENTS_SUBMISSION_ENABLED && selectedApplication?.status === ApplicationStatus.OfferAccepted;

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

  // An offer can run out while the tab stays open, so the applications are loaded again when the candidate comes back to
  // the tab and an offer is still open.
  const hasOpenOffer = applications.some((a) => a.status === ApplicationStatus.Offer);
  useEffect(() => {
    if (!hasOpenOffer) return;
    const onVisible = () => {
      if (document.visibilityState === "visible") dispatch(refreshApplications());
    };
    document.addEventListener("visibilitychange", onVisible);
    return () => document.removeEventListener("visibilitychange", onVisible);
  }, [hasOpenOffer, dispatch]);

  // A dialog belongs to the application it was opened for, so it never follows the candidate to another one.
  const [offerDialog, setOfferDialog] = useState<{
    kind: "accept" | "decline" | "welcome";
    applicationId: string;
  } | null>(null);
  const dialogKind = offerDialog && offerDialog.applicationId === selectedApplication?.id ? offerDialog.kind : null;
  const [respondingToOffer, setRespondingToOffer] = useState(false);

  const handleOfferAnswer = async (answer: OfferAnswer) => {
    if (!selectedApplication) return;
    const answeredId = selectedApplication.id;
    setRespondingToOffer(true);
    try {
      const token = await getToken();
      await dispatch(respondToOffer({ accessToken: token, applicationId: answeredId, answer })).unwrap();
      // The status, the dates and the deadline come from the backend, so the applications are loaded again.
      dispatch(refreshApplications());
      if (answer.response === "accepted") {
        setOfferDialog({ kind: "welcome", applicationId: answeredId });
      } else {
        setOfferDialog(null);
        dispatch(enqueueSnackbarMessage({ message: SnackMessage.success.offerDeclined, type: "success" }));
      }
    } catch (error) {
      const name = (error as { name?: string }).name;
      if (name === OFFER_CONFLICT_ERROR || name === OFFER_EXPIRED_ERROR || name === OFFER_NOT_FOUND_ERROR) {
        // Closes the dialog and loads the real state.
        setOfferDialog(null);
        dispatch(refreshApplications());
        const message =
          name === OFFER_EXPIRED_ERROR
            ? SnackMessage.error.offerExpired
            : name === OFFER_NOT_FOUND_ERROR
              ? SnackMessage.error.offerNotFound
              : SnackMessage.error.offerConflict;
        dispatch(enqueueSnackbarMessage({ message, type: "error" }));
      } else if (name === OFFER_INVALID_ERROR) {
        // The dialog stays open, and the message says what to correct.
        dispatch(enqueueSnackbarMessage({ message: (error as Error).message, type: "error" }));
      } else {
        dispatch(enqueueSnackbarMessage({ message: SnackMessage.error.respondToOffer, type: "error" }));
      }
    } finally {
      setRespondingToOffer(false);
    }
  };

  return (
    <PageContainer>
      {selectedApplication && dialogKind === "accept" && (
        <AcceptOfferDialog
          jobTitle={selectedApplication.jobTitle}
          sending={respondingToOffer}
          onConfirm={() => handleOfferAnswer({ response: "accepted" })}
          onClose={() => setOfferDialog(null)}
        />
      )}
      {selectedApplication && dialogKind === "decline" && (
        <DeclineOfferDialog
          jobTitle={selectedApplication.jobTitle}
          sending={respondingToOffer}
          onDecline={handleOfferAnswer}
          onClose={() => setOfferDialog(null)}
        />
      )}
      {selectedApplication && dialogKind === "welcome" && (
        <WelcomeDialog
          jobTitle={selectedApplication.jobTitle}
          onSubmitDocuments={
            DOCUMENTS_SUBMISSION_ENABLED ? () => navigate(`/applications/${selectedApplication.id}/documents`) : undefined
          }
          onClose={() => setOfferDialog(null)}
        />
      )}
      {applicationId ? (
        <>
          <Button
            variant="outlined"
            startIcon={<ArrowLeft size={16} />}
            onClick={() => navigate("/applications")}
            sx={{ ...pillButtonSx, mb: 2, px: 2.5 }}
          >
            Applications
          </Button>

          {selectedApplication ? (
            <ApplicationDetails
              application={selectedApplication}
              canAcceptOffer={!applications.some((a) => a.status === ApplicationStatus.OfferAccepted)}
              onAcceptOffer={() => setOfferDialog({ kind: "accept", applicationId: selectedApplication.id })}
              onDeclineOffer={() => setOfferDialog({ kind: "decline", applicationId: selectedApplication.id })}
              onSubmitDocuments={() => navigate(`/applications/${selectedApplication.id}/documents`)}
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
          signedInEmail={signedInEmail}
          onView={(id) => navigate(`/applications/${id}`)}
          onBrowseJobs={() => window.open(CareersSiteUrl, "_blank", "noopener,noreferrer")}
          onRetry={() => dispatch(retryApplications())}
        />
      )}
    </PageContainer>
  );
};

export default Applications;
