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
  Application,
  ApplicationInterview,
  CandidateProfile,
  DocumentRequirements,
  DocumentsStatus,
  EditableProfileFields,
  OfferAnswer,
  OfferLetter,
  PersonalDetails,
} from "@/types/types";
import { ApplicationStatus, OFFER_CONFLICT_ERROR, OFFER_EXPIRED_ERROR } from "@config/constant";
import { isValidE164 } from "@utils/phone";

// In-memory stand-in for the backend, used when USE_MOCK_PROFILE is "true".

const LATENCY_MS = 250;
const EDITABLE_FIELDS: (keyof EditableProfileFields)[] = [
  "firstName",
  "lastName",
  "gender",
  "contactNo",
  "address",
  "university",
];

let profile: CandidateProfile = {
  firstName: "Alice",
  lastName: "Bob",
  gender: "Female",
  personalEmail: "subavarshana@wso2.com",
  contactNo: "+94771234567",
  address: "45 Galle Road, Colombo 03, Sri Lanka",
  university: "University of Moratuwa",
};

const delay = () => new Promise<void>((resolve) => setTimeout(resolve, LATENCY_MS));

export async function fetchProfile(): Promise<CandidateProfile> {
  await delay();
  return structuredClone(profile);
}

export async function saveProfile(changes: Partial<EditableProfileFields>): Promise<CandidateProfile> {
  await delay();
  if (changes.contactNo !== undefined && !isValidE164(changes.contactNo)) {
    throw new Error("Enter the phone number.");
  }
  const allowed = Object.fromEntries(
    Object.entries(changes).filter(([key]) => EDITABLE_FIELDS.includes(key as keyof EditableProfileFields)),
  );
  profile = { ...profile, ...allowed };
  return structuredClone(profile);
}

// A date as YYYY-MM-DD in the local calendar.
const dateOnly = (date: Date) =>
  `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, "0")}-${String(date.getDate()).padStart(2, "0")}`;

const daysFromNow = (days: number) => {
  const date = new Date();
  date.setDate(date.getDate() + days);
  return dateOnly(date);
};

const applications: Application[] = [
  {
    id: "a1",
    jobId: "228",
    jobTitle: "Intern - Customer Success",
    department: "Customer Success",
    appliedDate: "2026-10-05",
    status: ApplicationStatus.Applied,
    timeline: [{ stage: ApplicationStatus.Applied, date: "2026-10-05" }],
  },
  {
    id: "a2",
    jobId: "228",
    jobTitle: "Administration Officer - People Operations",
    department: "People Operations",
    appliedDate: "2026-09-28",
    status: ApplicationStatus.Screening,
    timeline: [
      { stage: ApplicationStatus.Applied, date: "2026-09-28" },
      { stage: ApplicationStatus.Screening, date: "2026-10-02" },
    ],
  },
  {
    id: "a3",
    jobId: "240",
    jobTitle: "Senior Software Engineer - Identity",
    department: "Engineering",
    appliedDate: "2026-09-10",
    status: ApplicationStatus.Interview,
    timeline: [
      { stage: ApplicationStatus.Applied, date: "2026-09-10" },
      { stage: ApplicationStatus.Screening, date: "2026-09-14" },
      { stage: ApplicationStatus.Interview, date: "2026-09-20" },
    ],
    interviews: [
      {
        id: "i0",
        round: "Screening call",
        dateTime: "2026-10-12T10:00:00",
        mode: "Video",
        location: "https://meet.example.com/screening",
        status: "Completed",
      },
      {
        id: "i1",
        round: "Technical Interview",
        dateTime: "2026-11-05T11:00:00",
        mode: "Video",
        location: "https://meet.example.com/technical",
        status: "Upcoming",
      },
    ],
  },
  {
    id: "a4",
    jobId: "245",
    jobTitle: "Solutions Architect",
    department: "Sales Engineering",
    appliedDate: "2026-08-20",
    status: ApplicationStatus.Offer,
    offerExpiresOn: daysFromNow(7),
    timeline: [
      { stage: ApplicationStatus.Applied, date: "2026-08-20" },
      { stage: ApplicationStatus.Interview, date: "2026-09-08" },
      { stage: ApplicationStatus.Offer, date: "2026-09-25" },
    ],
  },
  {
    id: "a5",
    jobId: "250",
    jobTitle: "Associate Technical Writer",
    department: "Engineering",
    appliedDate: "2026-08-02",
    status: ApplicationStatus.Rejected,
    timeline: [
      { stage: ApplicationStatus.Applied, date: "2026-08-02" },
      { stage: ApplicationStatus.Screening, date: "2026-08-09" },
      { stage: ApplicationStatus.Rejected, date: "2026-08-16" },
    ],
  },
  {
    id: "a7",
    jobId: "260",
    jobTitle: "Business Analyst",
    department: "Business Operations",
    appliedDate: "2026-07-01",
    status: ApplicationStatus.OfferDeclined,
    timeline: [
      { stage: ApplicationStatus.Applied, date: "2026-07-01" },
      { stage: ApplicationStatus.Interview, date: "2026-07-20" },
      { stage: ApplicationStatus.Offer, date: "2026-08-01" },
      { stage: ApplicationStatus.OfferDeclined, date: "2026-08-05" },
    ],
  },
];

