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

import { Box, Button, MenuItem, Stack, TextField, Typography } from "@wso2/oxygen-ui";
import { ChevronDown, ChevronUp, CircleAlert, CircleCheck, Clock, Trash2 } from "@wso2/oxygen-ui-icons-react";
import { useEffect, useState } from "react";

import { COUNTRY_OPTIONS, phoneFrom, phoneInputStart } from "@utils/phone";
import { fullRowSx } from "@utils/styles";
import type { DocumentStatus } from "@view/documents/documentFiles";

// The icon and colour of each document status.
const STATUS_LOOK = {
  Complete: { Icon: CircleCheck, color: "#059669" },
  Pending: { Icon: Clock, color: "#6B7280" },
  "Action needed": { Icon: CircleAlert, color: "#EF4444" },
} as const;

// A document's status: an icon with the status beside it, a tick when it is complete. The label can be more specific
// than the status, such as "Already uploaded" for a complete document.
export const StatusTag = ({ status, label = status }: { status: DocumentStatus; label?: string }) => {
  const { Icon, color } = STATUS_LOOK[status];
  return (
    <Stack direction="row" alignItems="center" gap={0.5} sx={{ color, flexShrink: 0 }}>
      <Icon size={16} aria-hidden />
      <Typography component="span" fontSize="0.8rem" fontWeight={600} color="inherit">
        {label}
      </Typography>
    </Stack>
  );
};

interface FieldProps {
  // How many of the 12 parts of a row it takes on a wide screen; half a row when not given.
  span?: number;
  error?: string;
  helper?: string;
  children: React.ReactNode;
}

// An input in its place in the grid, with a hint and the problem with the input below it. The label is inside the
// input itself, as in the apply form.
export const Field = ({ span = 6, error, helper, children }: FieldProps) => (
  <Box sx={{ minWidth: 0, gridColumn: { md: `span ${span}` } }}>
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

// The same, with the chosen value as tall as the text typed in an input, so a select is as tall as the other boxes and
// its label sits in the middle. The Oxygen UI theme pads a select's value more and lifts its label by 7px; both are
// undone here, with !important because the theme's rules are more specific.
const selectSx = {
  ...inputSx,
  "& .MuiSelect-select": {
    minHeight: "unset",
    height: "1.4375em",
    lineHeight: "1.4375em",
    paddingTop: "8.5px !important",
    paddingBottom: "8.5px !important",
  },
  "& .MuiInputLabel-root:not(.MuiInputLabel-shrink)": { top: "0 !important" },
} as const;

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
  <Field span={span} error={error} helper={helper}>
    <TextField
      fullWidth
      size="small"
      label={required ? `${label} *` : label}
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
        // A date shows its format inside the box, so its label stays at the top.
        ...(type === "date" ? { inputLabel: { shrink: true } } : {}),
      }}
    />
  </Field>
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
  <Field span={span} error={error} helper={helper}>
    <TextField
      select
      fullWidth
      size="small"
      label={required ? `${label} *` : label}
      value={value}
      onChange={(event) => onChange(event.target.value)}
      error={Boolean(error)}
      disabled={disabled}
      sx={selectSx}
      slotProps={{ htmlInput: { "aria-label": label, "aria-required": required } }}
    >
      {options.map((option) => (
        <MenuItem key={option} value={option}>
          {option}
        </MenuItem>
      ))}
    </TextField>
  </Field>
);

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
  const initial = phoneInputStart(value, defaultCountry);
  const [countryIso, setCountryIso] = useState(initial.countryIso);
  const [national, setNational] = useState(initial.national);
  const change = (nextIso: string, nextNational: string) => {
    setCountryIso(nextIso);
    setNational(nextNational);
    onChange(phoneFrom(nextIso, nextNational));
  };
  // A default country that arrives once the input is on the page (the profile loads while the form is open) is taken
  // only while none has been chosen, so a choice is never replaced and the digits typed so far are kept.
  useEffect(() => {
    if (countryIso || !defaultCountry) return;
    setCountryIso(defaultCountry);
    if (national) onChange(phoneFrom(defaultCountry, national));
  }, [countryIso, defaultCountry, national, onChange]);
  return (
    <Field span={span} error={error} helper={helper}>
      <Box sx={{ display: "grid", gridTemplateColumns: "minmax(96px, 112px) 1fr", gap: 1 }}>
        <TextField
          select
          size="small"
          label={required ? "Code *" : "Code"}
          value={countryIso}
          onChange={(event) => change(event.target.value, national)}
          error={Boolean(error)}
          disabled={disabled}
          sx={selectSx}
          slotProps={{
            htmlInput: { "aria-label": `${label} country code` },
            select: {
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
          label={required ? `${label} *` : label}
          value={national}
          onChange={(event) => change(countryIso, event.target.value.replace(/\D/g, "").slice(0, 15))}
          error={Boolean(error)}
          disabled={disabled}
          sx={inputSx}
          slotProps={{ htmlInput: { inputMode: "numeric", "aria-label": label, "aria-required": required } }}
        />
      </Box>
    </Field>
  );
};

interface SectionProps {
  // Left out for the first group, which continues from the top of the form.
  title?: string;
  note?: string;
  // Makes the group foldable: its title row gets a View or Hide button, and a folded group shows only the summary.
  fold?: { open: boolean; onToggle: () => void; summary: string };
  children: React.ReactNode;
}

// A group of inputs, two to a row on a wide screen, with a title when it has one.
export const Section = ({ title, note, fold, children }: SectionProps) => (
  <Box sx={{ p: 3, borderTop: "1px solid", borderColor: "divider", "&:first-of-type": { borderTop: 0 } }}>
    <Stack direction="row" alignItems="flex-start" justifyContent="space-between" gap={2}>
      <Box sx={{ minWidth: 0 }}>
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
        {fold && !fold.open && (
          <Typography fontSize="0.85rem" color="text.secondary" mt={0.75}>
            {fold.summary}
          </Typography>
        )}
      </Box>
      {fold && (
        <Button
          size="small"
          onClick={fold.onToggle}
          aria-expanded={fold.open}
          endIcon={fold.open ? <ChevronUp size={16} /> : <ChevronDown size={16} />}
          sx={{ fontWeight: 600, flexShrink: 0 }}
        >
          {fold.open ? "Hide" : "View"}
        </Button>
      )}
    </Stack>
    {(!fold || fold.open) && (
      <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", md: "repeat(12, 1fr)" }, gap: 2.5, mt: title || note ? 2 : 0 }}>
        {children}
      </Box>
    )}
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
