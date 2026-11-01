import { describe, expect, it, vi } from "vitest";

import { AxiosError } from "axios";

import { SnackMessage } from "@config/constant";
import { SESSION_EXPIRED_ERROR } from "@utils/profileService";
import { isSessionEnded, submitFailureMessage } from "@view/documents/documentFiles";

// The config reads window.config when it loads, which does not exist in these tests.
vi.mock("@config/config", () => ({
  AppConfig: { serviceUrls: { candidates: "", jobs: "", applications: "", documents: "" } },
  ServiceBaseUrl: "",
  UseMockProfile: false,
}));

const sessionEnded = () => Object.assign(new Error("Your session has ended."), { name: SESSION_EXPIRED_ERROR });

const refused = (status: number, message?: string) =>
  new AxiosError("refused", String(status), undefined, undefined, {
    status,
    statusText: "",
    headers: {},
    config: {} as never,
    data: message === undefined ? undefined : { message },
  });

describe("isSessionEnded", () => {
  it("tells an ended sign-in from any other failure", () => {
    expect(isSessionEnded(sessionEnded())).toBe(true);
    expect(isSessionEnded(new Error("boom"))).toBe(false);
    expect(isSessionEnded(refused(401))).toBe(false);
    expect(isSessionEnded("not an error")).toBe(false);
  });
});

describe("submitFailureMessage", () => {
  it("names an ended session, so retrying is not suggested", () => {
    expect(submitFailureMessage(sessionEnded())).toBe(SnackMessage.error.sessionEndedOnSubmit);
  });

  it("shows the reason the backend gives for a refused submission", () => {
    expect(submitFailureMessage(refused(403, "The time to change your documents has ended."))).toBe(
      "The time to change your documents has ended.",
    );
    expect(submitFailureMessage(refused(409, "Your documents are already being submitted."))).toBe(
      "Your documents are already being submitted.",
    );
  });

  it("falls back to a fixed text by status when the backend gives no reason", () => {
    expect(submitFailureMessage(refused(404))).toBe(SnackMessage.error.documentsNotAllowed);
    expect(submitFailureMessage(refused(413))).toBe(SnackMessage.error.documentsTooLarge);
    expect(submitFailureMessage(refused(429))).toBe(SnackMessage.error.documentsTooManyAttempts);
    expect(submitFailureMessage(refused(500))).toBe(SnackMessage.error.submitDocuments);
    expect(submitFailureMessage(new Error("network"))).toBe(SnackMessage.error.submitDocuments);
  });
});
