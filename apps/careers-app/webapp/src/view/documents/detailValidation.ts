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

import type {
  CandidateProfile,
  Dependant,
  DocumentRequirements,
  EmergencyContact,
  PersonalDetails,
} from "@/types/types";
import { isValidEmail } from "@utils/email";
import { isValidE164 } from "@utils/phone";

// The choices the form offers, which the backend supplies.
export type FormOptions = Pick<
  DocumentRequirements,
  "tshirtSizes" | "titles" | "genders" | "civilStatuses" | "dependantRelationships" | "maxDependants" | "maxEmergencyContacts"
>;

// The problems with the details, by field; a field inside a list is named after its place in it.
export type DetailErrors = Record<string, string>;

export const emptyContact = (): EmergencyContact => ({ name: "", relationship: "", address: "", mobileNumber: "", landNumber: "" });

export const emptyDependant = (): Dependant => ({ relationship: "", name: "", dateOfBirth: "", idNumber: "" });

// A form with nothing filled in, and the two emergency contacts that are asked for.
export const emptyDetails = (): PersonalDetails => ({
  title: "",
  firstName: "",
  surname: "",
  fullName: "",
  preferredName: "",
  initials: "",
  nameWithInitials: "",
  gender: "",
  dateOfBirth: "",
  idNumber: "",
  civilStatus: "",
  tshirtSize: "",
  homeAddress: "",
  temporaryAddress: "",
  mobileNumber: "",
  landNumber: "",
  personalEmail: "",
  businessInterest: "",
  dependants: [],
  emergencyContacts: [emptyContact(), emptyContact()],
  bank: { bank: "", branch: "", accountNumber: "" },
  highestQualification: "",
  university: "",
  githubUserId: "",
});

// Fills the empty fields from what the application holds; the preferred name and the full name are left to the
// candidate.
export const detailsFromProfile = (current: PersonalDetails, profile: CandidateProfile): PersonalDetails => {
  return {
    ...current,
    firstName: current.firstName || profile.firstName,
    surname: current.surname || profile.lastName,
    gender: current.gender || profile.gender,
    personalEmail: current.personalEmail || profile.personalEmail,
    mobileNumber: current.mobileNumber || (isValidE164(profile.contactNo) ? profile.contactNo : ""),
    // An internship application is stored with "N/A" as its address, which is not a home address.
    homeAddress: current.homeAddress || (profile.address && profile.address !== "N/A" ? profile.address : ""),
    university: current.university || (profile.university ?? ""),
  };
};

export const YES_NO = ["Yes", "No"];

const ID_NUMBER = /^[A-Za-z0-9][A-Za-z0-9 /-]{3,29}$/;
const ACCOUNT_NUMBER = /^[0-9]{5,20}$/;
const GITHUB_USER = /^[A-Za-z0-9-]{1,39}$/;

// A phone number without the spaces and hyphens people type in it.
const compactPhone = (phone: string) => phone.replace(/[\s-]/g, "");

// Whether the text is a real date, written yyyy-mm-dd, that is not in the future and not before the given year.
const isPastDate = (text: string, earliestYear: number) => {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(text)) return false;
  const date = new Date(`${text}T00:00:00`);
  return !Number.isNaN(date.getTime()) && date <= new Date() && date.getFullYear() >= earliestYear;
};

