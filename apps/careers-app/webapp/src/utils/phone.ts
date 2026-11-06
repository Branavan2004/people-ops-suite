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

import { getCountries, getCountryCallingCode, parsePhoneNumberFromString } from "libphonenumber-js";

// Every country with its dialing code, keyed by ISO region so countries sharing a code stay distinct.
const regionNames = new Intl.DisplayNames(["en"], { type: "region" });
export const COUNTRY_OPTIONS = getCountries()
  .map((iso) => ({ iso, name: regionNames.of(iso) ?? iso, dialCode: `+${getCountryCallingCode(iso)}` }))
  .sort((a, b) => a.name.localeCompare(b.name));

// The format the backend accepts: the dialing code, then only the digits typed, without a leading trunk "0".
export const toE164 = (dialCode: string, input: string): string =>
  `${dialCode}${input.replace(/\D/g, "").replace(/^0+/, "")}`;

// The number from a chosen country and the digits typed, in that format. Digits typed before a country is chosen are
// returned as typed, so the check of the number asks for the country instead of the digits being dropped; the text is
// empty only while nothing was typed.
export const phoneFrom = (countryIso: string, national: string): string => {
  if (!national) return "";
  const dialCode = COUNTRY_OPTIONS.find((option) => option.iso === countryIso)?.dialCode ?? "";
  return dialCode ? toE164(dialCode, national) : national;
};

// Splits a number in that format into its country and the digits after the dialing code, or null when it cannot be read.
export const splitE164 = (value: string): { countryIso: string; national: string } | null => {
  const parsed = parsePhoneNumberFromString(value);
  if (!parsed) return null;
  const countryIso =
    parsed.country ?? getCountries().find((iso) => getCountryCallingCode(iso) === parsed.countryCallingCode);
  return countryIso ? { countryIso, national: parsed.nationalNumber } : null;
};

// What a phone input shows for a stored value: the country and digits of a number in that format, or, for digits kept
// without a country (see phoneFrom), the digits with no country so the default can be taken, or nothing.
export const phoneInputStart = (value: string, defaultCountry: string): { countryIso: string; national: string } => {
  const split = splitE164(value);
  if (split) return split;
  return /^\d+$/.test(value) ? { countryIso: "", national: value } : { countryIso: defaultCountry, national: "" };
};

// Whether a value is in that format: "+", then 2 to 15 digits, not starting with 0.
export const isValidE164 = (value: string): boolean => /^\+[1-9]\d{1,14}$/.test(value);
