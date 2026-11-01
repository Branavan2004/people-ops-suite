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

import { Box, Checkbox, Chip, FormControlLabel, Link, Stack, Typography } from "@mui/material";

import type { DocumentRequirements, PersonalDetails } from "@/types/types";
import Callout from "@component/common/Callout";
import { summarySectionsOf } from "@view/documents/detailValidation";
import {
  DOCUMENTS_STEP,
  PHOTOS_STEP,
  STATUS_COLORS,
  formatSize,
  statusOf,
} from "@view/documents/documentFiles";

interface ReviewStepProps {
  requirements: DocumentRequirements;
  details: PersonalDetails;
  files: Record<string, File>;
  sentKeys: string[];
  detailsReady: boolean;
  totalBytes: number;
  tooLarge: boolean;
  declared: boolean;
  submitting: boolean;
  onDeclaredChange: (declared: boolean) => void;
  onShowDetailProblems: () => void;
  onGoTo: (step: number) => void;
}

// The last step: what will be sent, the declaration and what is still missing.
const ReviewStep = ({
  requirements,
  details,
  files,
  sentKeys,
  detailsReady,
  totalBytes,
  tooLarge,
  declared,
  submitting,
  onDeclaredChange,
  onShowDetailProblems,
  onGoTo,
}: ReviewStepProps) => {
  // A document counts as sent when a file was chosen now or one was sent earlier.
  const isSent = (key: string) => Boolean(files[key]) || sentKeys.includes(key);
  const missingDocuments = requirements.documents.filter((document) => document.required && !isSent(document.key));
  return (
    <>
      {(!detailsReady || missingDocuments.length > 0) && (
        <Box sx={{ px: 3, pt: 3 }}>
          <Callout tone="danger">
            <Typography fontWeight={700} fontSize="0.95rem" color="text.primary">
              Submit unlocks when everything is complete
            </Typography>
            {!detailsReady && (
              <Typography fontSize="0.9rem" color="text.primary">
                Some personal details are missing.{" "}
                <Link component="button" type="button" onClick={onShowDetailProblems} sx={{ verticalAlign: "baseline" }}>
                  Go to personal details
                </Link>
              </Typography>
            )}
            {missingDocuments.length > 0 && (
              <Box>
                <Typography fontSize="0.9rem" color="text.primary" mb={0.75}>
                  Still to add:
                </Typography>
                <Stack direction="row" flexWrap="wrap" gap={1}>
                  {missingDocuments.map((document) => (
                    <Chip
                      key={document.key}
                      label={document.label}
                      variant="outlined"
                      clickable
                      onClick={() => onGoTo(document.group === "photos" ? PHOTOS_STEP : DOCUMENTS_STEP)}
                    />
                  ))}
                </Stack>
              </Box>
            )}
          </Callout>
        </Box>
      )}
      {summarySectionsOf(details).map((section) => (
        <Box key={section.title} sx={{ p: 3, borderTop: "1px solid", borderColor: "divider" }}>
          <Typography fontWeight={700} fontSize="0.95rem" color="text.primary" mb={1.5}>
            {section.title}
          </Typography>
          <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", sm: "260px 1fr" }, rowGap: 1, columnGap: 2 }}>
            {section.rows.map(([label, value]) => (
              <Box key={label} sx={{ display: "contents" }}>
                <Typography fontSize="0.9rem" color="text.secondary">
                  {label}
                </Typography>
                <Typography fontSize="0.9rem" color="text.primary" sx={{ wordBreak: "break-word" }}>
                  {value}
                </Typography>
              </Box>
            ))}
          </Box>
        </Box>
      ))}

      <Box sx={{ px: 3, pb: 2, borderTop: "1px solid", borderColor: "divider" }}>
        <Typography fontWeight={700} fontSize="0.95rem" color="text.primary" mt={2} mb={1}>
          Your documents and photos
        </Typography>
        {requirements.documents.map((document) => (
          <Stack key={document.key} direction="row" justifyContent="space-between" gap={2} sx={{ py: 0.5 }}>
            <Typography fontSize="0.9rem" color="text.primary">
              {document.label}
            </Typography>
            <Chip
              size="small"
              variant="outlined"
              color={STATUS_COLORS[statusOf(isSent(document.key), undefined)]}
              label={
                files[document.key]
                  ? "Complete"
                  : sentKeys.includes(document.key)
                    ? "Already uploaded"
                    : document.required
                      ? "Pending"
                      : "Not sent"
              }
            />
          </Stack>
        ))}
        <Typography fontSize="0.85rem" color={tooLarge ? "error" : "text.secondary"} mt={1}>
          {formatSize(totalBytes)} of {formatSize(requirements.maxTotalBytes)}
        </Typography>
      </Box>

      <Box sx={{ px: 3, pt: 2, borderTop: "1px solid", borderColor: "divider" }}>
        <FormControlLabel
          control={<Checkbox checked={declared} onChange={(event) => onDeclaredChange(event.target.checked)} disabled={submitting} />}
          label="I declare that these documents are genuine and the details in them are correct."
          sx={{ alignItems: "flex-start", "& .MuiTypography-root": { fontSize: "0.9rem", pt: 0.75 } }}
        />
      </Box>
    </>
  );
};

export default ReviewStep;