export async function fetchInterviews(applicationId: string): Promise<ApplicationInterview[]> {
  await delay();
  return applications.find((a) => a.id === applicationId)?.interviews ?? [];
}

// No offer letter is kept for the mock applications.
export async function fetchOfferLetter(): Promise<OfferLetter | null> {
  await delay();
  return null;
}

const MEGABYTE = 1024 * 1024;

const documentRequirements: DocumentRequirements = {
  documents: [
    { key: "nic", label: "National identity card", required: true, group: "documents", types: ["pdf", "jpg", "png"] },
    { key: "degree", label: "Degree certificate", required: true, group: "documents", types: ["pdf"] },
    { key: "photo", label: "Profile photo", required: true, group: "photos", types: ["jpg", "png"], minSquareSide: 400 },
  ],
  maxFiles: 10,
  maxFileBytes: 5 * MEGABYTE,
  maxTotalBytes: 20 * MEGABYTE,
  tshirtSizes: ["S", "M", "L", "XL"],
  titles: ["Mr", "Ms", "Mrs", "Dr"],
  genders: ["Male", "Female", "Other"],
  civilStatuses: ["Single", "Married"],
  dependantRelationships: ["Spouse", "Child", "Parent"],
  maxDependants: 2,
  maxEmergencyContacts: 2,
};

export async function fetchDocumentRequirements(): Promise<DocumentRequirements> {
  await delay();
  return structuredClone(documentRequirements);
}

// The submissions made in this session, by application, which cannot be changed afterwards.
const submissions = new Map<string, { details: PersonalDetails; files: string[] }>();

export async function fetchDocumentsStatus(applicationId: string): Promise<DocumentsStatus> {
  await delay();
  const submission = submissions.get(applicationId);
  return {
    submitted: submission !== undefined,
    canEdit: false,
    editableUntil: "",
    details: submission ? structuredClone(submission.details) : null,
    files: submission?.files ?? [],
  };
}

export async function submitDocuments(
  applicationId: string,
  files: Record<string, File>,
  details: PersonalDetails,
): Promise<void> {
  await delay();
  if (submissions.has(applicationId)) {
    throw new Error("The documents were already submitted.");
  }
  submissions.set(applicationId, { details: structuredClone(details), files: Object.keys(files) });
}

export async function submitFeedback(applicationId: string): Promise<void> {
  await delay();
  const application = applications.find((a) => a.id === applicationId);
  if (application) application.feedbackSubmitted = true;
}

export async function respondToOffer(applicationId: string, answer: OfferAnswer): Promise<Application> {
  await delay();
  const application = applications.find((a) => a.id === applicationId);
  if (!application || application.status !== ApplicationStatus.Offer) {
    throw Object.assign(new Error("There is no offer to answer."), { name: OFFER_CONFLICT_ERROR });
  }
  if (application.offerExpiresOn && application.offerExpiresOn < daysFromNow(0)) {
    throw Object.assign(new Error("This offer has expired."), { name: OFFER_EXPIRED_ERROR });
  }
  const acceptedElsewhere = applications.some((a) => a.status === ApplicationStatus.OfferAccepted);
  if (answer.response === "accepted" && acceptedElsewhere) {
    throw Object.assign(new Error("Another offer was already accepted."), { name: OFFER_CONFLICT_ERROR });
  }
  application.status = answer.response === "accepted" ? ApplicationStatus.OfferAccepted : ApplicationStatus.OfferDeclined;
  application.timeline = [
    ...(application.timeline ?? []),
    { stage: application.status, date: dateOnly(new Date()) },
  ];
  return structuredClone(application);
}

// Adds an application the candidate just made, so the Applications page shows it.
export function addApplication(jobId: string, jobTitle: string, department: string): void {
  const date = dateOnly(new Date());
  applications.unshift({
    id: `new-${Date.now()}`,
    jobId,
    jobTitle,
    department,
    appliedDate: date,
    status: ApplicationStatus.Applied,
    timeline: [{ stage: ApplicationStatus.Applied, date }],
  });
}

export async function fetchApplications(): Promise<Application[]> {
  await delay();
  return structuredClone(applications);
}
