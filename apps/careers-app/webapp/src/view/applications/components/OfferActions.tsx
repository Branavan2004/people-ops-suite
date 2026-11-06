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

import { Button, Stack, Typography } from "@wso2/oxygen-ui";

import { pillButtonSx } from "@utils/styles";

interface OfferActionsProps {
  // False when the candidate has already accepted another offer.
  canAccept: boolean;
  onAccept: () => void;
  onDecline: () => void;
}

// The buttons that answer an offer; accepting is not offered once another offer has been accepted.
const OfferActions = ({ canAccept, onAccept, onDecline }: OfferActionsProps) => (
  <Stack direction="row" alignItems="center" gap={1.5} flexWrap="wrap" sx={{ mb: 3 }}>
    {canAccept ? (
      <Button variant="contained" onClick={onAccept} sx={{ ...pillButtonSx, px: 3 }}>
        Accept offer
      </Button>
    ) : (
      <Typography fontSize="0.9rem" color="text.secondary">
        You have already accepted another offer, so you can&apos;t accept this one.
      </Typography>
    )}
    <Button variant="outlined" onClick={onDecline} sx={{ ...pillButtonSx, px: 3 }}>
      Decline offer
    </Button>
  </Stack>
);

export default OfferActions;
