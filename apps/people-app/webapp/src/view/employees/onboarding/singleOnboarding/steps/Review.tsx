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

import React, { useMemo } from "react";
import { Box, Grid, Typography, useTheme, alpha } from "@mui/material";
import { useFormikContext } from "formik";
import { useAppSelector } from "@slices/store";
import { CreateEmployeeFormValues } from "@root/src/types/types";
import { formatDate } from "@utils/utils";
import PeopleChip, {
  PeopleChipList,
} from "@component/PeopleChip/PeopleChip";
import {
  PersonOutline,
  CakeOutlined,
  ContactPhoneOutlined,
  HomeOutlined,
  BadgeOutlined,
  WorkOutline,
  LocationOnOutlined,
  EventOutlined,
  SupervisorAccountOutlined,
  PhoneOutlined,
  WidgetsOutlined,
} from "@mui/icons-material";

const REVIEW_ICONS = {
  person: <PersonOutline fontSize="small" />,
  cake: <CakeOutlined fontSize="small" />,
  contact: <ContactPhoneOutlined fontSize="small" />,
  home: <HomeOutlined fontSize="small" />,
  badge: <BadgeOutlined fontSize="small" />,
  work: <WorkOutline fontSize="small" />,
  location: <LocationOnOutlined fontSize="small" />,
  event: <EventOutlined fontSize="small" />,
  supervisor: <SupervisorAccountOutlined fontSize="small" />,
  phone: <PhoneOutlined fontSize="small" />,
  other: <WidgetsOutlined fontSize="small" />,
};

const SectionHeader = React.memo(
  ({ icon, title }: { icon: React.ReactNode; title: string }) => {
    const theme = useTheme();
    return (
      <Box sx={{ display: "flex", alignItems: "center", gap: 1.5, mb: 2 }}>
        <Box
          sx={{
            display: "flex",
            alignItems: "center",
            justifyContent: "center",
            width: 36,
            height: 36,
            borderRadius: 1.5,
            background: `linear-gradient(135deg, ${alpha(
              theme.palette.secondary.contrastText,
              0.15,
            )}, ${alpha(theme.palette.secondary.contrastText, 0.08)})`,
            color: theme.palette.secondary.contrastText,
          }}
        >
          {icon}
        </Box>
        <Typography
          variant="h6"
          fontWeight={600}
          fontSize="1rem"
          sx={{ color: alpha(theme.palette.text.primary, 0.6) }}
        >
          {title}
        </Typography>
      </Box>
    );
  },
);

const ReviewField = React.memo(
  ({
    label,
    value,
  }: {
    label: string;
    value: React.ReactNode | string | null | undefined;
  }) => {
    const theme = useTheme();
    return (
      <Box>
        <Typography
          variant="subtitle2"
          sx={{
            color: theme.palette.text.primary,
            fontWeight: 600,
            fontSize: "0.8125rem",
            mb: 0.75,
            letterSpacing: "0.01em",
          }}
        >
          {label}
        </Typography>
        <Typography
          component="div"
          variant="body2"
          sx={{
            color: alpha(theme.palette.text.secondary, 0.85),
            fontWeight: 400,
            fontSize: "0.875rem",
            wordBreak: "break-word",
            lineHeight: 1.5,
          }}
        >
          {value || "—"}
        </Typography>
      </Box>
    );
  },
);

const MainSectionTitle = React.memo(({ title }: { title: string }) => {
  const theme = useTheme();
  return (
    <Box
      sx={{
        display: "flex",
        alignItems: "center",
        width: "100%",
        mb: 2.5,
        mt: 4,
      }}
    >
      <Typography
        variant="h5"
        sx={{
          mr: 2,
          whiteSpace: "nowrap",
          fontWeight: 600,
          color: theme.palette.text.primary,
        }}
      >
        {title}
      </Typography>
      <Box
        sx={{
          flexGrow: 1,
          height: "1.5px",
          backgroundColor: alpha(theme.palette.text.primary, 0.15),
        }}
      />
    </Box>
  );
});

interface ReviewStepProps {
  isEditMode: boolean;
}

