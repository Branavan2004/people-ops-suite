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

import { Chip } from "@wso2/oxygen-ui";

import { ApplicationStatus } from "@config/constant";

interface Props {
  status: ApplicationStatus;
  size?: "small" | "medium";
}

// The text color of each status; its chip is tinted with the same color.
const statusConfig: Record<ApplicationStatus, { color: string }> = {
  [ApplicationStatus.Applied]: { color: "#3B82F6" },
  [ApplicationStatus.Screening]: { color: "#F59E0B" },
  [ApplicationStatus.Interview]: { color: "#8B5CF6" },
  [ApplicationStatus.Selected]: { color: "#14B8A6" },
  [ApplicationStatus.Offer]: { color: "#10B981" },
  [ApplicationStatus.OfferAccepted]: { color: "#059669" },
  [ApplicationStatus.OfferDeclined]: { color: "#6B7280" },
  [ApplicationStatus.OfferExpired]: { color: "#6B7280" },
  [ApplicationStatus.Rejected]: { color: "#EF4444" },
};

// A status this version does not know, for example one the backend added later, shows in grey and does not break the page.
const UNKNOWN_STATUS = { color: "#6B7280" };

const ApplicationStatusBadge = ({ status, size = "small" }: Props) => {
  const config = statusConfig[status] ?? UNKNOWN_STATUS;
  return (
    <Chip
      label={status}
      size={size}
      sx={{
        fontWeight: 600,
        fontSize: "11px",
        color: config.color,
        backgroundColor: `${config.color}22`,
        border: `1px solid ${config.color}30`,
        borderRadius: "6px",
      }}
    />
  );
};

export default ApplicationStatusBadge;
