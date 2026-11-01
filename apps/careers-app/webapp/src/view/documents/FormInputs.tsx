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

import { Box, Button, MenuItem, Stack, TextField, Typography } from "@mui/material";
import { Trash2 } from "lucide-react";
import { useState } from "react";

import { COUNTRY_OPTIONS, splitE164, toE164 } from "@utils/phone";
import { fullRowSx } from "@utils/styles";

interface LabeledFieldProps {
  label: string;
  // Shows a * after the label.
  required?: boolean;
  // How many of the 12 parts of a row it takes on a wide screen; half a row when not given.
  span?: number;
  error?: string;
  helper?: string;
  children: React.ReactNode;
}

// A label above its input, with a hint and the problem with the input below it.
export const LabeledField = ({ label, required, span = 6, error, helper, children }: LabeledFieldProps) => (
  <Box sx={{ minWidth: 0, gridColumn: { md: `span ${span}` } }}>
    <Typography component="label" fontWeight={600} fontSize="0.95rem" color="text.primary" sx={{ display: "block", mb: 0.75 }}>
      {label}
      {required && (
        <Box component="span" aria-hidden sx={{ color: "error.main", ml: 0.5 }}>
          *
        </Box>
      )}
    </Typography>
    {children}
    {error ? (
      <Typography color="error" fontSize="0.8rem" mt={0.5}>
        {error}
      </Typography>
    ) : (
      helper && (
        <Typography color="text.secondary" fontSize="0.8rem" mt={0.5}>
          {helper}
        </Typography>
      )
    )}
  </Box>
);

// The rounded, tinted look of the inputs.
const inputSx = { "& .MuiOutlinedInput-root": { borderRadius: "10px", bgcolor: "action.hover" } } as const;

interface InputProps {
  label: string;
  value: string;
  onChange: (value: string) => void;
  required?: boolean;
  span?: number;
  error?: string;
  helper?: string;
  disabled: boolean;
}

export const TextInput = ({
  label,
  value,
  onChange,
  required,
  span,
  error,
  helper,
  disabled,
  type,
  placeholder,
  multiline,
  digitsOnly,
}: InputProps & { type?: string; placeholder?: string; multiline?: boolean; digitsOnly?: boolean }) => (
  <LabeledField label={label} required={required} span={span} error={error} helper={helper}>
    <TextField
      fullWidth
      size="small"
      value={value}
      onChange={(event) => onChange(digitsOnly ? event.target.value.replace(/\D/g, "") : event.target.value)}
      error={Boolean(error)}
      disabled={disabled}
      type={type}
      placeholder={placeholder}
      multiline={multiline}
      minRows={multiline ? 2 : undefined}
      sx={inputSx}
      slotProps={{
        htmlInput: {
          "aria-label": label,
          "aria-required": required,
          ...(type === "date" ? { max: new Date().toISOString().slice(0, 10) } : {}),
          ...(digitsOnly ? { inputMode: "numeric" } : {}),
        },
      }}
    />
  </LabeledField>
);

export const SelectInput = ({
  label,
  value,
  onChange,
  required,
  span,
  error,
  helper,
  disabled,
  options,
}: InputProps & { options: string[] }) => (
  <LabeledField label={label} required={required} span={span} error={error} helper={helper}>
    <TextField
      select
      fullWidth
      size="small"
      value={value}
      onChange={(event) => onChange(event.target.value)}
      error={Boolean(error)}
      disabled={disabled}
      sx={inputSx}
      slotProps={{ htmlInput: { "aria-label": label, "aria-required": required } }}
    >
      {options.map((option) => (
        <MenuItem key={option} value={option}>
          {option}
        </MenuItem>
      ))}
    </TextField>
  </LabeledField>
);

// The number in the format the backend accepts, or an empty text until both parts are filled in.
const phoneOf = (countryIso: string, national: string) => {
  const dialCode = COUNTRY_OPTIONS.find((option) => option.iso === countryIso)?.dialCode ?? "";
  return dialCode && national ? toE164(dialCode, national) : "";
};

