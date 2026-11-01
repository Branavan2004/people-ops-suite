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

# Email template for the Marked-leaver auto-transition summary notification.
# Placeholders: APP_NAME, SUMMARY_DATE, COUNT, EMPLOYEE_LIST, YEAR
public final string leaverAutoTransitionSummaryTemplate = string `
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta content="text/html; charset=utf-8" http-equiv="Content-Type" />
    <meta name="color-scheme" content="light dark" />
    <meta name="supported-color-schemes" content="light dark" />
    <title>WSO2 <!-- [APP_NAME] --></title>
    <style type="text/css">
      @import url("https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700;900&display=swap");
      body {
        margin: 0;
        padding: 0;
        background-color: #f4f4f4;
      }
      table {
        border-collapse: collapse;
      }
      img {
        outline: none;
        text-decoration: none;
        border: 0;
      }
      p {
        margin: 1em 0;
      }
    </style>
  </head>
  <body style="margin:0; padding:0; background-color:#f4f4f4;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f4;">
      <tbody>
        <tr>
          <td align="center" valign="top">

            <!-- HEADER -->
            <table
              width="100%"
              cellpadding="0"
              cellspacing="0"
              style="
                max-width:650px;
                background-color:#ff7300;
                background-image:url('https://wso2.cachefly.net/wso2/sites/all/2022-optimized/bg-hr-mailer-new.png');
                background-size:auto;
                background-repeat:no-repeat;
                background-position:top;
              "
            >
              <tbody>
                <tr>
                  <td style="padding:30px 20px;">
                    <a href="https://wso2.com/" style="text-decoration:none;" target="_blank">
                      <img
                        src="https://wso2.cachefly.net/wso2/sites/all/image_resources/logos/WSO2-Logo-White.png"
                        alt="WSO2 Logo"
                        height="40"
                        width="100"
                        style="height:auto; width:150px;"
                      />
                    </a>
                  </td>
                </tr>
              </tbody>
            </table>

            <!-- BODY -->
            <table
              width="100%"
              cellpadding="0"
              cellspacing="0"
              style="
                max-width:650px;
                background-color:#ffffff;
                margin:auto;
                box-shadow:0px 0px 26px 0 rgba(0,0,0,0.15);
              "
            >
              <tbody>
                <tr>
                  <td style="padding:30px 40px;">

                    <!-- Info Banner -->
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tbody>
                        <tr>
                          <td
                            style="
                              background-color:#e8f4fd;
                              border-left:4px solid #2b7de9;
                              padding:14px 16px;
                              border-radius:4px;
                            "
                          >
                            <p
                              style="
                                margin:0;
                                font-family:'Roboto', Helvetica, sans-serif;
                                font-size:14px;
                                color:#1a4c7a;
                              "
                            >
                              <strong>Automated Offboarding Update</strong> &mdash;
                              <!-- [COUNT] --> employee(s) had reached their final day of employment by
                              <!-- [SUMMARY_DATE] --> and were automatically transitioned from
                              <em>Marked leaver</em> to <em>Left</em>.
                            </p>
                          </td>
                        </tr>
                      </tbody>
                    </table>

                    <p
                      style="
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:16px;
                        color:#465868;
                        margin-top:24px;
                      "
                    >
                      Hi Admin,<br /><br />
                      The following employees were auto-transitioned to <strong>Left</strong> status. No action is
                      required unless one of these transitions looks incorrect.
                    </p>

                    <!-- Transitioned Employees -->
                    <p
                      style="
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:15px;
                        color:#465868;
                        font-weight:bold;
                        margin-bottom:4px;
                        margin-top:20px;
                      "
                    >
                      Transitioned Employees:
                    </p>
                    <table
                      width="100%"
                      cellpadding="0"
                      cellspacing="0"
                      style="
                        border:1px solid #e0e0e0;
                        border-radius:4px;
                        margin-top:8px;
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:13px;
                        color:#465868;
                      "
                    >
                      <thead>
                        <tr>
                          <th
                            align="left"
                            style="
                              padding:10px 16px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                              white-space:nowrap;
                            "
                          >
                            ID
                          </th>
                          <th
                            align="left"
                            style="
                              padding:10px 12px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                            "
                          >
                            Employee
                          </th>
                          <th
                            align="left"
                            style="
                              padding:10px 12px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                            "
                          >
                            Work email
                          </th>
                          <th
                            align="left"
                            style="
                              padding:10px 12px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                            "
                          >
                            Location
                          </th>
                          <th
                            align="right"
                            style="
                              padding:10px 16px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                              white-space:nowrap;
                            "
                          >
                            Final day
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <!-- [EMPLOYEE_LIST] -->
                      </tbody>
                    </table>

                    <p
                      style="
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:14px;
                        color:#465868;
                        margin-top:24px;
                      "
                    >
                      Best regards,<br />
                      <!-- [APP_NAME] --> System
                    </p>

                  </td>
                </tr>
              </tbody>
            </table>

            <!-- FOOTER -->
            <table width="100%" cellpadding="0" cellspacing="0" style="max-width:650px; margin:auto;">
              <tbody>
                <tr>
                  <td style="padding:20px 40px; text-align:center;">
                    <p
                      style="
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:12px;
                        color:#999999;
                        margin:0;
                      "
                    >
                      &copy; <!-- [YEAR] --> WSO2 LLC. This is an automated notification from the <!-- [APP_NAME] --> System.
                    </p>
                  </td>
                </tr>
              </tbody>
            </table>

          </td>
        </tr>
      </tbody>
    </table>
  </body>
</html>
`;


