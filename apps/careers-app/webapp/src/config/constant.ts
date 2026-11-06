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

export const SnackMessage = {
  success: {
    profileUpdated: "Profile updated successfully!",
    offerDeclined: "You declined the offer.",
    documentsSent: "Your documents were submitted.",
    documentsUpdated: "Your changes were saved.",
  },
  error: {
    fetchApplications: "Unable to retrieve your applications.",
    fetchProfile: "Unable to retrieve your profile.",
    saveProfile: "Unable to save your changes. Please try again.",
    respondToOffer: "Unable to record your response to the offer. Please try again.",
    offerConflict: "This offer was already answered, or you have already accepted another offer.",
    offerExpired: "This offer has expired. Please contact the recruitment team if you still want to join.",
    offerNotFound: "This offer is no longer available. Please contact the recruitment team.",
    fetchDocumentRequirements: "Unable to load the list of documents. Please try again.",
    submitDocuments: "Unable to submit your documents. Please try again.",
    sessionEndedOnSubmit: "Your session has ended. Please sign in again to submit your documents.",
    documentsAlreadySent: "Your documents were already submitted for this application.",
    documentsNotAllowed: "Documents can't be submitted for this application.",
    documentsTooLarge: "The files are too large to send.",
    documentsTooManyAttempts: "Too many attempts. Please try again later.",
  },
  warning: {},
};

// The names of the errors raised when the backend refuses an offer answer.
export const OFFER_CONFLICT_ERROR = "OfferConflictError";
export const OFFER_EXPIRED_ERROR = "OfferExpiredError";
export const OFFER_NOT_FOUND_ERROR = "OfferNotFoundError";
export const OFFER_INVALID_ERROR = "OfferInvalidError";

// The first phase stops once a candidate has accepted or declined an offer, so the onboarding documents step is hidden.
// Turn it on, together with the backend setting documentsEnabled, when that step opens.
export const DOCUMENTS_SUBMISSION_ENABLED = false;

export enum ApplicationStatus {
  Applied = "Applied",
  Screening = "Screening",
  Interview = "Interview",
  Selected = "Selected",
  Offer = "Offer",
  OfferAccepted = "Offer Accepted",
  OfferDeclined = "Offer Declined",
  OfferExpired = "Offer Expired",
  Rejected = "Rejected",
}
