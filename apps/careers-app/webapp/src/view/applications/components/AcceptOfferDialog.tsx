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

import { Button, Typography } from "@wso2/oxygen-ui";
import { Award } from "@wso2/oxygen-ui-icons-react";

import StatusDialog from "@component/common/StatusDialog";
import { pillButtonSx } from "@utils/styles";

interface AcceptOfferDialogProps {
  jobTitle: string;
  sending: boolean;
  onConfirm: () => void;
  onClose: () => void;
}

// Asks the candidate to confirm accepting an offer, since the answer cannot be changed here afterwards.
const AcceptOfferDialog = ({ jobTitle, sending, onConfirm, onClose }: AcceptOfferDialogProps) => (
  <StatusDialog
    open
    onClose={sending ? () => undefined : onClose}
    tone="brand"
    icon={<Award size={32} />}
    title="Accept this offer?"
    actions={
      <>
        <Button onClick={onClose} disabled={sending} sx={{ fontWeight: 600 }}>
          Cancel
        </Button>
        <Button variant="contained" onClick={onConfirm} disabled={sending} sx={{ ...pillButtonSx, px: 3 }}>
          {sending ? "Accepting..." : "Yes, accept"}
        </Button>
      </>
    }
  >
    <Typography fontSize="0.95rem" color="text.primary">
      You are about to accept the offer for {jobTitle}. You will not be able to change this answer here afterwards.
    </Typography>
  </StatusDialog>
);

export default AcceptOfferDialog;