# Email template for the New-joiner activation summary notification.
# Placeholders: APP_NAME, SUMMARY_DATE, COUNT, PENDING_EMAIL_NOTE, EMPLOYEE_LIST, YEAR
public final string joinerActivationSummaryTemplate = string `
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta content="text/html; charset=utf-8" http-equiv="Content-Type" />
    <meta name="color-scheme" content="light dark" />
    <meta name="supported-color-schemes" content="light dark" />
    <title>WSO2 <!-- [APP_NAME] --></title>
    <style type="text/css">
      @import url("https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700;900&display=swap");
      body {
        margin: 0;
        padding: 0;
        background-color: #f4f4f4;
      }
      table {
        border-collapse: collapse;
      }
      img {
        outline: none;
        text-decoration: none;
        border: 0;
      }
      p {
        margin: 1em 0;
      }
    </style>
  </head>
  <body style="margin:0; padding:0; background-color:#f4f4f4;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f4;">
      <tbody>
        <tr>
          <td align="center" valign="top">

            <!-- HEADER -->
            <table
              width="100%"
              cellpadding="0"
              cellspacing="0"
              style="
                max-width:650px;
                background-color:#ff7300;
                background-image:url('https://wso2.cachefly.net/wso2/sites/all/2022-optimized/bg-hr-mailer-new.png');
                background-size:auto;
                background-repeat:no-repeat;
                background-position:top;
              "
            >
              <tbody>
                <tr>
                  <td style="padding:30px 20px;">
                    <a href="https://wso2.com/" style="text-decoration:none;" target="_blank">
                      <img
                        src="https://wso2.cachefly.net/wso2/sites/all/image_resources/logos/WSO2-Logo-White.png"
                        alt="WSO2 Logo"
                        height="40"
                        width="100"
                        style="height:auto; width:150px;"
                      />
                    </a>
                  </td>
                </tr>
              </tbody>
            </table>

            <!-- BODY -->
            <table
              width="100%"
              cellpadding="0"
              cellspacing="0"
              style="
                max-width:650px;
                background-color:#ffffff;
                margin:auto;
                box-shadow:0px 0px 26px 0 rgba(0,0,0,0.15);
              "
            >
              <tbody>
                <tr>
                  <td style="padding:30px 40px;">

                    <!-- Info Banner -->
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tbody>
                        <tr>
                          <td
                            style="
                              background-color:#e8f4fd;
                              border-left:4px solid #2b7de9;
                              padding:14px 16px;
                              border-radius:4px;
                            "
                          >
                            <p
                              style="
                                margin:0;
                                font-family:'Roboto', Helvetica, sans-serif;
                                font-size:14px;
                                color:#1a4c7a;
                              "
                            >
                              <strong>Automated Onboarding Update</strong> &mdash;
                              <!-- [COUNT] --> employee(s) had reached their start date by
                              <!-- [SUMMARY_DATE] --> and were automatically transitioned from
                              <em>New joiner</em> to <em>Active</em>.
                            </p>
                          </td>
                        </tr>
                      </tbody>
                    </table>

                    <p
                      style="
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:16px;
                        color:#465868;
                        margin-top:24px;
                      "
                    >
                      Hi Admin,<br /><br />
                      The following employees were auto-transitioned to <strong>Active</strong> status. No action is
                      required unless one of these transitions looks incorrect.
                    </p>
                    <!-- [PENDING_EMAIL_NOTE] -->

                    <!-- Transitioned Employees -->
                    <p
                      style="
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:15px;
                        color:#465868;
                        font-weight:bold;
                        margin-bottom:4px;
                        margin-top:20px;
                      "
                    >
                      Activated Employees:
                    </p>
                    <table
                      width="100%"
                      cellpadding="0"
                      cellspacing="0"
                      style="
                        border:1px solid #e0e0e0;
                        border-radius:4px;
                        margin-top:8px;
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:13px;
                        color:#465868;
                      "
                    >
                      <thead>
                        <tr>
                          <th
                            align="left"
                            style="
                              padding:10px 16px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                              white-space:nowrap;
                            "
                          >
                            ID
                          </th>
                          <th
                            align="left"
                            style="
                              padding:10px 12px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                            "
                          >
                            Employee
                          </th>
                          <th
                            align="left"
                            style="
                              padding:10px 12px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                            "
                          >
                            Work email
                          </th>
                          <th
                            align="left"
                            style="
                              padding:10px 12px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                            "
                          >
                            Location
                          </th>
                          <th
                            align="right"
                            style="
                              padding:10px 16px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                              white-space:nowrap;
                            "
                          >
                            Start date
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <!-- [EMPLOYEE_LIST] -->
                      </tbody>
                    </table>

                    <p
                      style="
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:14px;
                        color:#465868;
                        margin-top:24px;
                      "
                    >
                      Best regards,<br />
                      <!-- [APP_NAME] --> System
                    </p>

                  </td>
                </tr>
              </tbody>
            </table>

            <!-- FOOTER -->
            <table width="100%" cellpadding="0" cellspacing="0" style="max-width:650px; margin:auto;">
              <tbody>
                <tr>
                  <td style="padding:20px 40px; text-align:center;">
                    <p
                      style="
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:12px;
                        color:#999999;
                        margin:0;
                      "
                    >
                      &copy; <!-- [YEAR] --> WSO2 LLC. This is an automated notification from the <!-- [APP_NAME] --> System.
                    </p>
                  </td>
                </tr>
              </tbody>
            </table>

          </td>
        </tr>
      </tbody>
    </table>
  </body>
</html>
`;


