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

import dayjs from "dayjs";
import { useFormikContext } from "formik";
import { useCallback, useEffect, useMemo, useState } from "react";

import { CreateEmployeeFormValues } from "@/types/types";
import { useAppSelector } from "@slices/store";
import {
  AUTO_ID_EMPLOYMENT_TYPES,
  FIXED_TERM_EMPLOYMENT_TYPE,
  PROBATION_EMPLOYMENT_TYPE,
} from "@view/employees/onboarding/singleOnboarding/steps/JobInfo";

/**
 * Employment-type driven rules for the profile's General Information editor, carried
 * over from the onboarding wizard's Job Info step.
 *
 * Derives which employment type is selected, whether an agreement end date applies,
 * and the probation end date implied by the work location's configured probation
 * period.
 *
 * Auto-computation only ever fills an EMPTY probation date. A value already on the
 * record is left alone: it may have been corrected by hand, and silently recomputing
 * it when an admin edits an unrelated field in the same section would discard that
 * correction without telling anyone.
 */
export const useEmploymentRules = () => {
  const { values, setFieldValue } =
    useFormikContext<CreateEmployeeFormValues>();
  const { companies, employmentTypes } = useAppSelector(
    (state) => state.organization,
  );

  const [internshipDurationMonths, setInternshipDurationMonths] =
    useState<number>(0);

  const selectedType = useMemo(
    () => employmentTypes.find((et) => et.id === values.employmentTypeId),
    [employmentTypes, values.employmentTypeId],
  );

  const typeName = selectedType?.name?.trim() ?? "";

  const isPermanent = useMemo(() => /^permanent$/i.test(typeName), [typeName]);

  const isProbationType = useMemo(
    () => (typeName ? PROBATION_EMPLOYMENT_TYPE.test(typeName) : false),
    [typeName],
  );

  const isFixedTerm = useMemo(
    () => (typeName ? FIXED_TERM_EMPLOYMENT_TYPE.test(typeName) : false),
    [typeName],
  );

  const showAgreementEndDate = useMemo(() => {
    if (!typeName) return false;
    return /\b(internship|consult(ancy|ant)?|fixed\s+term)\b/.test(
      typeName.toLowerCase(),
    );
  }, [typeName]);

  // Only active types are selectable, but keep the employee's current type even if it
  // has since been deactivated — otherwise the dropdown would render blank.
  const selectableEmploymentTypes = useMemo(
    () =>
      employmentTypes.filter(
        (t) => t.isActive || t.id === values.employmentTypeId,
      ),
    [employmentTypes, values.employmentTypeId],
  );

  const [addProbationEndDate, setAddProbationEndDate] = useState(false);

  useEffect(() => {
    if (values.probationEndDate) setAddProbationEndDate(true);
  }, [values.probationEndDate]);

  const matchedProbationLocation = useMemo(() => {
    if (!values.companyId || !values.workLocation || !companies.length) {
      return null;
    }
    const company = companies.find((c) => c.id === values.companyId);
    return (
      company?.allowedLocations?.find(
        (item) =>
          item.location.trim().toUpperCase() ===
          values.workLocation.trim().toUpperCase(),
      ) ?? null
    );
  }, [values.companyId, values.workLocation, companies]);

  useEffect(() => {
    // isPermanent/isProbationType both read false against an empty list, which would
    // clear a loaded value before the preservation guard below gets a chance to run.
    if (employmentTypes.length === 0) return;

    // Other types only carry a probation end date once it is added explicitly.
    if (!isPermanent && !isProbationType && !addProbationEndDate) return;

    // The record already has a date — never overwrite it.
    if (values.probationEndDate) return;

    if (!values.startDate || !matchedProbationLocation) return;

    const probationMonths = matchedProbationLocation.probationPeriod ?? null;
    if (probationMonths === null) return;

    const startDate = dayjs(values.startDate);
    if (!startDate.isValid()) return;

    setFieldValue(
      "probationEndDate",
      startDate.add(probationMonths, "month").format("YYYY-MM-DD"),
    );
    // values.probationEndDate is read above as the preservation guard but deliberately
    // excluded from the deps — including it re-fires this on every manual edit and
    // immediately overwrites what the admin just typed.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [
    employmentTypes.length,
    isPermanent,
    isProbationType,
    addProbationEndDate,
    values.startDate,
    matchedProbationLocation,
    setFieldValue,
  ]);

  const isInternship = useMemo(
    () => /^internship$/i.test(typeName),
    [typeName],
  );

  /** An internship's agreement end date is derived from its duration in months. */
  const computeAgreementEndDate = useCallback(
    (startDate: string | null, months: number) => {
      if (!startDate || !months) return null;
      try {
        return dayjs(startDate).add(months, "month").format("YYYY-MM-DD");
      } catch {
        return null;
      }
    },
    [],
  );

  const handleInternshipDurationChange = useCallback(
    (months: number) => {
      setInternshipDurationMonths(months);
      const computed = computeAgreementEndDate(
        values.startDate ?? null,
        months,
      );
      if (computed) setFieldValue("agreementEndDate", computed);
    },
    [setFieldValue, values.startDate, computeAgreementEndDate],
  );

  const handleEmploymentTypeChange = useCallback(
    (newEmploymentTypeId: number) => {
      setFieldValue("employmentTypeId", newEmploymentTypeId);

      const next = employmentTypes.find((e) => e.id === newEmploymentTypeId);
      const nextName = next?.name?.trim() ?? "";

      const isNewInternship = /^internship$/i.test(nextName);
      const isAutoIdType = AUTO_ID_EMPLOYMENT_TYPES.test(nextName);

      const isNewPermanentOrProbation =
        /^permanent$/i.test(nextName) ||
        PROBATION_EMPLOYMENT_TYPE.test(nextName);

      if (!isNewPermanentOrProbation || (!isPermanent && !isProbationType)) {
        setFieldValue("probationEndDate", null);
        setAddProbationEndDate(false);
      }

      if (isNewInternship) {
        // Six months is the wizard's default internship term; the agreement end date
        // follows from it immediately so the field is never left blank.
        setInternshipDurationMonths(6);
        setFieldValue("employeeId", "");
        const computed = computeAgreementEndDate(values.startDate ?? null, 6);
        if (computed) setFieldValue("agreementEndDate", computed);
        return;
      }

      setInternshipDurationMonths(0);

      // Types whose IDs are generated rather than assigned drop any manually entered
      // ID, so one typed for a fixed-term contract cannot survive a switch away.
      if (isAutoIdType) setFieldValue("employeeId", "");

      // Types that carry no agreement end date drop any value the previous type had,
      // so a stale date can't be submitted against a type that doesn't use one.
      const nextShowsAgreement =
        /\b(internship|consult(ancy|ant)?|fixed\s+term)\b/.test(
          nextName.toLowerCase(),
        );
      if (!nextShowsAgreement) {
        setFieldValue("agreementEndDate", null);
      }
    },
    [
      setFieldValue,
      employmentTypes,
      values.startDate,
      computeAgreementEndDate,
      isPermanent,
      isProbationType,
    ],
  );

  return {
    addProbationEndDate,
    setAddProbationEndDate,
    isPermanent,
    isProbationType,
    isFixedTerm,
    isInternship,
    internshipDurationMonths,
    handleInternshipDurationChange,
    showAgreementEndDate,
    selectableEmploymentTypes,
    matchedProbationLocation,
    handleEmploymentTypeChange,
  };
};
