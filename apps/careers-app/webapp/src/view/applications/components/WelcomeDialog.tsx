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
import { Check } from "@wso2/oxygen-ui-icons-react";

import StatusDialog from "@component/common/StatusDialog";
import { pillButtonSx } from "@utils/styles";

interface WelcomeDialogProps {
  jobTitle: string;
  // Opens the page for the onboarding documents; not given while that step is closed.
  onSubmitDocuments?: () => void;
  onClose: () => void;
}

// Congratulates a candidate who has accepted an offer and, when the documents step is open, offers to open the page for
// their onboarding documents.
const WelcomeDialog = ({ jobTitle, onSubmitDocuments, onClose }: WelcomeDialogProps) => (
  <StatusDialog
    open
    onClose={onClose}
    tone="success"
    icon={<Check size={32} strokeWidth={3} />}
    title="Welcome to the WSO2 family!"
    actions={
      onSubmitDocuments ? (
        <>
          <Button onClick={onClose} sx={{ fontWeight: 600 }}>
            Later
          </Button>
          <Button variant="contained" onClick={onSubmitDocuments} sx={{ ...pillButtonSx, px: 3 }}>
            Submit documents
          </Button>
        </>
      ) : (
        <Button variant="contained" onClick={onClose} sx={{ ...pillButtonSx, px: 3 }}>
          Close
        </Button>
      )
    }
  >
    <Typography fontSize="0.95rem" color="text.primary">
      Congratulations on joining WSO2 as {jobTitle}.
      {onSubmitDocuments && " Please submit the documents we need to complete your onboarding."} The hiring team will
      contact you with the next steps.
    </Typography>
  </StatusDialog>
);

export default WelcomeDialog;