// The problems with the details, by field; empty when every detail is fine.
export const detailErrorsOf = (details: PersonalDetails, options: FormOptions): DetailErrors => {
  const errors: DetailErrors = {};
  const need = (key: string, value: string, message: string) => {
    if (!value.trim()) errors[key] = message;
  };
  const oneOf = (key: string, value: string, choices: string[], message: string) => {
    if (!choices.includes(value)) errors[key] = message;
  };
  const phone = (key: string, value: string, required: boolean) => {
    if (!value.trim()) {
      if (required) errors[key] = "Choose the country code and enter the number.";
    } else if (!isValidE164(compactPhone(value))) {
      errors[key] = "Choose the country code and enter a valid number.";
    }
  };

  oneOf("title", details.title, options.titles, "Choose your title.");
  need("firstName", details.firstName, "Enter your first name.");
  need("surname", details.surname, "Enter your last name.");
  need("fullName", details.fullName, "Enter your full name as on your identity document.");
  need("preferredName", details.preferredName, "Enter the name you like to be called.");
  need("initials", details.initials, "Enter your initials.");
  need("nameWithInitials", details.nameWithInitials, "Enter your name with initials.");
  oneOf("gender", details.gender, options.genders, "Choose your gender.");
  if (!isPastDate(details.dateOfBirth, 1940)) errors.dateOfBirth = "Enter a valid date of birth.";
  if (!ID_NUMBER.test(details.idNumber.trim())) errors.idNumber = "Enter a valid identity document number.";
  oneOf("civilStatus", details.civilStatus, options.civilStatuses, "Choose your civil status.");
  oneOf("businessInterest", details.businessInterest, YES_NO, "Choose Yes or No.");
  oneOf("tshirtSize", details.tshirtSize, options.tshirtSizes, "Choose your T-shirt size.");
  need("homeAddress", details.homeAddress, "Enter your residential address.");
  phone("mobileNumber", details.mobileNumber, true);
  phone("landNumber", details.landNumber, false);
  if (!isValidEmail(details.personalEmail)) errors.personalEmail = "Enter a valid email address.";

  details.dependants.forEach((dependant, index) => {
    const at = `dependants.${index}`;
    oneOf(`${at}.relationship`, dependant.relationship, options.dependantRelationships, "Choose the relationship.");
    need(`${at}.name`, dependant.name, "Enter the name.");
    if (!isPastDate(dependant.dateOfBirth, 1900)) errors[`${at}.dateOfBirth`] = "Enter a valid date of birth.";
    if (dependant.idNumber.trim() && !ID_NUMBER.test(dependant.idNumber.trim())) {
      errors[`${at}.idNumber`] = "Enter a valid identity document number, or leave it blank.";
    }
  });

  if (details.emergencyContacts.length < 2) errors.emergencyContacts = "Give at least two emergency contacts.";
  details.emergencyContacts.forEach((contact, index) => {
    const at = `emergencyContacts.${index}`;
    need(`${at}.name`, contact.name, "Enter the name.");
    need(`${at}.relationship`, contact.relationship, "Enter the relationship.");
    need(`${at}.address`, contact.address, "Enter the address.");
    phone(`${at}.mobileNumber`, contact.mobileNumber, true);
    phone(`${at}.landNumber`, contact.landNumber, false);
  });

  need("bank.bank", details.bank.bank, "Enter the bank.");
  need("bank.branch", details.bank.branch, "Enter the branch.");
  if (!ACCOUNT_NUMBER.test(details.bank.accountNumber.trim())) {
    errors["bank.accountNumber"] = "Enter the account number as digits only, including any zeros at the start.";
  }
  need("highestQualification", details.highestQualification, "Enter your highest qualification.");
  need("university", details.university, "Enter your university.");
  if (details.githubUserId.trim() && !GITHUB_USER.test(details.githubUserId.trim())) {
    errors.githubUserId = "Enter a valid GitHub user ID, or leave it blank.";
  }
  return errors;
};

// The details as titled lines for the last step. The account number is hidden but for its last digits.
export const summarySectionsOf = (d: PersonalDetails): { title: string; rows: [string, string][] }[] => [
  {
    title: "Your details",
    rows: [
      ["Title", d.title],
      ["First name", d.firstName],
      ["Last name", d.surname],
      ["Full name (as on identity document)", d.fullName],
      ["Preferred name", d.preferredName],
      ["Initials", d.initials],
      ["Name with initials", d.nameWithInitials],
      ["Gender", d.gender],
      ["Date of birth", d.dateOfBirth],
      ["Identity document number", d.idNumber],
      ["Civil status", d.civilStatus],
      ["T-shirt size", d.tshirtSize],
      ["Personal email", d.personalEmail],
      ["Mobile number", d.mobileNumber],
      ["Land number", d.landNumber || "None"],
      ["Residential address", d.homeAddress],
      ["Temporary address", d.temporaryAddress || "None"],
      ["University", d.university],
      ["Interest in any commercial or business pursuit", d.businessInterest],
    ],
  },
  {
    title: "Dependants",
    rows: d.dependants.length
      ? d.dependants.map((person, index): [string, string] => [
          `${index + 1}. ${person.relationship}`,
          [person.name, person.dateOfBirth, person.idNumber].filter(Boolean).join(" · "),
        ])
      : [["None", ""]],
  },
  {
    title: "Emergency contacts",
    rows: d.emergencyContacts.map((contact, index): [string, string] => [
      `${index + 1}. ${contact.name} (${contact.relationship})`,
      [contact.address, contact.mobileNumber, contact.landNumber].filter(Boolean).join(" · "),
    ]),
  },
  {
    title: "Bank and education",
    rows: [
      ["Bank", `${d.bank.bank}, ${d.bank.branch}`],
      ["Account number", d.bank.accountNumber ? `•••• ${d.bank.accountNumber.slice(-4)}` : ""],
      ["Highest qualification", d.highestQualification],
      ["GitHub user ID", d.githubUserId || "None"],
    ],
  },
];