# HTML template for the scheduled-change summary email.
#
# Placeholders: APP_NAME, SUMMARY_DATE, COUNT, EMPLOYEE_LIST, YEAR
public final string scheduledChangeSummaryTemplate = string `
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta content="text/html; charset=utf-8" http-equiv="Content-Type" />
    <meta name="color-scheme" content="light dark" />
    <meta name="supported-color-schemes" content="light dark" />
    <title>WSO2 <!-- [APP_NAME] --></title>
    <style type="text/css">
      @import url("https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700;900&display=swap");
      body {
        margin: 0;
        padding: 0;
        background-color: #f4f4f4;
      }
      table {
        border-collapse: collapse;
      }
      img {
        outline: none;
        text-decoration: none;
        border: 0;
      }
      p {
        margin: 1em 0;
      }
    </style>
  </head>
  <body style="margin:0; padding:0; background-color:#f4f4f4;">
    <table width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f4f4;">
      <tbody>
        <tr>
          <td align="center" valign="top">

            <!-- HEADER -->
            <table
              width="100%"
              cellpadding="0"
              cellspacing="0"
              style="
                max-width:650px;
                background-color:#ff7300;
                background-image:url('https://wso2.cachefly.net/wso2/sites/all/2022-optimized/bg-hr-mailer-new.png');
                background-size:auto;
                background-repeat:no-repeat;
                background-position:top;
              "
            >
              <tbody>
                <tr>
                  <td style="padding:30px 20px;">
                    <a href="https://wso2.com/" style="text-decoration:none;" target="_blank">
                      <img
                        src="https://wso2.cachefly.net/wso2/sites/all/image_resources/logos/WSO2-Logo-White.png"
                        alt="WSO2 Logo"
                        height="40"
                        width="100"
                        style="height:auto; width:150px;"
                      />
                    </a>
                  </td>
                </tr>
              </tbody>
            </table>

            <!-- BODY -->
            <table
              width="100%"
              cellpadding="0"
              cellspacing="0"
              style="
                max-width:650px;
                background-color:#ffffff;
                margin:auto;
                box-shadow:0px 0px 26px 0 rgba(0,0,0,0.15);
              "
            >
              <tbody>
                <tr>
                  <td style="padding:30px 40px;">

                    <!-- Info Banner -->
                    <table width="100%" cellpadding="0" cellspacing="0">
                      <tbody>
                        <tr>
                          <td
                            style="
                              background-color:#e8f4fd;
                              border-left:4px solid #2b7de9;
                              padding:14px 16px;
                              border-radius:4px;
                            "
                          >
                            <p
                              style="
                                margin:0;
                                font-family:'Roboto', Helvetica, sans-serif;
                                font-size:14px;
                                color:#1a4c7a;
                              "
                            >
                              <strong>Scheduled Change Update</strong> &mdash;
                              <!-- [COUNT] --> scheduled change(s) were due by <!-- [SUMMARY_DATE] --> and have
                              been processed. Changes shown as superseded were not applied:
                              the field had already been changed after the change was scheduled.
                              </em>
                            </p>
                          </td>
                        </tr>
                      </tbody>
                    </table>

                    <p
                      style="
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:16px;
                        color:#465868;
                        margin-top:24px;
                      "
                    >
                      Hi Admin,<br /><br />
                      Applied changes are now on the record. Superseded and failed changes were not
                      applied and may need to be rescheduled.
                    </p>

                    <!-- Processed Changes -->
                    <p
                      style="
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:15px;
                        color:#465868;
                        font-weight:bold;
                        margin-bottom:4px;
                        margin-top:20px;
                      "
                    >
                      Processed Changes:
                    </p>
                    <table
                      width="100%"
                      cellpadding="0"
                      cellspacing="0"
                      style="
                        border:1px solid #e0e0e0;
                        border-radius:4px;
                        margin-top:8px;
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:13px;
                        color:#465868;
                      "
                    >
                      <thead>
                        <tr>
                          <th
                            align="left"
                            style="
                              padding:10px 16px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                              white-space:nowrap;
                            "
                          >
                            ID
                          </th>
                          <th
                            align="left"
                            style="
                              padding:10px 12px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                            "
                          >
                            Employee
                          </th>
                          <th
                            align="left"
                            style="
                              padding:10px 12px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                            "
                          >
                            Location
                          </th>
                          <th
                            align="left"
                            style="
                              padding:10px 12px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                            "
                          >
                            Effective date
                          </th>
                          <th
                            align="right"
                            style="
                              padding:10px 16px;
                              background-color:#f7f9fb;
                              border-bottom:1px solid #e0e0e0;
                              font-size:11px;
                              font-weight:bold;
                              letter-spacing:0.6px;
                              text-transform:uppercase;
                              color:#7a8899;
                              white-space:nowrap;
                            "
                          >
                            Outcome
                          </th>
                        </tr>
                      </thead>
                      <tbody>
                        <!-- [EMPLOYEE_LIST] -->
                      </tbody>
                    </table>

                    <p
                      style="
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:14px;
                        color:#465868;
                        margin-top:24px;
                      "
                    >
                      Best regards,<br />
                      <!-- [APP_NAME] --> System
                    </p>

                  </td>
                </tr>
              </tbody>
            </table>

            <!-- FOOTER -->
            <table width="100%" cellpadding="0" cellspacing="0" style="max-width:650px; margin:auto;">
              <tbody>
                <tr>
                  <td style="padding:20px 40px; text-align:center;">
                    <p
                      style="
                        font-family:'Roboto', Helvetica, sans-serif;
                        font-size:12px;
                        color:#999999;
                        margin:0;
                      "
                    >
                      &copy; <!-- [YEAR] --> WSO2 LLC. This is an automated notification from the <!-- [APP_NAME] --> System.
                    </p>
                  </td>
                </tr>
              </tbody>
            </table>

          </td>
        </tr>
      </tbody>
    </table>
  </body>
</html>
`;
