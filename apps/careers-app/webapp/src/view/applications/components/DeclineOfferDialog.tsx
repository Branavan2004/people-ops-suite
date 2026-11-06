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

import { Box, Button, Dialog, DialogActions, DialogContent, DialogTitle, Typography } from "@wso2/oxygen-ui";
import { useState } from "react";

import type { OfferAnswer } from "@/types/types";
import { useIsDark } from "@config/brand";
import { pillButtonSx } from "@utils/styles";
import { SelectInput, TextInput } from "@view/documents/FormInputs";

const MAX_COMMENT_LENGTH = 1000;

// The reasons offered in the dialog. The backend only requires a non-empty reason, so this list is not enforced there.
const DECLINE_REASONS = [
  "Accepted another offer",
  "Compensation",
  "Location or relocation",
  "Personal reasons",
  "Other",
];

interface DeclineOfferDialogProps {
  jobTitle: string;
  sending: boolean;
  onDecline: (answer: OfferAnswer) => void;
  onClose: () => void;
}

// Asks the candidate why they are declining an offer.
const DeclineOfferDialog = ({ jobTitle, sending, onDecline, onClose }: DeclineOfferDialogProps) => {
  const [reason, setReason] = useState("");
  const [comment, setComment] = useState("");
  const isDark = useIsDark();

  return (
    <Dialog
      open
      onClose={sending ? undefined : onClose}
      fullWidth
      maxWidth="sm"
      aria-labelledby="decline-title"
      // The box has its own surface and a visible edge, so it stands out from the page behind it in both modes.
      PaperProps={{
        sx: {
          borderRadius: "16px",
          backgroundImage: "none",
          backgroundColor: isDark ? "#162033" : "#FFFFFF",
          border: "1px solid",
          borderColor: isDark ? "rgba(255,255,255,0.22)" : "divider",
          boxShadow: isDark ? "0 24px 60px rgba(0,0,0,0.6)" : "0 24px 60px rgba(7,20,46,0.25)",
        },
      }}
    >
      <DialogTitle id="decline-title">Decline this offer?</DialogTitle>
      <DialogContent>
        <Typography color="text.secondary" mb={2}>
          We are sorry you are not joining us as {jobTitle}. Please tell us why, so we can do better.
        </Typography>
        {/* The same inputs as the profile and documents forms, so the labels sit in the middle of the boxes. */}
        <Box sx={{ display: "grid", gap: 2, pt: 0.5 }}>
          <SelectInput
            label="Reason"
            value={reason}
            onChange={setReason}
            options={DECLINE_REASONS}
            disabled={sending}
            required
            span={12}
          />
          <TextInput
            label="Anything else you would like to tell us? (optional)"
            value={comment}
            onChange={(value) => setComment(value.slice(0, MAX_COMMENT_LENGTH))}
            helper={`${comment.length}/${MAX_COMMENT_LENGTH}`}
            disabled={sending}
            multiline
            span={12}
          />
        </Box>
      </DialogContent>
      <DialogActions sx={{ px: 3, pb: 2 }}>
        <Button onClick={onClose} disabled={sending} sx={{ fontWeight: 600 }}>
          Cancel
        </Button>
        <Button
          variant="contained"
          disabled={reason === "" || sending}
          onClick={() => onDecline({ response: "declined", reason, comment: comment.trim() })}
          sx={{ ...pillButtonSx, px: 3 }}
        >
          {sending ? "Declining..." : "Decline offer"}
        </Button>
      </DialogActions>
    </Dialog>
  );
};

export default DeclineOfferDialog;
