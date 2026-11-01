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

import {
  Avatar,
  Box,
  Button,
  Card,
  CardContent,
  InputAdornment,
  MenuItem,
  Stack,
  TextField,
  Typography,
} from "@mui/material";
import { GraduationCap, Mail, MapPin, Pencil, Phone, User } from "lucide-react";
import { useState } from "react";

import { type CandidateProfile, type EditableProfileFields, State } from "@/types/types";
import CenteredSpinner from "@component/common/CenteredSpinner";
import PageContainer from "@component/common/PageContainer";
import PageHeading from "@component/common/PageHeading";
import { BRAND_ORANGE, BRAND_TINT } from "@config/brand";
import { SnackMessage } from "@config/constant";
import { useAppAuthContext } from "@context/AuthContext";
import { loadProfile, profileFailed, updateProfile } from "@slices/careersSlice/careers";
import { enqueueSnackbarMessage } from "@slices/commonSlice/common";
import { RootState, useAppDispatch, useAppSelector } from "@slices/store";
import { isValidE164 } from "@utils/phone";
import { cardSx, pillButtonSx } from "@utils/styles";

const GENDERS = ["Male", "Female", "Prefer not to say"];

interface ProfileForm {
  firstName: string;
  lastName: string;
  gender: string;
  contactNo: string;
  address: string;
  university: string;
}

const formOf = (profile: CandidateProfile): ProfileForm => ({
  firstName: profile.firstName,
  lastName: profile.lastName,
  gender: profile.gender,
  contactNo: profile.contactNo,
  address: profile.address ?? "",
  university: profile.university ?? "",
});

// The fields the candidate changed; a cleared address or university is sent as null.
const changesOf = (form: ProfileForm, profile: CandidateProfile): Partial<EditableProfileFields> => {
  const saved = formOf(profile);
  const changes: Partial<EditableProfileFields> = {};
  if (form.firstName.trim() !== saved.firstName) changes.firstName = form.firstName.trim();
  if (form.lastName.trim() !== saved.lastName) changes.lastName = form.lastName.trim();
  if (form.gender !== saved.gender) changes.gender = form.gender;
  if (form.contactNo.trim() !== saved.contactNo) changes.contactNo = form.contactNo.trim();
  if (form.address.trim() !== saved.address) changes.address = form.address.trim() || null;
  if (form.university.trim() !== saved.university) changes.university = form.university.trim() || null;
  return changes;
};

// An icon, a label and a value; a missing value shows as "Not added".
const DetailItem = ({ icon, label, value }: { icon: React.ReactNode; label: string; value: string | null }) => (
  <Stack direction="row" gap={1.5} alignItems="flex-start" sx={{ minWidth: 0 }}>
    <Box
      sx={{
        width: 36,
        height: 36,
        flexShrink: 0,
        borderRadius: "50%",
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        backgroundColor: BRAND_TINT.soft,
        color: BRAND_ORANGE,
      }}
    >
      {icon}
    </Box>
    <Box sx={{ minWidth: 0 }}>
      <Typography fontSize="0.8rem" color="text.secondary">
        {label}
      </Typography>
      <Typography fontSize="0.95rem" color={value ? "text.primary" : "text.secondary"} sx={{ overflowWrap: "anywhere" }}>
        {value || "Not added"}
      </Typography>
    </Box>
  </Stack>
);

const fieldIcon = (icon: React.ReactNode) => ({
  input: { startAdornment: <InputAdornment position="start">{icon}</InputAdornment> },
});

interface SectionProps {
  title: string;
  editing: boolean;
  saving: boolean;
  canSave: boolean;
  // True while another section is being edited, so its unsaved changes are not lost.
  editDisabled: boolean;
  canEdit: boolean;
  onEdit: () => void;
  onSave: () => void;
  onCancel: () => void;
  view: React.ReactNode;
  fields: React.ReactNode;
}

