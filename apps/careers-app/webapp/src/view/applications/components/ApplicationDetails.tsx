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

import { Box, Button, Card, CardContent, Skeleton, Stack, Step, StepLabel, Stepper, Typography } from "@mui/material";
import { Award, Info } from "lucide-react";

import DOMPurify from "dompurify";
import { useState } from "react";

import type { Application, ApplicationInterview, DocumentsStatus, OfferLetter } from "@/types/types";
import ApplicationStatusBadge from "@component/careers/ApplicationStatusBadge";
import Callout from "@component/common/Callout";
import { orangeTextOf } from "@config/brand";
import { ApplicationStatus } from "@config/constant";
import { cardSx, pillButtonSx } from "@utils/styles";
import {
  STAGES,
  daysLeftText,
  formatDate,
  historyOf,
  isOffer,
  nextStepOf,
  offerDeadlineOf,
  trackerOf,
  upcomingInterviewOf,
} from "@view/applications/applicationHelpers";
import InterviewsSection from "@view/applications/components/InterviewsSection";
import OfferActions from "@view/applications/components/OfferActions";
import ProgressHistory from "@view/applications/components/ProgressHistory";

interface ApplicationDetailsProps {
  application: Application;
  // Whether the vacancy is still listed.
  jobOpen: boolean;
  onOpenJob: (jobId: string) => void;
  canAcceptOffer: boolean;
  onAcceptOffer: () => void;
  onDeclineOffer: () => void;
  onSubmitDocuments: () => void;
  // The offer letter that was sent, when the ATS has it.
  offerLetter: OfferLetter | null;
  // The interviews of the application, past and upcoming.
  interviews: ApplicationInterview[];
  // Documents submission status; undefined while loading, null when it failed.
  documentsStatus: DocumentsStatus | null | undefined;
  onRetryDocumentsStatus: () => void;
}

