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

import { Box, Button, Stack, Typography } from "@mui/material";
import { Pencil, Plus } from "lucide-react";
import { useEffect, useState } from "react";

import type { Dependant, EmergencyContact, PersonalDetails } from "@/types/types";
import { splitE164 } from "@utils/phone";
import { fullRowSx as fullWidth, pillButtonSx } from "@utils/styles";
import {
  type DetailErrors,
  type FormOptions,
  YES_NO,
  emptyContact,
  emptyDependant,
} from "@view/documents/detailValidation";
import { LabeledField, ListItem, PhoneInput, Section, SelectInput, TextInput } from "@view/documents/FormInputs";

// The details that come from the application, and are listed rather than shown as inputs.
const APPLICATION_FIELDS = ["firstName", "surname", "gender", "mobileNumber", "university", "homeAddress"] as const;

interface PersonalDetailsFormProps {
  details: PersonalDetails;
  onChange: (next: PersonalDetails) => void;
  errors: DetailErrors;
  options: FormOptions;
  disabled: boolean;
}

// The details step: what the application already holds, listed first, then the rest of what HR keeps for every new
// employee. A * marks what is required.
const PersonalDetailsForm = ({ details, onChange, errors, options, disabled }: PersonalDetailsFormProps) => {
  // Raised when someone is removed from a list, so the inputs after them are remade.
  const [listVersion, setListVersion] = useState(0);
  // The details the application holds are listed, and opened for editing when one is missing, has a problem, or the
  // candidate asks to edit them.
  const [editingApplication, setEditingApplication] = useState(() => APPLICATION_FIELDS.some((key) => !details[key].trim()));
  useEffect(() => {
    if (APPLICATION_FIELDS.some((key) => errors[key])) setEditingApplication(true);
  }, [errors]);

  const update = (patch: Partial<PersonalDetails>) => onChange({ ...details, ...patch });
  const defaultCountry = splitE164(details.mobileNumber)?.countryIso ?? "";

  const setDependant = (index: number, patch: Partial<Dependant>) =>
    update({ dependants: details.dependants.map((item, at) => (at === index ? { ...item, ...patch } : item)) });
  const setContact = (index: number, patch: Partial<EmergencyContact>) =>
    update({ emergencyContacts: details.emergencyContacts.map((item, at) => (at === index ? { ...item, ...patch } : item)) });

  return (
    <Box>
      <Section>
        <SelectInput label="Title" required span={3} value={details.title} options={options.titles} onChange={(v) => update({ title: v })} error={errors.title} disabled={disabled} />
        <TextInput label="Full name (as on identity document)" required span={9} value={details.fullName} onChange={(v) => update({ fullName: v })} error={errors.fullName} disabled={disabled} />
        <TextInput label="Preferred name" required span={4} value={details.preferredName} onChange={(v) => update({ preferredName: v })} error={errors.preferredName} disabled={disabled} />
        <TextInput label="Initials" required span={3} value={details.initials} onChange={(v) => update({ initials: v })} error={errors.initials} disabled={disabled} />
        <TextInput label="Name with initials" required span={5} value={details.nameWithInitials} onChange={(v) => update({ nameWithInitials: v })} error={errors.nameWithInitials} disabled={disabled} />
        {editingApplication ? (
          <>
            <TextInput label="First name" required value={details.firstName} onChange={(v) => update({ firstName: v })} error={errors.firstName} disabled={disabled} />
            <TextInput label="Last name" required value={details.surname} onChange={(v) => update({ surname: v })} error={errors.surname} disabled={disabled} />
            <SelectInput label="Gender" required span={4} value={details.gender} options={options.genders} onChange={(v) => update({ gender: v })} error={errors.gender} disabled={disabled} />
            <PhoneInput
              label="Mobile number"
              required
              span={8}
              value={details.mobileNumber}
              onChange={(v) => update({ mobileNumber: v })}
              error={errors.mobileNumber}
              disabled={disabled}
              defaultCountry={defaultCountry}
            />
            <TextInput label="University" required value={details.university} onChange={(v) => update({ university: v })} error={errors.university} disabled={disabled} />
            <LabeledField label="Personal email" required>
              <Typography fontSize="0.95rem" color="text.primary" sx={{ wordBreak: "break-word", py: 0.75 }}>
                {details.personalEmail}
              </Typography>
            </LabeledField>
            <Box sx={fullWidth}>
              <TextInput label="Residential address" required value={details.homeAddress} onChange={(v) => update({ homeAddress: v })} error={errors.homeAddress} disabled={disabled} />
            </Box>
          </>
        ) : (
          <Stack direction="row" alignItems="flex-start" justifyContent="space-between" gap={2} sx={fullWidth}>
            <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", sm: "200px 1fr" }, rowGap: 1, columnGap: 2, minWidth: 0 }}>
              {(
                [
                  ["First name", details.firstName],
                  ["Last name", details.surname],
                  ["Gender", details.gender],
                  ["Personal email", details.personalEmail],
                  ["Mobile number", details.mobileNumber],
                  ["University", details.university],
                  ["Residential address", details.homeAddress],
                ] as [string, string][]
              ).map(([label, value]) => (
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
            <Button size="small" startIcon={<Pencil size={14} />} onClick={() => setEditingApplication(true)} disabled={disabled} sx={{ fontWeight: 600 }}>
              Edit
            </Button>
          </Stack>
        )}

        <TextInput label="Date of birth" required span={3} type="date" value={details.dateOfBirth} onChange={(v) => update({ dateOfBirth: v })} error={errors.dateOfBirth} disabled={disabled} />
        <TextInput label="Identity document number" required span={4} value={details.idNumber} onChange={(v) => update({ idNumber: v })} error={errors.idNumber} disabled={disabled} />
        <SelectInput label="Civil status" required span={3} value={details.civilStatus} options={options.civilStatuses} onChange={(v) => update({ civilStatus: v })} error={errors.civilStatus} disabled={disabled} />
        <SelectInput label="T-shirt size" required span={2} value={details.tshirtSize} options={options.tshirtSizes} onChange={(v) => update({ tshirtSize: v })} error={errors.tshirtSize} disabled={disabled} />
        <PhoneInput
          label="Land number"
          value={details.landNumber}
          onChange={(v) => update({ landNumber: v })}
          error={errors.landNumber}
          disabled={disabled}
          defaultCountry={defaultCountry}
        />
        <SelectInput
          label="Interest in any commercial or business pursuit"
          required
          span={3}
          value={details.businessInterest}
          options={YES_NO}
          onChange={(v) => update({ businessInterest: v })}
          error={errors.businessInterest}
          disabled={disabled}
        />
        <TextInput label="Temporary address" span={12} value={details.temporaryAddress} onChange={(v) => update({ temporaryAddress: v })} disabled={disabled} />
      </Section>

      <Section title="Dependants" note="For the insurance policy, for permanent employees. If you are single, add your parents.">
        {details.dependants.map((person, index) => (
          <ListItem
            key={`${listVersion}-dependant-${index}`}
            title={`Dependant ${index + 1}`}
            canRemove
            disabled={disabled}
            onRemove={() => {
              update({ dependants: details.dependants.filter((_, at) => at !== index) });
              setListVersion((current) => current + 1);
            }}
          >
            <SelectInput label="Relationship" required span={4} value={person.relationship} options={options.dependantRelationships} onChange={(v) => setDependant(index, { relationship: v })} error={errors[`dependants.${index}.relationship`]} disabled={disabled} />
            <TextInput label="Name" required span={8} value={person.name} onChange={(v) => setDependant(index, { name: v })} error={errors[`dependants.${index}.name`]} disabled={disabled} />
            <TextInput label="Date of birth" required span={4} type="date" value={person.dateOfBirth} onChange={(v) => setDependant(index, { dateOfBirth: v })} error={errors[`dependants.${index}.dateOfBirth`]} disabled={disabled} />
            <TextInput label="NIC or passport number" span={8} value={person.idNumber} onChange={(v) => setDependant(index, { idNumber: v })} error={errors[`dependants.${index}.idNumber`]} disabled={disabled} />
          </ListItem>
        ))}
        {details.dependants.length < options.maxDependants && (
          <Box sx={fullWidth}>
            <Button
              startIcon={<Plus size={16} />}
              variant="outlined"
              disabled={disabled}
              onClick={() => update({ dependants: [...details.dependants, emptyDependant()] })}
              sx={pillButtonSx}
            >
              Add a dependant
            </Button>
          </Box>
        )}
      </Section>

      <Section title="Emergency contacts" note="Give at least two people we can call in an emergency.">
        {errors.emergencyContacts && (
          <Typography color="error" fontSize="0.85rem" sx={fullWidth}>
            {errors.emergencyContacts}
          </Typography>
        )}
        {details.emergencyContacts.map((contact, index) => (
          <ListItem
            key={`${listVersion}-contact-${index}`}
            title={`Emergency contact ${index + 1}`}
            canRemove={details.emergencyContacts.length > 2}
            disabled={disabled}
            onRemove={() => {
              update({ emergencyContacts: details.emergencyContacts.filter((_, at) => at !== index) });
              setListVersion((current) => current + 1);
            }}
          >
            <TextInput label="Name" required value={contact.name} onChange={(v) => setContact(index, { name: v })} error={errors[`emergencyContacts.${index}.name`]} disabled={disabled} />
            <TextInput label="Relationship" required value={contact.relationship} onChange={(v) => setContact(index, { relationship: v })} error={errors[`emergencyContacts.${index}.relationship`]} disabled={disabled} />
            <Box sx={fullWidth}>
              <TextInput label="Address" required value={contact.address} onChange={(v) => setContact(index, { address: v })} error={errors[`emergencyContacts.${index}.address`]} disabled={disabled} />
            </Box>
            <PhoneInput label="Mobile number" required value={contact.mobileNumber} onChange={(v) => setContact(index, { mobileNumber: v })} error={errors[`emergencyContacts.${index}.mobileNumber`]} disabled={disabled} defaultCountry={defaultCountry} />
            <PhoneInput label="Land number" value={contact.landNumber} onChange={(v) => setContact(index, { landNumber: v })} error={errors[`emergencyContacts.${index}.landNumber`]} disabled={disabled} defaultCountry={defaultCountry} />
          </ListItem>
        ))}
        {details.emergencyContacts.length < options.maxEmergencyContacts && (
          <Box sx={fullWidth}>
            <Button
              startIcon={<Plus size={16} />}
              variant="outlined"
              disabled={disabled}
              onClick={() => update({ emergencyContacts: [...details.emergencyContacts, emptyContact()] })}
              sx={pillButtonSx}
            >
              Add an emergency contact
            </Button>
          </Box>
        )}
      </Section>

      <Section title="Bank details" note="The account your salary should be paid into.">
        <TextInput label="Bank" required span={4} value={details.bank.bank} onChange={(v) => update({ bank: { ...details.bank, bank: v } })} error={errors["bank.bank"]} disabled={disabled} />
        <TextInput label="Branch" required span={4} value={details.bank.branch} onChange={(v) => update({ bank: { ...details.bank, branch: v } })} error={errors["bank.branch"]} disabled={disabled} />
        <TextInput
          label="Account number"
          required
          span={4}
          value={details.bank.accountNumber}
          onChange={(v) => update({ bank: { ...details.bank, accountNumber: v } })}
          error={errors["bank.accountNumber"]}
          digitsOnly
          disabled={disabled}
        />
      </Section>

      <Section title="Education and work">
        <TextInput
          label="Highest qualification"
          required
          span={8}
          value={details.highestQualification}
          onChange={(v) => update({ highestQualification: v })}
          error={errors.highestQualification}
          disabled={disabled}
        />
        <TextInput
          label="GitHub user ID"
          span={4}
          value={details.githubUserId}
          onChange={(v) => update({ githubUserId: v })}
          error={errors.githubUserId}
          disabled={disabled}
        />
      </Section>
    </Box>
  );
};

export default PersonalDetailsForm;
