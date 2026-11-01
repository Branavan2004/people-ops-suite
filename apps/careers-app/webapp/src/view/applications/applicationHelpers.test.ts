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

import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type { Application, ApplicationInterview } from "@/types/types";
import { ApplicationStatus } from "@config/constant";
import { daysLeftText, defaultTabOf, historyOf, offerDeadlineOf, tabOf, trackerOf } from "@view/applications/applicationHelpers";

const application = (overrides: Partial<Application> = {}): Application => ({
  id: "a1",
  jobId: "1",
  jobTitle: "Site Reliability Engineer",
  department: "Engineering",
  appliedDate: "2026-09-01",
  status: ApplicationStatus.Applied,
  ...overrides,
});

describe("offerDeadlineOf and daysLeftText", () => {
  // Noon on 19 Oct in the machine's own time zone, so the results do not depend on where the tests run.
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date(2026, 9, 19, 12));
  });
  afterEach(() => vi.useRealTimers());

  const daysLeftFor = (offerExpiresOn: string) => offerDeadlineOf(application({ offerExpiresOn }))?.daysLeft;

  it("counts the last day as 0 days left", () => {
    expect(daysLeftFor("2026-10-19")).toBe(0);
    expect(daysLeftText(0)).toBe("last day to respond");
  });

  it("counts the day after as expired", () => {
    expect(daysLeftFor("2026-10-18")).toBe(-1);
    expect(daysLeftText(-1)).toBe("expired");
  });

  it("counts the days ahead", () => {
    expect(daysLeftFor("2026-10-20")).toBe(1);
    expect(daysLeftFor("2026-10-26")).toBe(7);
    expect(daysLeftText(1)).toBe("1 day left");
    expect(daysLeftText(7)).toBe("7 days left");
  });

  it("has no deadline when the application has none or it cannot be read", () => {
    expect(offerDeadlineOf(application())).toBeNull();
    expect(offerDeadlineOf(application({ offerExpiresOn: "not a date" }))).toBeNull();
    expect(offerDeadlineOf(application({ offerExpiresOn: "2026-02-30" }))).toBeNull();
  });

  // Run the tests with TZ=America/Los_Angeles (and America/New_York) to cover a negative-offset time zone: a
  // date-only value read as midnight UTC would fall on the day before and give -1 here.
  it("does not shift a date-only deadline back a day west of UTC", () => {
    expect(daysLeftFor("2026-10-19")).toBeGreaterThanOrEqual(0);
  });
});

describe("trackerOf", () => {
  const rejectedAfter = (...stages: ApplicationStatus[]) =>
    application({
      status: ApplicationStatus.Rejected,
      timeline: [...stages, ApplicationStatus.Rejected].map((stage) => ({ stage, date: "2026-09-10" })),
    });

  it.each([
    [[ApplicationStatus.Applied], 0],
    [[ApplicationStatus.Applied, ApplicationStatus.Screening], 1],
    [[ApplicationStatus.Applied, ApplicationStatus.Screening, ApplicationStatus.Interview], 2],
    [[ApplicationStatus.Applied, ApplicationStatus.Screening, ApplicationStatus.Interview, ApplicationStatus.Offer], 3],
  ])("stops a rejected application at the last stage it reached (%#)", (stages, step) => {
    expect(trackerOf(rejectedAfter(...stages))).toEqual({ activeStep: step, errorStep: step });
  });

  it("puts a rejected application with no timeline on the first step", () => {
    expect(trackerOf(application({ status: ApplicationStatus.Rejected }))).toEqual({ activeStep: 0, errorStep: 0 });
  });

  it("shows no error for an application that is not rejected", () => {
    expect(trackerOf(application({ status: ApplicationStatus.Interview }))).toEqual({
      activeStep: 2,
      errorStep: null,
    });
  });
});

