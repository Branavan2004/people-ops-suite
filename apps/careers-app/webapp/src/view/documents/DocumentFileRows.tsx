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

import { Box, Button, Chip, Link, Stack, Typography } from "@mui/material";
import { styled } from "@mui/material/styles";
import { FileUp, Trash2 } from "lucide-react";

import type { DocumentRequirement } from "@/types/types";
import { pillButtonSx } from "@utils/styles";
import { STATUS_COLORS, extensionsOf, formatSize, formatsText, statusOf } from "@view/documents/documentFiles";

// A file input that stays in the tab order and the accessibility tree while being invisible; the button around it shows
// its focus.
const VisuallyHiddenInput = styled("input")({
  clip: "rect(0 0 0 0)",
  clipPath: "inset(50%)",
  height: 1,
  overflow: "hidden",
  position: "absolute",
  bottom: 0,
  left: 0,
  whiteSpace: "nowrap",
  width: 1,
});

// The hint, with any web address in it shown as a link that opens in a new tab.
const hintContent = (hint: string) =>
  hint.split(/(https:\/\/\S+[^\s.,;])/).map((part, index) =>
    part.startsWith("https://") ? (
      <Link key={index} href={part} target="_blank" rel="noopener noreferrer">
        {part.replace("https://", "")}
      </Link>
    ) : (
      part
    ),
  );

interface DocumentFileRowsProps {
  documents: DocumentRequirement[];
  files: Record<string, File>;
  sentKeys: string[];
  problems: Record<string, string>;
  submitting: boolean;
  onChoose: (key: string, file: File | undefined) => void;
  onRemove: (key: string) => void;
}

// The rows of the documents or photos step: one per document, each with its status.
const DocumentFileRows = ({ documents, files, sentKeys, problems, submitting, onChoose, onRemove }: DocumentFileRowsProps) => (
  <Stack divider={<Box sx={{ borderTop: "1px solid", borderColor: "divider" }} />}>
    {documents.map((document) => {
      const file = files[document.key];
      const sentEarlier = !file && sentKeys.includes(document.key);
      const documentStatus = statusOf(Boolean(file) || sentKeys.includes(document.key), problems[document.key]);
      return (
        <Stack
          key={document.key}
          direction={{ xs: "column", sm: "row" }}
          alignItems={{ xs: "flex-start", sm: "center" }}
          justifyContent="space-between"
          gap={1.5}
          sx={{ px: 3, py: 2 }}
        >
          <Box sx={{ minWidth: 0 }}>
            <Stack direction="row" alignItems="center" gap={1} flexWrap="wrap">
              <Typography fontWeight={600} fontSize="0.95rem" color="text.primary">
                {document.label}
              </Typography>
              <Chip size="small" variant="outlined" color={STATUS_COLORS[documentStatus]} label={documentStatus} />
              {!document.required && <Chip size="small" variant="outlined" label="Optional" />}
            </Stack>
            <Typography fontSize="0.8rem" color="text.secondary">
              {formatsText(document.types)}
              {document.hint && <> · {hintContent(document.hint)}</>}
            </Typography>
            {file && (
              <Typography fontSize="0.85rem" color="text.secondary" sx={{ wordBreak: "break-all" }}>
                {file.name} · {formatSize(file.size)}
              </Typography>
            )}
            {problems[document.key] && (
              <Typography fontSize="0.85rem" color="error">
                {problems[document.key]}
              </Typography>
            )}
          </Box>

          {file ? (
            <Button
              startIcon={<Trash2 size={16} />}
              onClick={() => onRemove(document.key)}
              disabled={submitting}
              sx={{ fontWeight: 600 }}
            >
              Remove
            </Button>
          ) : (
            <Button
              component="label"
              role={undefined}
              tabIndex={-1}
              variant="outlined"
              startIcon={<FileUp size={16} />}
              disabled={submitting}
              sx={{ ...pillButtonSx, "&:focus-within": { outline: "2px solid", outlineOffset: 2, outlineColor: "primary.main" } }}
            >
              {sentEarlier ? "Replace" : "Upload"}
              <VisuallyHiddenInput
                type="file"
                disabled={submitting}
                aria-label={`${sentEarlier ? "Replace" : "Upload"} ${document.label}`}
                accept={extensionsOf(document.types)
                  .map((extension) => `.${extension}`)
                  .join(",")}
                onChange={(event) => {
                  onChoose(document.key, event.target.files?.[0]);
                  // Lets the same file be chosen again after it was removed.
                  event.target.value = "";
                }}
              />
            </Button>
          )}
        </Stack>
      );
    })}
  </Stack>
);

export default DocumentFileRows;
