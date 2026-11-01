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

import { MapPin, Phone, Video } from "lucide-react";

import type { Application, ApplicationInterview } from "@/types/types";
import { BRAND_ORANGE, ON_ORANGE } from "@config/brand";
import { ApplicationStatus } from "@config/constant";

// The stages shown in the tracker.
export const STAGES = ["Applied", "Screening", "Interview", "Offer"];

const STAGE_INDEX: Partial<Record<ApplicationStatus, number>> = {
  [ApplicationStatus.Applied]: 0,
  [ApplicationStatus.Screening]: 1,
  [ApplicationStatus.Interview]: 2,
  [ApplicationStatus.Offer]: 3,
  [ApplicationStatus.OfferAccepted]: 3,
  [ApplicationStatus.OfferDeclined]: 3,
};

// Parses a date, or null when invalid; a date without a time is a local day.
const parseDate = (value: string): Date | null => {
  const dateOnly = /^(\d{4})-(\d{2})-(\d{2})$/.exec(value);
  if (dateOnly) {
    const [year, month, day] = dateOnly.slice(1).map(Number);
    const date = new Date(year, month - 1, day);
    // Rejects a day that does not exist.
    const exists = date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day;
    return exists ? date : null;
  }
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
};

export const formatDate = (value: string) =>
  parseDate(value)?.toLocaleDateString(undefined, { day: "numeric", month: "short", year: "numeric" }) ?? "-";

export const formatDateTime = (value: string) =>
  parseDate(value)?.toLocaleString(undefined, { dateStyle: "medium", timeStyle: "short" }) ?? "-";

// The tracker's active step, and the step to mark as an error for a rejected application.
export function trackerOf(application: Application): { activeStep: number; errorStep: number | null } {
  if (application.status === ApplicationStatus.Rejected) {
    const reached = Math.max(0, ...(application.timeline ?? []).map((event) => STAGE_INDEX[event.stage] ?? 0));
    return { activeStep: reached, errorStep: reached };
  }
  return { activeStep: STAGE_INDEX[application.status] ?? 0, errorStep: null };
}

// One line of an application's history.
export interface HistoryEntry {
  label: string;
  date: string | null;
  // Whether the date carries a time of day.
  withTime?: boolean;
  detail?: string;
}

// Statuses that end the journey or answer the offer.
const FINAL_STATUSES = [
  ApplicationStatus.Offer,
  ApplicationStatus.OfferAccepted,
  ApplicationStatus.OfferDeclined,
  ApplicationStatus.Rejected,
];

// The application's history: applied, screened, each interview and the final status.
export function historyOf(application: Application, interviews: ApplicationInterview[]): HistoryEntry[] {
  const entries: HistoryEntry[] = [{ label: ApplicationStatus.Applied, date: application.appliedDate }];
  const { status } = application;
  if ((STAGE_INDEX[status] ?? 0) >= STAGE_INDEX[ApplicationStatus.Screening]!) {
    const screeningIsCurrent = status === ApplicationStatus.Screening;
    const screeningDated = screeningIsCurrent || status === ApplicationStatus.Interview;
    entries.push({
      label: ApplicationStatus.Screening,
      date: screeningDated ? (application.updatedDate ?? null) : null,
      detail: screeningIsCurrent ? "Current" : "Passed",
    });
  }
  [...interviews]
    .sort((a, b) => a.dateTime.localeCompare(b.dateTime))
    .forEach((interview) =>
      entries.push({
        label: interview.round,
        date: interview.dateTime || null,
        withTime: true,
        detail: `Interview · ${interview.status}`,
      }),
    );
  if (FINAL_STATUSES.includes(status)) {
    entries.push({ label: status, date: application.updatedDate ?? null, detail: "Current" });
  }
  return entries;
}

// Whether an offer is waiting for the candidate's answer.
export const isOffer = (application: Application) => application.status === ApplicationStatus.Offer;

const startOfDay = (date: Date) => new Date(date.getFullYear(), date.getMonth(), date.getDate()).getTime();

