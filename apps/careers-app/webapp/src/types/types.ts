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

import { ApplicationStatus } from "@config/constant";

export enum State {
  failed = "failed",
  success = "success",
  loading = "loading",
  idle = "idle",
}

export enum ThemeMode {
  Light = "light",
  Dark = "dark",
}

export interface PreLoaderProps {
  message?: string;
  isLoading?: boolean;
}

// A candidate's profile.
export interface CandidateProfile {
  firstName: string;
  lastName: string;
  gender: string;
  personalEmail: string;
  contactNo: string;
  address: string | null;
  university: string | null;
  // False when no application backs the profile; absent means editable.
  editable?: boolean;
}

// The details a candidate can change themselves.
export type EditableProfileFields = Pick<
  CandidateProfile,
  "firstName" | "lastName" | "gender" | "contactNo" | "address" | "university"
>;

export interface Job {
  id: string;
  title: string;
  team: string;
  country: string[];
  jobType: string;
  publishStatus: string;
  postedDate: string;
}

// What an applicant submits alongside their CV.
export interface GuestApplicationDetails {
  firstName: string;
  lastName: string;
  email: string;
  phone: string;
  address: string;
  university?: string;
  authorizedToWork: boolean;
  // Whether the candidate agreed to receive emails from WSO2.
  marketingEmails: boolean;
}

interface ApplicationTimelineEvent {
  stage: ApplicationStatus;
  date: string;
}

export interface ApplicationInterview {
  id: string;
  round: string;
  // ISO date-time of the interview.
  dateTime: string;
  mode: "Video" | "Phone" | "Onsite";
  // Where the interview takes place: a link, a number or an address, by mode.
  location: string;
  status: "Upcoming" | "Completed" | "Cancelled";
}

// A candidate's application and its progress.
export interface Application {
  id: string;
  jobId: string;
  jobTitle: string;
  department: string;
  appliedDate: string;
  // When the application last changed, which is when it reached its current status.
  updatedDate?: string;
  status: ApplicationStatus;
  // The last day the candidate can answer an offer.
  offerExpiresOn?: string;
  // True once the candidate has sent feedback about this application.
  feedbackSubmitted?: boolean;
  timeline?: ApplicationTimelineEvent[];
  // Only present when the list of applications carries the interviews.
  interviews?: ApplicationInterview[];
}

// A candidate's answer to an offer; a declined offer carries the reason.
export interface OfferAnswer {
  response: "accepted" | "declined";
  reason?: string;
  comment?: string;
}

// The offer letter a candidate was sent.
export interface OfferLetter {
  // The subject of the email the letter was sent in.
  subject: string;
  // ISO date-time the letter was sent.
  sentOn: string;
  // A reference to the email thread the letter was sent in; empty when there is none.
  threadId: string;
  // The letter itself, as HTML.
  html: string;
}

// The personal details a new joiner fills in after accepting an offer.
export interface PersonalDetails {
  title: string;
  // The first name and the last name, as the ATS keeps them.
  firstName: string;
  surname: string;
  // The full name as on the identity document, which the candidate types.
  fullName: string;
  preferredName: string;
  initials: string;
  nameWithInitials: string;
  gender: string;
  // The date of birth as yyyy-mm-dd.
  dateOfBirth: string;
  // The number of the identity document: a national identity card or a passport.
  idNumber: string;
  civilStatus: string;
  tshirtSize: string;
  homeAddress: string;
  temporaryAddress: string;
  // The mobile number in international format.
  mobileNumber: string;
  // The land line in international format; empty when there is none.
  landNumber: string;
  personalEmail: string;
  // Yes or No: whether the joiner has an interest in any commercial or business pursuit.
  businessInterest: string;
  dependants: Dependant[];
  emergencyContacts: EmergencyContact[];
  bank: BankDetails;
  highestQualification: string;
  university: string;
  githubUserId: string;
}

// A person the new joiner supports, who may be covered by the company's insurance policy.
export interface Dependant {
  // Spouse, Child or Parent.
  relationship: string;
  name: string;
  // The date of birth as yyyy-mm-dd.
  dateOfBirth: string;
  // A child may have none.
  idNumber: string;
}

// A person to call in an emergency.
export interface EmergencyContact {
  name: string;
  relationship: string;
  address: string;
  mobileNumber: string;
  landNumber: string;
}

// The account the salary is paid into.
interface BankDetails {
  bank: string;
  branch: string;
  // Digits only.
  accountNumber: string;
}

// What the backend says about a candidate's submission of the onboarding documents.
export interface DocumentsStatus {
  submitted: boolean;
  // Whether the submission can still be changed.
  canEdit: boolean;
  // The deadline for changes as an ISO 8601 time, or an empty text when none is set.
  editableUntil: string;
  // The details saved with the submission.
  details?: PersonalDetails | null;
  // The keys of the documents already sent.
  files: string[];
}

// One document the candidate is asked for after accepting an offer.
export interface DocumentRequirement {
  // The name the file is sent under.
  key: string;
  label: string;
  required: boolean;
  // The step of the form the document belongs to.
  group: "documents" | "photos";
  // The file types this document accepts: pdf, jpg or png.
  types: string[];
  // A line of guidance shown under the name.
  hint?: string;
  // When above zero, the picture must be square and at least this many pixels on each side.
  minSquareSide?: number;
}

// The documents asked for, and the limits every file must meet.
export interface DocumentRequirements {
  documents: DocumentRequirement[];
  maxFiles: number;
  maxFileBytes: number;
  maxTotalBytes: number;
  // The choices the details form offers.
  tshirtSizes: string[];
  titles: string[];
  genders: string[];
  civilStatuses: string[];
  dependantRelationships: string[];
  maxDependants: number;
  maxEmergencyContacts: number;
}

// What a candidate tells us about their application experience.
export interface ApplicationFeedback {
  rating: number | null;
  comment: string;
}