export default function ReviewStep({ isEditMode }: ReviewStepProps) {
  const theme = useTheme();
  const { values } = useFormikContext<CreateEmployeeFormValues>();

  const {
    businessUnits,
    teams,
    subTeams,
    units,
    careerFunctions,
    designations,
    companies,
    offices,
    employmentTypes,
    houses,
  } = useAppSelector((s) => s.organization);

  const p = values.personalInfo ?? {};

  const sectionBoxSx = useMemo(
    () => ({
      boxShadow:
        theme.palette.mode === "dark"
          ? `0 1px 2px ${alpha(theme.palette.common.black, 0.3)}`
          : `0 1px 2px ${alpha(theme.palette.common.black, 0.06)}`,
      borderRadius: 2,
      p: 2.5,
      mb: 2,
      backgroundColor:
        theme.palette.mode === "dark"
          ? alpha(theme.palette.common.white, 0.02)
          : alpha(theme.palette.common.black, 0.01),
    }),
    [theme],
  );

  // Map IDs to Names for display
  const mappedNames = useMemo(
    () => ({
      businessUnit:
        businessUnits.find((b) => b.id === values.businessUnitId)?.name || null,
      team: teams.find((t) => t.id === values.teamId)?.name || null,
      subTeam: subTeams.find((st) => st.id === values.subTeamId)?.name || null,
      unit: units.find((u) => u.id === values.unitId)?.name || null,
      designation:
        designations.find((cf) => cf.id === values.designationId)
          ?.designation || null,
      careerFunction:
        careerFunctions.find((cf) => cf.id === values.careerFunctionId)
          ?.careerFunction || null,
      company: companies.find((c) => c.id === values.companyId)?.name || null,
      office: offices.find((o) => o.id === values.officeId)?.name || null,
      employmentType:
        employmentTypes.find((o) => o.id === values.employmentTypeId)?.name ||
        null,
      house: houses.find((h) => h.id === values.houseId)?.name || null,
    }),
    [
      businessUnits,
      teams,
      subTeams,
      units,
      designations,
      careerFunctions,
      companies,
      offices,
      employmentTypes,
      houses,
      values.businessUnitId,
      values.teamId,
      values.subTeamId,
      values.unitId,
      values.designationId,
      values.careerFunctionId,
      values.companyId,
      values.officeId,
      values.employmentTypeId,
      values.houseId,
    ],
  );

  return (
    <Box sx={{ width: "100%", px: 0 }}>
      <MainSectionTitle title="Personal Information" />

      {/* Identity */}
      <Box sx={sectionBoxSx}>
        <SectionHeader icon={REVIEW_ICONS.person} title="Identity" />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Title" value={p.title} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="First Name" value={p.firstName} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Last Name" value={p.lastName} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Full Name" value={p.fullName} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="NIC" value={p.nicOrPassport} />
          </Grid>
        </Grid>
      </Box>

      {/* Birth & Nationality */}
      <Box sx={sectionBoxSx}>
        <SectionHeader icon={REVIEW_ICONS.cake} title="Birth & Nationality" />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField
              label="Date of Birth"
              value={formatDate(p.dob)}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Gender" value={p.gender} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Nationality" value={p.nationality} />
          </Grid>
        </Grid>
      </Box>

      {/* Contact */}
      <Box sx={sectionBoxSx}>
        <SectionHeader icon={REVIEW_ICONS.contact} title="Contact" />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Personal Email" value={p.personalEmail} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Personal Phone" value={p.personalPhone} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Home Phone" value={p.residentNumber} />
          </Grid>
        </Grid>
      </Box>

      {/* Address */}
      <Box sx={sectionBoxSx}>
        <SectionHeader icon={REVIEW_ICONS.home} title="Address" />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Address Line 1" value={p.addressLine1} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Address Line 2" value={p.addressLine2} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="City" value={p.city} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="State / Province" value={p.stateOrProvince} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Postal Code" value={p.postalCode} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Country" value={p.country} />
          </Grid>
        </Grid>
      </Box>

      {/* Emergency Contacts */}
      {p.emergencyContacts && p.emergencyContacts.length > 0 && (
        <Box sx={sectionBoxSx}>
          <SectionHeader
            icon={REVIEW_ICONS.contact}
            title="Emergency Contacts"
          />
          {p.emergencyContacts.map((contact, index) => (
            <Box
              key={index}
              sx={{
                mb: 2,
                p: 2,
                borderRadius: 1.5,
                backgroundColor: alpha(theme.palette.background.paper, 0.5),
                border: `1px solid ${alpha(theme.palette.divider, 0.1)}`,
              }}
            >
              <Typography
                variant="subtitle1"
                sx={{
                  fontWeight: 600,
                  mb: 1,
                  color: theme.palette.text.primary,
                }}
              >
                Contact {index + 1}
              </Typography>
              <Grid container spacing={3}>
                <Grid item xs={12} sm={6} md={3}>
                  <ReviewField label="Name" value={contact.name} />
                </Grid>
                <Grid item xs={12} sm={6} md={3}>
                  <ReviewField
                    label="Relationship"
                    value={contact.relationship}
                  />
                </Grid>
                <Grid item xs={12} sm={6} md={3}>
                  <ReviewField label="Telephone" value={contact.telephone} />
                </Grid>
                <Grid item xs={12} sm={6} md={3}>
                  <ReviewField label="Mobile" value={contact.mobile} />
                </Grid>
              </Grid>
            </Box>
          ))}
        </Box>
      )}

      <MainSectionTitle title="Job Information" />

      {/* Identity (Work Email & EPF) */}
      <Box sx={sectionBoxSx}>
        <SectionHeader icon={REVIEW_ICONS.badge} title="Identity" />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField
              label="Work Email"
              value={
                values.workEmail?.trim() ||
                (isEditMode ? values.workEmail : "Not created yet — added later")
              }
            />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="EPF" value={values.epf} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField
              label="Secondary Job Title"
              value={values.secondaryJobTitle}
            />
          </Grid>
        </Grid>
      </Box>

      {/* Job & Team */}
      <Box sx={sectionBoxSx}>
        <SectionHeader icon={REVIEW_ICONS.work} title="Job & Team" />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField
              label="Business Unit"
              value={mappedNames.businessUnit}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Team" value={mappedNames.team} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Sub Team" value={mappedNames.subTeam} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Unit" value={mappedNames.unit} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField
              label="Career Function"
              value={mappedNames.careerFunction}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Designation" value={mappedNames.designation} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Job Role" value={values.jobRole} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField
              label="External Designation"
              value={values.externalDesignation}
            />
          </Grid>
        </Grid>
      </Box>

      {/* Location & Office */}
      <Box sx={sectionBoxSx}>
        <SectionHeader icon={REVIEW_ICONS.location} title="Location & Office" />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Company" value={mappedNames.company} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Office" value={mappedNames.office} />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField label="Work Location" value={values.workLocation} />
          </Grid>
        </Grid>
      </Box>

      {/* Dates & Status */}
      <Box sx={sectionBoxSx}>
        <SectionHeader icon={REVIEW_ICONS.event} title="Dates & Status" />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField
              label="Employment Type"
              value={mappedNames.employmentType}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField
              label="Start Date"
              value={formatDate(values.startDate)}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField
              label="Probation End Date"
              value={formatDate(values.probationEndDate)}
            />
          </Grid>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField
              label="Agreement End Date"
              value={formatDate(values.agreementEndDate)}
            />
          </Grid>
          {/^internship$/i.test(mappedNames.employmentType?.trim() ?? "") ? (
            <Grid item xs={12} sm={6} md={4}>
              <ReviewField label="University" value={values.university || null} />
            </Grid>
          ) : null}
        </Grid>
      </Box>

      {/* Lead & Reports */}
      <Box sx={sectionBoxSx}>
        <SectionHeader
          icon={REVIEW_ICONS.supervisor}
          title="Lead & Reports"
        />
        <Grid container spacing={3}>
          <Grid item xs={12} sm={6} md={4}>
            <ReviewField
              label="Lead"
              value={
                values.managerEmail ? (
                  <PeopleChip email={values.managerEmail} />
                ) : null
              }
            />
          </Grid>

          <Grid item xs={12} sm={6} md={4}>
            <ReviewField
              label="Additional Leads"
              value={
                values.additionalManagerEmail?.length ? (
                  <PeopleChipList emails={values.additionalManagerEmail} />
                ) : (
                  "—"
                )
              }
            />
          </Grid>
        </Grid>
      </Box>

      {/* House */}
      {isEditMode ? (
        <Box sx={sectionBoxSx}>
          <SectionHeader icon={REVIEW_ICONS.other} title="Other" />
          <Grid container spacing={3}>
            <Grid item xs={12} sm={6} md={4}>
              <ReviewField label="House" value={mappedNames.house} />
            </Grid>
          </Grid>
        </Box>
      ) : null}
    </Box>
  );
}