const ApplicationDetails = ({
  application,
  jobOpen,
  onOpenJob,
  canAcceptOffer,
  onAcceptOffer,
  onDeclineOffer,
  onSubmitDocuments,
  offerLetter,
  interviews,
  documentsStatus,
  onRetryDocumentsStatus,
}: ApplicationDetailsProps) => {
  const [letterOpen, setLetterOpen] = useState(false);
  const actionNeeded = isOffer(application);
  // An upcoming interview is shown in orange.
  const interviewComing = upcomingInterviewOf(application, interviews) !== undefined;
  const deadline = actionNeeded ? offerDeadlineOf(application) : null;
  const offerExpired = deadline !== null && deadline.daysLeft < 0;
  const { activeStep, errorStep } = trackerOf(application);

  return (
    <Card elevation={0} sx={cardSx}>
      <Box sx={{ p: 3 }}>
        <Stack direction="row" alignItems="flex-start" justifyContent="space-between" flexWrap="wrap" gap={1.5}>
          <Box sx={{ minWidth: 0 }}>
            <Typography
              component="h1"
              sx={{ fontSize: { xs: "1.5rem", md: "1.9rem" }, lineHeight: 1.3, fontWeight: 400, color: "text.primary" }}
            >
              {application.jobTitle}
            </Typography>
            <Typography fontSize="0.9rem" color="text.secondary" mt={0.5}>
              {application.department} · Applied on {formatDate(application.appliedDate)}
            </Typography>
          </Box>
          <ApplicationStatusBadge status={application.status} />
        </Stack>
        <Typography
          fontSize="0.95rem"
          fontWeight={actionNeeded || interviewComing ? 700 : 500}
          sx={{
            mt: 1.5,
            color: (theme) => (actionNeeded || interviewComing ? orangeTextOf(theme) : theme.palette.text.secondary),
          }}
        >
          {nextStepOf(application, interviews)}
        </Typography>
      </Box>

      <CardContent sx={{ pt: 3, px: 3, pb: 3, borderTop: "1px solid", borderColor: "divider" }}>
        <Stepper
          alternativeLabel
          activeStep={activeStep}
          sx={{
            mb: 3,
            "& .MuiStepIcon-root": { color: "divider" },
            "& .MuiStepIcon-root.Mui-active, & .MuiStepIcon-root.Mui-completed": { color: "primary.main" },
            "& .MuiStepIcon-root.Mui-error": { color: "#EF4444" },
            "& .MuiStepLabel-label": { fontSize: "0.85rem" },
            "& .MuiStepConnector-root.Mui-active .MuiStepConnector-line, & .MuiStepConnector-root.Mui-completed .MuiStepConnector-line":
              { borderColor: "primary.main" },
          }}
        >
          {STAGES.map((label, index) => (
            <Step key={label}>
              <StepLabel error={index === errorStep}>{label}</StepLabel>
            </Step>
          ))}
        </Stepper>

        {isOffer(application) && (
          <Callout tone="success" icon={<Award size={20} color="#059669" />} sx={{ mb: 3 }}>
            <Typography fontWeight={700} fontSize="0.95rem" color="text.primary">
              Congratulations - you have been selected for this position.
            </Typography>
            <Typography fontSize="0.9rem" color="text.primary">
              We have sent your offer to your email. Please check your inbox, and your spam folder if you can&apos;t
              find it.
            </Typography>
            {deadline && (
              <Typography fontSize="0.9rem" fontWeight={700} color={offerExpired ? "error" : "text.primary"} mt={1}>
                {offerExpired
                  ? `This offer expired on ${deadline.date}. Please contact the recruitment team if you still want to join.`
                  : `Please respond by ${deadline.date} (${daysLeftText(deadline.daysLeft)}).`}
              </Typography>
            )}
          </Callout>
        )}

        {isOffer(application) && !offerExpired && (
          <OfferActions canAccept={canAcceptOffer} onAccept={onAcceptOffer} onDecline={onDeclineOffer} />
        )}

        {application.status === ApplicationStatus.OfferAccepted && (
          <Callout tone="success" icon={<Award size={20} color="#059669" />} sx={{ mb: 3 }}>
            <Typography fontWeight={700} fontSize="0.95rem" color="text.primary">
              You accepted this offer.
            </Typography>
            {documentsStatus === undefined ? (
              <Skeleton variant="rounded" width={170} height={40} sx={{ borderRadius: "999px", mt: 1.5 }} />
            ) : documentsStatus === null ? (
              <>
                <Typography fontSize="0.9rem" color="text.primary" mt={0.5}>
                  We could not check whether your documents were submitted.
                </Typography>
                <Button variant="outlined" onClick={onRetryDocumentsStatus} sx={{ ...pillButtonSx, px: 3, mt: 1.5 }}>
                  Try again
                </Button>
              </>
            ) : documentsStatus.submitted ? (
              <>
                <Typography fontSize="0.9rem" color="text.primary">
                  We received your details and documents. The hiring team will contact you with the next steps.
                </Typography>
                {documentsStatus.canEdit ? (
                  <>
                    {documentsStatus.editableUntil && (
                      <Typography fontSize="0.9rem" color="text.primary" mt={0.5}>
                        You can make changes until{" "}
                        {new Date(documentsStatus.editableUntil).toLocaleDateString(undefined, {
                          day: "numeric",
                          month: "long",
                          year: "numeric",
                        })}
                        .
                      </Typography>
                    )}
                    <Button variant="outlined" onClick={onSubmitDocuments} sx={{ ...pillButtonSx, px: 3, mt: 1.5 }}>
                      Edit submission
                    </Button>
                  </>
                ) : (
                  <Typography fontSize="0.9rem" color="text.primary" mt={0.5}>
                    {documentsStatus.editableUntil
                      ? "The time to make changes has ended."
                      : "Please contact the hiring team if something needs to change."}
                  </Typography>
                )}
              </>
            ) : (
              <>
                <Typography fontSize="0.9rem" color="text.primary">
                  Please submit the documents we need for your onboarding. The hiring team will contact you with the
                  next steps.
                </Typography>
                <Button variant="contained" onClick={onSubmitDocuments} sx={{ ...pillButtonSx, px: 3, mt: 1.5 }}>
                  Submit documents
                </Button>
              </>
            )}
          </Callout>
        )}

        {offerLetter && (
          <Box sx={{ mb: 3, p: 2, border: "1px solid", borderColor: "divider", borderRadius: "8px" }}>
            <Typography fontWeight={700} fontSize="0.95rem" color="text.primary">
              Your offer letter
            </Typography>
            <Typography fontSize="0.9rem" color="text.primary" mt={0.5} sx={{ wordBreak: "break-word" }}>
              {offerLetter.subject}
            </Typography>
            <Typography fontSize="0.85rem" color="text.secondary">
              Sent on {formatDate(offerLetter.sentOn)}
              {offerLetter.threadId && ` · Email reference: ${offerLetter.threadId}`}
            </Typography>
            <Button size="small" onClick={() => setLetterOpen((open) => !open)} sx={{ fontWeight: 600, mt: 1, ml: -1 }}>
              {letterOpen ? "Hide letter" : "Show letter"}
            </Button>
            {letterOpen && (
              <Box
                sx={{ mt: 1, fontSize: "0.9rem", overflowX: "auto", "& img": { maxWidth: "100%" } }}
                dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(offerLetter.html) }}
              />
            )}
          </Box>
        )}

        {application.status === ApplicationStatus.OfferDeclined && (
          <Callout tone="brand" icon={<Info size={20} color="#6B7280" />} sx={{ mb: 3 }}>
            <Typography fontWeight={700} fontSize="0.95rem" color="text.primary">
              You declined this offer.
            </Typography>
          </Callout>
        )}

        {application.status === ApplicationStatus.Rejected && (
          <Callout tone="danger" icon={<Info size={20} color="#DC2626" />} sx={{ mb: 3 }}>
            <Typography fontWeight={700} fontSize="0.95rem" color="text.primary">
              You were not selected this time.
            </Typography>
          </Callout>
        )}

        <InterviewsSection interviews={interviews} />

        <ProgressHistory entries={historyOf(application, interviews)} />

        {jobOpen && (
          <Button size="small" onClick={() => onOpenJob(application.jobId)} sx={{ fontWeight: 600 }}>
            View job
          </Button>
        )}
      </CardContent>
    </Card>
  );
};

export default ApplicationDetails;