// The offer deadline with the days left.
export function offerDeadlineOf(application: Application): { date: string; daysLeft: number } | null {
  const end = application.offerExpiresOn ? parseDate(application.offerExpiresOn) : null;
  if (!end) return null;
  return {
    date: formatDate(application.offerExpiresOn as string),
    daysLeft: Math.round((startOfDay(end) - startOfDay(new Date())) / 86_400_000),
  };
}

// The days left to answer an offer, in words.
export const daysLeftText = (daysLeft: number) => {
  if (daysLeft < 0) return "expired";
  if (daysLeft === 0) return "last day to respond";
  return daysLeft === 1 ? "1 day left" : `${daysLeft} days left`;
};

type ApplicationTab = "active" | "offers" | "closed";

// The tab chosen above the list.
export type ApplicationFilter = "all" | ApplicationTab;

// The list tab an application belongs under.
export const tabOf = (application: Application): ApplicationTab => {
  switch (application.status) {
    case ApplicationStatus.Offer:
    case ApplicationStatus.OfferAccepted:
      return "offers";
    case ApplicationStatus.OfferDeclined:
    case ApplicationStatus.Rejected:
      return "closed";
    default:
      return "active";
  }
};

// The tab to open the list on: offers, then interviews, then rejections.
export function defaultTabOf(applications: Application[]): ApplicationFilter {
  if (applications.length === 0) return "all";
  if (applications.some((a) => tabOf(a) === "offers")) return "offers";
  if (applications.some((a) => a.status === ApplicationStatus.Interview)) return "active";
  if (applications.some((a) => a.status === ApplicationStatus.Rejected)) return "closed";
  return tabOf(applications[0]);
}

// How long ago a date was, in words.
export const timeAgo = (value: string) => {
  const date = parseDate(value);
  if (!date) return "recently";
  const days = Math.floor((Date.now() - date.getTime()) / 86_400_000);
  if (days <= 0) return "today";
  if (days === 1) return "yesterday";
  if (days < 7) return `${days} days ago`;
  if (days < 14) return "last week";
  if (days < 30) return `${Math.floor(days / 7)} weeks ago`;
  if (days < 60) return "last month";
  return `${Math.floor(days / 30)} months ago`;
};

// The upcoming interview of an application at the interview stage.
export const upcomingInterviewOf = (application: Application, interviews: ApplicationInterview[]) =>
  application.status === ApplicationStatus.Interview
    ? interviews.find((interview) => interview.status === "Upcoming")
    : undefined;

// The one-line next step of an application.
export function nextStepOf(application: Application, interviews: ApplicationInterview[]): string {
  switch (application.status) {
    case ApplicationStatus.Applied:
      return "Waiting for the hiring team to review your application";
    case ApplicationStatus.Screening:
      return "Your profile is being reviewed";
    case ApplicationStatus.Interview: {
      const upcoming = upcomingInterviewOf(application, interviews);
      return upcoming
        ? `Next: ${upcoming.round} · ${formatDateTime(upcoming.dateTime)}`
        : "Waiting for the interview outcome";
    }
    case ApplicationStatus.Offer:
      return "An offer has been sent to your email. Please check your inbox.";
    case ApplicationStatus.OfferAccepted:
      return "You accepted the offer. The hiring team will contact you with the next steps.";
    case ApplicationStatus.OfferDeclined:
      return "You declined the offer";
    case ApplicationStatus.Rejected:
      return "Not selected for this position";
    default:
      return "";
  }
}

export const interviewChip: Record<ApplicationInterview["status"], { color: string; bg: string }> = {
  // Solid orange for an upcoming interview.
  Upcoming: { color: ON_ORANGE, bg: BRAND_ORANGE },
  Completed: { color: "#059669", bg: "rgba(5,150,105,0.14)" },
  Cancelled: { color: "#6B7280", bg: "rgba(107,114,128,0.16)" },
};

export const interviewIcon = { Video, Phone, Onsite: MapPin };
