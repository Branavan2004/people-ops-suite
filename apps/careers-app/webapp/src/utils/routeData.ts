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

// A piece of store data that a route reads.
export type RouteNeed = "jobs" | "orgStructure" | "jobDetails" | "applications" | "profile";

// Set as `handle` on a route in app/AppHandler.tsx, so what a route needs is declared on the route itself.
export interface RouteHandle {
  needs?: RouteNeed[];
}

// The store data the open route needs.
export type RouteData = Record<RouteNeed, boolean>;

// The data needed by the matched routes, read from their handles. A route without a handle needs nothing.
export function dataNeededBy(matches: { handle?: unknown }[]): RouteData {
  const needed: RouteData = {
    jobs: false,
    orgStructure: false,
    jobDetails: false,
    applications: false,
    profile: false,
  };
  for (const match of matches) {
    for (const need of (match.handle as RouteHandle | undefined)?.needs ?? []) needed[need] = true;
  }
  return needed;
}