// A card that shows details and turns them into fields in place when the candidate chooses Edit.
const Section = ({
  title,
  editing,
  saving,
  canSave,
  editDisabled,
  canEdit,
  onEdit,
  onSave,
  onCancel,
  view,
  fields,
}: SectionProps) => (
  <Card elevation={0} sx={cardSx}>
    <CardContent sx={{ p: 3 }}>
      <Stack direction="row" alignItems="center" justifyContent="space-between" mb={2.5}>
        <Typography component="h3" sx={{ fontSize: "1.1rem", fontWeight: 600, color: "text.primary" }}>
          {title}
        </Typography>
        {!editing && canEdit && (
          <Button startIcon={<Pencil size={16} />} onClick={onEdit} disabled={editDisabled} sx={{ fontWeight: 700 }}>
            Edit
          </Button>
        )}
      </Stack>

      {editing ? (
        <Stack gap={2.5}>
          {fields}
          <Stack direction="row" gap={1.5} justifyContent="flex-end">
            <Button onClick={onCancel} disabled={saving} sx={{ fontWeight: 600 }}>
              Cancel
            </Button>
            <Button variant="contained" disabled={!canSave || saving} onClick={onSave} sx={{ ...pillButtonSx, px: 3 }}>
              {saving ? "Saving..." : "Save"}
            </Button>
          </Stack>
        </Stack>
      ) : (
        <Box sx={{ display: "grid", gridTemplateColumns: { xs: "1fr", sm: "1fr 1fr" }, gap: 3 }}>{view}</Box>
      )}
    </CardContent>
  </Card>
);

