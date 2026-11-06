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

import AttachFileRoundedIcon from "@mui/icons-material/AttachFileRounded";
import UploadFileRoundedIcon from "@mui/icons-material/UploadFileRounded";
import { Button, Stack, Typography, useTheme } from "@mui/material";

import { ChangeEvent, useRef } from "react";

interface SickNoteUploadProps {
  file: File | null;
  problem: string;
  maxBytes: number;
  contentTypes: string[];
  onChange: (file: File | null) => void;
}

export default function SickNoteUpload({
  file,
  problem,
  maxBytes,
  contentTypes,
  onChange,
}: SickNoteUploadProps) {
  const theme = useTheme();
  const inputRef = useRef<HTMLInputElement>(null);

  const handleChange = (event: ChangeEvent<HTMLInputElement>) => {
    onChange(event.target.files?.[0] ?? null);
    // Allow picking the same file again after it was rejected or removed.
    event.target.value = "";
  };

  return (
    <Stack gap={1.5}>
      <Stack direction="row" alignItems="center" gap={1}>
        <AttachFileRoundedIcon sx={{ fontSize: 20, color: theme.palette.primary.main }} />
        <Typography variant="h6" sx={{ color: theme.palette.customText.primary.p1.active }}>
          Sick Note
        </Typography>
      </Stack>
      <Typography variant="body2" sx={{ color: theme.palette.customText.primary.p3.active }}>
        A sick note is required for sick leave. Upload a PDF, JPG or PNG file of up to{" "}
        {(maxBytes / (1024 * 1024)).toFixed(1)} MB.
      </Typography>
      <Stack direction="row" alignItems="center" gap={1.5} flexWrap="wrap">
        <input
          ref={inputRef}
          type="file"
          hidden
          accept={contentTypes.join(",")}
          onChange={handleChange}
          data-testid="sick-note-input"
        />
        <Button
          variant="outlined"
          startIcon={<UploadFileRoundedIcon />}
          onClick={() => inputRef.current?.click()}
          sx={{ borderRadius: "10px", textTransform: "none", fontWeight: 600 }}
        >
          {file ? "Change file" : "Choose file"}
        </Button>
        {file && (
          <Typography variant="body2" sx={{ color: theme.palette.customText.primary.p2.active }}>
            {file.name}
          </Typography>
        )}
        {file && (
          <Button size="small" onClick={() => onChange(null)} sx={{ textTransform: "none" }}>
            Remove
          </Button>
        )}
      </Stack>
      {problem && (
        <Typography variant="caption" role="alert" sx={{ color: theme.palette.error.main }}>
          {problem}
        </Typography>
      )}
    </Stack>
  );
}