describe("historyOf", () => {
  const interview = (overrides: Partial<ApplicationInterview> = {}): ApplicationInterview => ({
    id: "i1",
    round: "Technical interview",
    dateTime: "2026-10-05T10:00:00",
    mode: "Video",
    location: "https://meet.example.test/x",
    status: "Completed",
    ...overrides,
  });

  it("is only the application date for a new application", () => {
    expect(historyOf(application(), [])).toEqual([{ label: "Applied", date: "2026-09-01" }]);
  });

  it("shows a shortlisted application as applied, then its current stage with the date it changed", () => {
    const entries = historyOf(
      application({ status: ApplicationStatus.Screening, updatedDate: "2026-09-04" }),
      [],
    );
    expect(entries.map((entry) => entry.label)).toEqual(["Applied", "Screening"]);
    expect(entries[1].date).toBe("2026-09-04");
  });

  it("dates screening by when the application last changed while it is at the interview stage", () => {
    const entries = historyOf(application({ status: ApplicationStatus.Interview, updatedDate: "2026-09-20" }), []);
    expect(entries.map((entry) => entry.label)).toEqual(["Applied", "Screening"]);
    expect(entries[1]).toMatchObject({ date: "2026-09-20", detail: "Passed" });
  });

  it("lists the interviews by their own stage names, in the order they take place, with no separate interview line", () => {
    const entries = historyOf(application({ status: ApplicationStatus.Interview, updatedDate: "2026-10-06" }), [
      interview({ id: "i2", round: "Final round", dateTime: "2026-10-12T10:00:00", status: "Upcoming" }),
      interview({ round: "Initial Interview" }),
    ]);
    expect(entries.map((entry) => entry.label)).toEqual([
      "Applied",
      "Screening",
      "Initial Interview",
      "Final round",
    ]);
    expect(entries[2].withTime).toBe(true);
    expect(entries[3].detail).toBe("Interview · Upcoming");
  });

  it("ends with the final status and the date it was reached", () => {
    const hired = historyOf(application({ status: ApplicationStatus.OfferAccepted, updatedDate: "2026-10-20" }), [
      interview(),
    ]);
    expect(hired.map((entry) => entry.label)).toEqual(["Applied", "Screening", "Technical interview", "Offer Accepted"]);
    expect(hired[1].date).toBeNull();
    expect(hired[3].date).toBe("2026-10-20");
  });

  it("does not invent the stages a rejected application passed", () => {
    const entries = historyOf(application({ status: ApplicationStatus.Rejected, updatedDate: "2026-09-10" }), []);
    expect(entries.map((entry) => entry.label)).toEqual(["Applied", "Rejected"]);
    expect(entries[1].date).toBe("2026-09-10");
  });

  it("leaves the date out when the current status has none", () => {
    const entries = historyOf(application({ status: ApplicationStatus.Screening }), []);
    expect(entries[1].date).toBeNull();
  });
});

describe("defaultTabOf", () => {
  const withStatuses = (...statuses: ApplicationStatus[]) => statuses.map((status) => application({ status }));

  it("opens on offers when there is an offer, even with interviews and rejections", () => {
    expect(
      defaultTabOf(withStatuses(ApplicationStatus.Rejected, ApplicationStatus.Interview, ApplicationStatus.Offer)),
    ).toBe("offers");
    expect(defaultTabOf(withStatuses(ApplicationStatus.OfferAccepted))).toBe("offers");
  });

  it("opens on active for an interview when there is no offer", () => {
    expect(defaultTabOf(withStatuses(ApplicationStatus.Rejected, ApplicationStatus.Interview))).toBe("active");
  });

  it("opens on closed for a rejection when there is no offer or interview", () => {
    expect(defaultTabOf(withStatuses(ApplicationStatus.Applied, ApplicationStatus.Rejected))).toBe("closed");
  });

  it("opens on active for applications still in progress, and on all when there are none", () => {
    expect(defaultTabOf(withStatuses(ApplicationStatus.Applied, ApplicationStatus.Screening))).toBe("active");
    expect(defaultTabOf([])).toBe("all");
  });
});

describe("tabOf", () => {
  it.each([
    [ApplicationStatus.Applied, "active"],
    [ApplicationStatus.Screening, "active"],
    [ApplicationStatus.Interview, "active"],
    [ApplicationStatus.Offer, "offers"],
    [ApplicationStatus.OfferAccepted, "offers"],
    [ApplicationStatus.OfferDeclined, "closed"],
    [ApplicationStatus.Rejected, "closed"],
  ])("files %s under %s", (status, tab) => {
    expect(tabOf(application({ status }))).toBe(tab);
  });
});
