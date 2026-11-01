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

function formatNameFromEmail(email: string): string {
  const local = email.split("@")[0];
  return local.replace(/[._]+/g, " ").replace(/\b\w/g, (c) => c.toUpperCase());
}

// Lower-cased, trimmed email, the key of the lookup built by buildEmailLookup.
export const emailKey = (email: string | null | undefined): string => (email || "").trim().toLowerCase();

// Built once per employee list, so resolving a name is a map lookup rather
// than a scan of every employee.
export function buildEmailLookup<T extends { email: string }>(employees: T[]): Map<string, T> {
  const lookup = new Map<string, T>();
  employees.forEach((e) => {
    const key = emailKey(e.email);
    if (key && !lookup.has(key)) lookup.set(key, e);
  });
  return lookup;
}

// Reporting Manager / Mentor fields in the source data only ever store an
// email address, never a display name. This resolves the actual person's
// name from the employee lookup, falling back to a formatted guess from the
// email's local-part if no match is found.
export function resolveNameByEmail(
  email: string | null | undefined,
  lookup: Map<string, { name: string }>
): string {
  const key = emailKey(email);
  if (!key) return "—";
  return lookup.get(key)?.name || formatNameFromEmail(key);
}