// The candidate's profile: who they are, and their contact details, each of which they can edit in place.
const Profile = () => {
  const dispatch = useAppDispatch();
  const { getToken } = useAppAuthContext();
  const profile = useAppSelector((state: RootState) => state.careers.profile);
  const profileState = useAppSelector((state: RootState) => state.careers.profileState);

  const [editing, setEditing] = useState<"personal" | "contact" | null>(null);
  const [form, setForm] = useState<ProfileForm>(formOf(profile));
  const [saving, setSaving] = useState(false);

  const load = () =>
    getToken()
      .then((token) => dispatch(loadProfile(token)))
      .catch(() => dispatch(profileFailed()));

  const startEditing = (section: "personal" | "contact") => {
    setForm(formOf(profile));
    setEditing(section);
  };

  const changes = changesOf(form, profile);
  const changed = Object.keys(changes).length > 0;
  const firstNameInvalid = changes.firstName === "";
  const lastNameInvalid = changes.lastName === "";
  const phoneInvalid = changes.contactNo !== undefined && !isValidE164(changes.contactNo);
  const canSave = changed && !firstNameInvalid && !lastNameInvalid && !phoneInvalid;

  const genderOptions = form.gender === "" || GENDERS.includes(form.gender) ? GENDERS : [form.gender, ...GENDERS];

  const notify = (message: string, type: "success" | "error") => dispatch(enqueueSnackbarMessage({ message, type }));

  const handleSave = async () => {
    setSaving(true);
    try {
      const token = await getToken();
      await dispatch(updateProfile({ accessToken: token, changes })).unwrap();
      notify(SnackMessage.success.profileUpdated, "success");
      setEditing(null);
    } catch {
      notify(SnackMessage.error.saveProfile, "error");
    } finally {
      setSaving(false);
    }
  };

  if (profileState === State.idle || profileState === State.loading) return <CenteredSpinner />;

  if (profileState === State.failed) {
    return (
      <PageContainer>
        <Box sx={{ py: 8, textAlign: "center", border: "1px dashed", borderColor: "error.light", borderRadius: "12px" }}>
          <Typography color="error" mb={2}>
            {SnackMessage.error.fetchProfile}
          </Typography>
          <Button variant="outlined" onClick={load}>
            Try again
          </Button>
        </Box>
      </PageContainer>
    );
  }

  const initials = `${profile.firstName.charAt(0)}${profile.lastName.charAt(0)}`.toUpperCase();

  return (
    <PageContainer>
      <PageHeading accent="My" mb={3}>
        Profile
      </PageHeading>

      <Stack gap={3}>
        <Card elevation={0} sx={cardSx}>
          <CardContent sx={{ p: 3 }}>
            <Stack direction="row" alignItems="center" gap={2}>
              <Avatar
                sx={{ width: 64, height: 64, fontSize: "1.4rem", fontWeight: 600, bgcolor: BRAND_TINT.soft, color: BRAND_ORANGE }}
              >
                {initials}
              </Avatar>
              <Box sx={{ minWidth: 0 }}>
                <Typography
                  component="h2"
                  sx={{ fontSize: { xs: "1.5rem", md: "1.9rem" }, lineHeight: 1.3, fontWeight: 400, color: "text.primary" }}
                >
                  {profile.firstName} {profile.lastName}
                </Typography>
                <Typography fontSize="0.9rem" color="text.secondary" mt={0.5} sx={{ overflowWrap: "anywhere" }}>
                  {profile.personalEmail}
                </Typography>
              </Box>
            </Stack>
          </CardContent>
        </Card>

        <Section
          title="Personal details"
          editing={editing === "personal"}
          saving={saving}
          canSave={canSave}
          editDisabled={editing !== null}
          canEdit={profile.editable !== false}
          onEdit={() => startEditing("personal")}
          onSave={handleSave}
          onCancel={() => setEditing(null)}
          view={
            <>
              <DetailItem icon={<User size={18} />} label="Name" value={`${profile.firstName} ${profile.lastName}`} />
              <DetailItem icon={<User size={18} />} label="Gender" value={profile.gender} />
              <DetailItem icon={<Mail size={18} />} label="Personal email" value={profile.personalEmail} />
            </>
          }
          fields={
            <>
              <Stack direction={{ xs: "column", sm: "row" }} gap={2.5}>
                <TextField
                  label="First name"
                  value={form.firstName}
                  onChange={(e) => setForm({ ...form, firstName: e.target.value })}
                  disabled={saving}
                  error={firstNameInvalid}
                  helperText={firstNameInvalid ? "Enter your first name." : undefined}
                  size="small"
                  fullWidth
                />
                <TextField
                  label="Last name"
                  value={form.lastName}
                  onChange={(e) => setForm({ ...form, lastName: e.target.value })}
                  disabled={saving}
                  error={lastNameInvalid}
                  helperText={lastNameInvalid ? "Enter your last name." : undefined}
                  size="small"
                  fullWidth
                />
              </Stack>
              <TextField
                select
                label="Gender"
                value={form.gender}
                onChange={(e) => setForm({ ...form, gender: e.target.value })}
                disabled={saving}
                size="small"
                fullWidth
              >
                {genderOptions.map((option) => (
                  <MenuItem key={option} value={option}>
                    {option}
                  </MenuItem>
                ))}
              </TextField>
            </>
          }
        />

        <Section
          title="Contact details"
          editing={editing === "contact"}
          saving={saving}
          canSave={canSave}
          editDisabled={editing !== null}
          canEdit={profile.editable !== false}
          onEdit={() => startEditing("contact")}
          onSave={handleSave}
          onCancel={() => setEditing(null)}
          view={
            <>
              <DetailItem icon={<Phone size={18} />} label="Contact number" value={profile.contactNo} />
              <DetailItem icon={<MapPin size={18} />} label="Address" value={profile.address} />
              <DetailItem icon={<GraduationCap size={18} />} label="University" value={profile.university} />
            </>
          }
          fields={
            <>
              <TextField
                label="Contact number"
                value={form.contactNo}
                onChange={(e) => setForm({ ...form, contactNo: e.target.value })}
                disabled={saving}
                error={phoneInvalid}
                helperText={
                  phoneInvalid
                    ? "Enter the number as + and your country code, then the number, with no spaces or dashes."
                    : "Start with + and your country code, then the number, with no spaces."
                }
                slotProps={fieldIcon(<Phone size={16} />)}
                size="small"
                fullWidth
              />
              <TextField
                label="Address"
                value={form.address}
                onChange={(e) => setForm({ ...form, address: e.target.value })}
                disabled={saving}
                slotProps={fieldIcon(<MapPin size={16} />)}
                size="small"
                fullWidth
              />
              <TextField
                label="University"
                value={form.university}
                onChange={(e) => setForm({ ...form, university: e.target.value })}
                disabled={saving}
                slotProps={fieldIcon(<GraduationCap size={16} />)}
                size="small"
                fullWidth
              />
            </>
          }
        />
      </Stack>
    </PageContainer>
  );
};

export default Profile;
