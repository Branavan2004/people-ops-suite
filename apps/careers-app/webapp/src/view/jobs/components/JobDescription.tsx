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

import DOMPurify from "dompurify";

import { Box } from "@mui/material";

import { offerCardStyles, proseStyles } from "@view/jobs/jobDetailStyles";

interface JobDescriptionProps {
  mainContent: string | null;
  taskInformation: string | null;
  additionalContent: string | null;
}

// The three description sections come from the vacancy API as HTML, so each is sanitized before it is rendered.
const JobDescription = ({ mainContent, taskInformation, additionalContent }: JobDescriptionProps) => (
  <>
    {mainContent && <Box sx={proseStyles} dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(mainContent) }} />}
    {taskInformation && (
      <Box sx={proseStyles} dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(taskInformation) }} />
    )}
    {additionalContent && (
      <Box sx={offerCardStyles} dangerouslySetInnerHTML={{ __html: DOMPurify.sanitize(additionalContent) }} />
    )}
  </>
);

export default JobDescription;