// A country code to choose and the digits of the number. It starts from the number it is given and is remade by its
// key when a different number is loaded.
export const PhoneInput = ({
  label,
  value,
  onChange,
  required,
  span,
  error,
  helper,
  disabled,
  defaultCountry,
}: InputProps & { defaultCountry: string }) => {
  const initial = splitE164(value);
  const [countryIso, setCountryIso] = useState(initial?.countryIso ?? defaultCountry);
  const [national, setNational] = useState(initial?.national ?? "");
  const change = (nextIso: string, nextNational: string) => {
    setCountryIso(nextIso);
    setNational(nextNational);
    onChange(phoneOf(nextIso, nextNational));
  };
  return (
    <LabeledField label={label} required={required} span={span} error={error} helper={helper}>
      <Box sx={{ display: "grid", gridTemplateColumns: "minmax(110px, 150px) 1fr", gap: 1 }}>
        <TextField
          select
          size="small"
          value={countryIso}
          onChange={(event) => change(event.target.value, national)}
          error={Boolean(error)}
          disabled={disabled}
          sx={inputSx}
          slotProps={{
            htmlInput: { "aria-label": `${label} country code` },
            select: {
              displayEmpty: true,
              MenuProps: { slotProps: { paper: { sx: { maxHeight: 320 } } } },
              renderValue: (iso) => COUNTRY_OPTIONS.find((option) => option.iso === iso)?.dialCode ?? "Code",
            },
          }}
        >
          {COUNTRY_OPTIONS.map((option) => (
            <MenuItem key={option.iso} value={option.iso}>
              {option.name} ({option.dialCode})
            </MenuItem>
          ))}
        </TextField>
        <TextField
          size="small"
          value={national}
          onChange={(event) => change(countryIso, event.target.value.replace(/\D/g, "").slice(0, 15))}
          error={Boolean(error)}
          disabled={disabled}
          sx={inputSx}
          slotProps={{ htmlInput: { inputMode: "numeric", "aria-label": label, "aria-required": required } }}
        />
      </Box>
    </LabeledField>
  );
};

interface SectionProps {
  // Left out for the first group, which continues from the top of the form.
  title?: string;
  note?: string;
  children: React.ReactNode;
}

// A group of inputs, two to a row on a wide screen, with a title when it has one.
export const Section = ({ title, note, children }: SectionProps) => (
  <Box sx={{ p: 3, borderTop: "1px solid", borderColor: "divider", "&:first-of-type": { borderTop: 0 } }}>
    {title && (
      <Typography fontWeight={700} fontSize="1rem" color="text.primary">
        {title}
      </Typography>
    )}
    {note && (
      <Typography fontSize="0.85rem" color="text.secondary" mt={0.25}>
        {note}
      </Typography>
    )}
    <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", md: "repeat(12, 1fr)" }, gap: 2.5, mt: title || note ? 2 : 0 }}>
      {children}
    </Box>
  </Box>
);

// A person in a list, with a title and a button to remove them.
export const ListItem = ({
  title,
  onRemove,
  canRemove,
  disabled,
  children,
}: {
  title: string;
  onRemove: () => void;
  canRemove: boolean;
  disabled: boolean;
  children: React.ReactNode;
}) => (
  <Box sx={{ ...fullRowSx, p: 2, border: "1px solid", borderColor: "divider", borderRadius: "10px" }}>
    <Stack direction="row" alignItems="center" justifyContent="space-between" mb={1.5}>
      <Typography fontWeight={600} fontSize="0.9rem" color="text.primary">
        {title}
      </Typography>
      {canRemove && (
        <Button size="small" startIcon={<Trash2 size={14} />} onClick={onRemove} disabled={disabled} sx={{ fontWeight: 600 }}>
          Remove
        </Button>
      )}
    </Stack>
    <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", md: "repeat(12, 1fr)" }, gap: 2.5 }}>{children}</Box>
  </Box>
);
