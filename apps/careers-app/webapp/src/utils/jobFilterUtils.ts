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

import { Job } from "@/types/types";

type JobAddress = Pick<Job, "id" | "title" | "country">;

// Turns text into lower-case words joined by dashes.
const slugOf = (text: string) =>
  text
    .normalize("NFKD")
    .replace(/\p{M}/gu, "")
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, "-")
    .replace(/^-+|-+$/g, "");

// The readable part of a job's address: its title and countries.
export const jobSlug = (job: JobAddress): string =>
  [slugOf(job.title), ...job.country.map(slugOf)].filter(Boolean).join("-");

// The address part that marks a link made to open a job in a new tab or from a share.
const ARRIVAL_PARAM = "from";

// The page address of a job. `from` marks a link that is allowed to open the job page directly.
export const jobPath = (job: JobAddress, from?: "list" | "share"): string => {
  const slug = jobSlug(job);
  const path = slug ? `/jobs/${job.id}/${slug}` : `/jobs/${job.id}`;
  return from ? `${path}?${ARRIVAL_PARAM}=${from}` : path;
};

// Whether an address carries the mark that lets a job page open directly.
export const opensDirectly = (search: string): boolean => new URLSearchParams(search).has(ARRIVAL_PARAM);

// The query of an address without the arrival mark; every other parameter is kept.
export const withoutArrivalMark = (search: string): string => {
  const params = new URLSearchParams(search);
  params.delete(ARRIVAL_PARAM);
  const rest = params.toString();
  return rest ? `?${rest}` : "";
};

// The links that share a job on each network, pointing at its readable address on the given site.
export const jobShareLinks = (job: JobAddress, origin: string) => {
  const url = encodeURIComponent(`${origin}${jobPath(job, "share")}`);
  return [
    {
      network: "facebook",
      label: "Share with your friends on Facebook",
      href: `https://www.facebook.com/share.php?u=${url}`,
    },
    {
      network: "x",
      label: "Share with your friends on X",
      href: `https://twitter.com/intent/tweet?url=${url}`,
    },
    {
      network: "linkedin",
      label: "Share with your friends on LinkedIn",
      href: `https://www.linkedin.com/sharing/share-offsite/?url=${url}`,
    },
  ] as const;
};

// Selections within one filter combine with OR; an empty selection matches every job. The results list and the
// per-option counts share these predicates.

export const matchesSearch = (job: Job, search: string): boolean => {
  const term = search.toLowerCase();
  return !term || job.title.toLowerCase().includes(term) || job.team.toLowerCase().includes(term);
};

export const matchesJobType = (job: Job, jobType: string): boolean => !jobType || job.jobType === jobType;

export const matchesTeam = (job: Job, teams: string[]): boolean => teams.length === 0 || teams.includes(job.team);

// Office locations are compared to a job's countries by case-insensitive substring in either direction.
export const matchesLocation = (job: Job, locations: string[]): boolean =>
  locations.length === 0 ||
  job.country.some((c) =>
    locations.some((loc) => c.toLowerCase().includes(loc.toLowerCase()) || loc.toLowerCase().includes(c.toLowerCase())),
  );
