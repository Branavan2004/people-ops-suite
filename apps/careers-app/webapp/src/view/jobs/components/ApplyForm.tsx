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

import { ArrowForward } from "@mui/icons-material";
import {
  Box,
  Button,
  Checkbox,
  CircularProgress,
  FormControlLabel,
  Grid,
  InputAdornment,
  LinearProgress,
  MenuItem,
  Radio,
  RadioGroup,
  Stack,
  TextField,
  Typography,
} from "@mui/material";

import { useRef, useState } from "react";

import { COUNTRY_OPTIONS } from "@utils/phone";
import { pillButtonSx } from "@utils/styles";

export interface ApplyFormValues {
  firstName: string;
  lastName: string;
  email: string;
  countryIso: string;
  phone: string;
  address: string;
  university: string;
}

interface ApplyFormProps {
  form: ApplyFormValues;
  isInternship: boolean;
  onFormChange: (form: ApplyFormValues) => void;
  cvFile: File | null;
  onCvChosen: (file: File) => void;
  authorized: "yes" | "no" | "";
  onAuthorizedChange: (value: "yes" | "no") => void;
  consentData: boolean;
  onConsentDataChange: (checked: boolean) => void;
  consentChecks: boolean;
  onConsentChecksChange: (checked: boolean) => void;
  consentMarketing: boolean;
  onConsentMarketingChange: (checked: boolean) => void;
  canSubmit: boolean;
  submitting: boolean;
  onSubmit: () => void;
}

const MAX_CV_BYTES = 5 * 1024 * 1024;

