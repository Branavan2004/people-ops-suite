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

export type NormalizedInternStatus = "active" | "ended" | "not_started" | "unknown";

export function normalizeStatus(rawStatus: unknown): NormalizedInternStatus {
  const status = String(rawStatus || "").trim().toLowerCase();

  if (status === "in progress" || status === "active" || status === "extended") return "active";
  if (status === "ended" || status === "completed" || status === "resigned" || status === "terminated") return "ended";
  if (status === "not started") return "not_started";
  return "unknown";
}

export function getStatusDisplay(rawStatus: unknown): { label: string; colorKey: NormalizedInternStatus } {
  const normalized = normalizeStatus(rawStatus);

  if (normalized === "active") {
    const label = String(rawStatus || "").trim().toLowerCase() === "extended" ? "Extended" : "In Progress";
    return { label, colorKey: "active" };
  }
  if (normalized === "ended") {
    return { label: "Ended", colorKey: "ended" };
  }
  if (normalized === "not_started") {
    return { label: "Not Started", colorKey: "not_started" };
  }
  return { label: rawStatus ? String(rawStatus).trim() : "Unknown", colorKey: "unknown" };
}

export function isEndedStatus(rawStatus: unknown): boolean {
  return normalizeStatus(rawStatus) === "ended";
}