const ApplyForm = ({
  form,
  isInternship,
  onFormChange,
  cvFile,
  onCvChosen,
  authorized,
  onAuthorizedChange,
  consentData,
  onConsentDataChange,
  consentChecks,
  onConsentChecksChange,
  consentMarketing,
  onConsentMarketingChange,
  canSubmit,
  submitting,
  onSubmit,
}: ApplyFormProps) => {
  const [cvError, setCvError] = useState<string | null>(null);
  const cvInputRef = useRef<HTMLInputElement>(null);

  return (
    <Stack gap={2.5}>
      <Grid container spacing={2}>
        <Grid size={{ xs: 12, sm: 6 }}>
          <TextField
            label="First Name"
            disabled={submitting}
            required
            fullWidth
            size="small"
            value={form.firstName}
            onChange={(e) => onFormChange({ ...form, firstName: e.target.value })}
          />
        </Grid>
        <Grid size={{ xs: 12, sm: 6 }}>
          <TextField
            label="Last Name"
            disabled={submitting}
            required
            fullWidth
            size="small"
            value={form.lastName}
            onChange={(e) => onFormChange({ ...form, lastName: e.target.value })}
          />
        </Grid>
        <Grid size={{ xs: 12, sm: 6 }}>
          <TextField
            label="Email"
            disabled={submitting}
            required
            fullWidth
            size="small"
            value={form.email}
            onChange={(e) => onFormChange({ ...form, email: e.target.value })}
          />
        </Grid>
        <Grid size={{ xs: 12, sm: 6 }}>
          <Stack direction="row" gap={1.5}>
            <TextField
              select
              label="Country Code"
              disabled={submitting}
              required
              size="small"
              sx={{ flex: "0 0 40%", minWidth: 0 }}
              value={form.countryIso}
              onChange={(e) => onFormChange({ ...form, countryIso: e.target.value })}
              slotProps={{
                select: {
                  MenuProps: { slotProps: { paper: { sx: { maxHeight: 320 } } } },
                  renderValue: (iso) => COUNTRY_OPTIONS.find((o) => o.iso === iso)?.dialCode ?? "",
                },
              }}
            >
              {COUNTRY_OPTIONS.map((o) => (
                <MenuItem key={o.iso} value={o.iso}>
                  {o.name} ({o.dialCode})
                </MenuItem>
              ))}
            </TextField>
            <TextField
              label="Phone"
              disabled={submitting}
              required
              size="small"
              sx={{ flex: 1, minWidth: 0 }}
              value={form.phone}
              onChange={(e) => onFormChange({ ...form, phone: e.target.value.replace(/\D/g, "").slice(0, 15) })}
              slotProps={{ htmlInput: { inputMode: "numeric" } }}
            />
          </Stack>
        </Grid>
        <Grid size={{ xs: 12, sm: 6 }}>
          {isInternship ? (
            <TextField
              label="University"
              disabled={submitting}
              required
              fullWidth
              size="small"
              value={form.university}
              onChange={(e) => onFormChange({ ...form, university: e.target.value })}
            />
          ) : (
            <TextField
              label="Address"
              disabled={submitting}
              required
              fullWidth
              size="small"
              value={form.address}
              onChange={(e) => onFormChange({ ...form, address: e.target.value })}
            />
          )}
        </Grid>
        <Grid size={{ xs: 12, sm: 6 }}>
          <input
            ref={cvInputRef}
            type="file"
            accept="application/pdf"
            hidden
            onChange={(e) => {
              const file = e.target.files?.[0];
              e.target.value = "";
              if (!file) return;
              if (file.type !== "application/pdf") {
                setCvError("Only PDF files are accepted.");
                return;
              }
              if (file.size > MAX_CV_BYTES) {
                setCvError("File must be 5MB or smaller.");
                return;
              }
              setCvError(null);
              onCvChosen(file);
            }}
          />
          <TextField
            label="Upload CV (PDF only / 5MB)"
            required
            fullWidth
            size="small"
            disabled={submitting}
            value={cvFile?.name ?? ""}
            placeholder="No file chosen"
            error={!!cvError}
            helperText={cvError}
            onClick={() => cvInputRef.current?.click()}
            slotProps={{
              inputLabel: { shrink: true },
              htmlInput: { readOnly: true, style: { cursor: "pointer" } },
              input: {
                startAdornment: (
                  <InputAdornment position="start" sx={{ mr: 1 }}>
                    <Button
                      size="small"
                      variant="outlined"
                      disabled={submitting}
                      sx={{ borderRadius: "6px", whiteSpace: "nowrap", py: 0, px: 1, minWidth: 0, fontSize: "0.8rem" }}
                    >
                      Choose file
                    </Button>
                  </InputAdornment>
                ),
              },
            }}
          />
        </Grid>
      </Grid>

      <Stack direction="row" alignItems="center" flexWrap="wrap" columnGap={2}>
        <Typography fontSize="0.9rem" fontWeight={600}>
          Do you have authorization to work in selected job location? *
        </Typography>
        <RadioGroup row value={authorized} onChange={(e) => onAuthorizedChange(e.target.value as "yes" | "no")}>
          <FormControlLabel value="yes" control={<Radio size="small" disabled={submitting} />} label="Yes" />
          <FormControlLabel value="no" control={<Radio size="small" disabled={submitting} />} label="No" />
        </RadioGroup>
      </Stack>

      <Stack gap={1}>
        <FormControlLabel
          control={<Checkbox
              size="small"
              disabled={submitting}
              checked={consentData}
              onChange={(e) => onConsentDataChange(e.target.checked)}
            />}
          label={
            <Typography fontSize="0.9rem">
              Yes, I give WSO2 permission to use my personal data for recruitment purposes only. *
            </Typography>
          }
        />
        <FormControlLabel
          control={
            <Checkbox
              size="small"
              disabled={submitting}
              checked={consentChecks}
              onChange={(e) => onConsentChecksChange(e.target.checked)}
            />
          }
          label={
            <Typography fontSize="0.9rem">
              I give WSO2 permission to assess my suitability for employment and to conduct independent reference
              checks and verify the information I provided, beyond what is on my resume. I understand that these
              checks will occur in accordance with applicable data protection laws, and that I may withdraw my consent
              at any time. *
            </Typography>
          }
        />
        <FormControlLabel
          control={
            <Checkbox
              size="small"
              disabled={submitting}
              checked={consentMarketing}
              onChange={(e) => onConsentMarketingChange(e.target.checked)}
            />
          }
          label={
            <Typography fontSize="0.9rem">
              I would like to receive emails from WSO2 to learn about new releases, security announcements, and other
              updates.
            </Typography>
          }
        />
      </Stack>

      <Button
        variant="contained"
        size="large"
        disabled={!canSubmit || submitting}
        onClick={onSubmit}
        startIcon={submitting ? <CircularProgress size={18} color="inherit" /> : undefined}
        endIcon={submitting ? undefined : <ArrowForward />}
        sx={{ ...pillButtonSx, alignSelf: "flex-start", px: 5 }}
      >
        {submitting ? "Submitting..." : "Submit"}
      </Button>

      {submitting && (
        <Box role="status" aria-live="polite">
          <LinearProgress sx={{ borderRadius: "999px", mb: 1 }} />
          <Typography fontSize="0.9rem" color="text.secondary">
            Sending your application and CV. This can take a few seconds, so please keep this page open.
          </Typography>
        </Box>
      )}
    </Stack>
  );
};

export default ApplyForm;
