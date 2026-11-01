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


# Reminder sent to the lead ahead of an approved sabbatical leave.
final string sabbaticalReminderTemplate = string `
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <meta content="text/html; charset=utf-8" http-equiv="Content-Type" />
    <!-- Facebook sharing information tags -->
    <meta property="og:title" content="{{subject}}" />
    <meta name="color-scheme" content="light dark" />
    <meta name="supported-color-schemes" content="light dark" />

    <title>Upcoming Sabbatical Leave Reminder</title>

    <style type="text/css">
      @import url("https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700;900&display=swap");

      @font-face {
        font-family: "Roboto", Arial, Verdana, Helvetica, sans-serif;
        font-style: normal;
        font-weight: 400;
        src: local("Roboto"), local("Roboto"),
          url("https://fonts.googleapis.com/css2?family=Roboto:wght@300;400;500;700;900&display=swap")
            format("Roboto");
      }

      #outlook a {
        padding: 0;
      }

      .body {
        width: 100% !important;
        -webkit-text-size-adjust: 100%;
        -ms-text-size-adjust: 100%;
        margin: 0;
        padding: 0;
      }

      .cBackimg {
        background: url(https://wso2.cachefly.net/wso2/sites/all/2022-optimized/bg-hr-mailer-new.png);
        background-size: auto;
        background-repeat: no-repeat;
        background-position: top;
        background-color: #ff7101;
      }

      .ExternalClass {
        width: 100%;
      }

      .ExternalClass,
      .ExternalClass p,
      .ExternalClass span,
      .ExternalClass font,
      .ExternalClass td,
      .ExternalClass div {
        line-height: 100%;
      }

      img {
        outline: none;
        text-decoration: none;
        -ms-interpolation-mode: bicubic;
      }

      .viduraimage a img:hover {
        transition: 0.3s !important;
        opacity: 0.8 !important;
      }

      .wso2_orange a {
        color: #ff7300;
        text-decoration: underline;
      }

      .wso2_orange a:hover {
        text-decoration: none !important;
      }

      .Wrap_Border img:hover {
        background-color: #ff7300 !important;
      }

      .cFottop a:hover {
        color: #465868 !important;
      }

      a.wso2_orange3:hover {
        text-decoration: none !important;
      }

      .wso2_orange3 a:hover {
        color: #ff7300 !important;
        text-decoration: none !important;
      }

      .wso2_grey7 a:hover {
        text-decoration: none !important;
      }

      a img {
        border: none;
      }

      p {
        margin: 1em 0;
      }

      table td {
        border-collapse: collapse;
      }

      /* hide unsubscribe from forwards*/
      blockquote .original-only,
      .WordSection1 .original-only {
        display: none !important;
      }

      .fadeimg:hover {
        transition: 0.3s !important;
        opacity: 0.7 !important;
      }

      .linkname:hover {
        transition: 0.3s !important;
        opacity: 0.6 !important;
      }

      .linktopic:hover {
        transition: 0.3s !important;
        opacity: 0.8 !important;
      }

      .linkbody:hover {
        transition: 0.3s !important;
        text-decoration: none !important;
        color: #000000 !important;
      }

      .linkrevbut:hover {
        transition: 0.3s !important;
        text-decoration: none;
        background-color: #092a56;
        color: #ffffff !important;
      }

      .AddtoCalender2:hover {
        transition: 0.3s !important;
        background-color: #53a99b !important;
        color: #fff !important;
      }

      .AddtoCalender:hover {
        transition: 0.3s !important;
        background-color: #1f78d1 !important;
        color: #fff !important;
      }

      .ctaorange:hover {
        transition: 0.3s !important;
        background-color: #ff7300 !important;
        color: #000 !important;
      }

      .ctaorange1:hover {
        transition: 0.3s !important;
        background-color: #ff7300 !important;
        color: #000 !important;
      }

      .footerContent a:hover {
        color: #ff7300 !important;
      }

      .wso2_center {
        text-align: center !important;
      }

      @media only screen and (max-width: 650px) {
        .fadeimg {
          width: 100% !important;
        }
      }

      @media only screen and (max-width: 490px) {
        body,
        table,
        td,
        p,
        a,
        li,
        blockquote {
          -webkit-text-size-adjust: none !important;
        }

        .footerBlock {
          padding-left: 20px !important;
          padding-right: 20px !important;
        }

        .SSborder {
          padding-left: 20px !important;
          padding-right: 20px !important;
          padding-bottom: 0 !important;
        }

        .cForm {
          padding-bottom: 30px !important;
        }

        /* Prevent Webkit platforms from changing default text sizes */
        body {
          width: 100% !important;
          min-width: 100% !important;
        }

        /* Prevent iOS Mail from adding padding to the body */

        #bodyCell {
          padding: 10px !important;
        }

        #templateContainer {
          /*              max-width:650px !important;*/
          width: 100% !important;
        }

        h1 {
          font-size: 24px !important;
          line-height: 100% !important;
        }

        .cDottedline {
          margin-top: 32px !important;
        }

        h2 {
          font-size: 20px !important;
          line-height: 100% !important;
        }

        h3 {
          font-size: 18px !important;
          line-height: 100% !important;
        }

        h4 {
          font-size: 16px !important;
          line-height: 100% !important;
        }

        #templatePreheader {
          display: none !important;
        }

        /* Hide the template preheader to save space */

        .cP1 {
          padding-top: 10px !important;
        }

        .headerContent {
          font-size: 20px !important;
          line-height: 125% !important;
        }

        .bodyContent {
          font-size: 18px !important;
          line-height: 125% !important;
          padding-left: 20px !important;
          padding-right: 20px !important;
        }

        .templateColumnContainer {
          display: block !important;
          width: 100% !important;
        }

        .columnImage {
          height: auto !important;
          max-width: 480px !important;
          width: 100% !important;
        }

        .leftColumnContent {
          font-size: 16px !important;
          line-height: 125% !important;
        }

        .rightColumnContent {
          font-size: 16px !important;
          line-height: 125% !important;
        }

        .footerContent {
          font-size: 14px !important;
          line-height: 140% !important;
        }

        .viduraimage {
          display: inline;
          padding-bottom: 20px !important;
        }

        .viduraimage img {
          max-width: 277px !important;
        }

        .viduraname {
          display: inline;
          text-align: center !important;
        }

        .cRountable {
          padding-top: 0 !important;
        }

        .cSrinath {
          padding-bottom: 20px !important;
        }

        .vidurawso2 {
          display: inline;
        }

        /* Place footer social and utility links on their own lines, for easier access */
      }

      @media (prefers-color-scheme: dark) {
        .footerContent {
          color: #a2a3a4 !important;
        }

        .Summitfotter {
          background-color: #ced6e0 !important;
        }

        .cDayAwy {
          color: #ff7300 !important;
        }

        .cDayAwy span {
          color: #ff7300 !important;
        }

        .Summitfotter p {
          color: #000000 !important;
        }

        .Summitfotter p span {
          color: #000000 !important;
        }

        .bgtest {
          background-color: #303235 !important;
        }

        .bgtestbotom {
          background-color: #292b2e !important;
        }

        .SSname {
          color: #719ce2 !important;
        }

        a.wso2_orange4:hover {
          text-decoration: none;
        }

        a.wso2_orange3 {
          color: #2b9ce9 !important;
          font-weight: 500 !important;
        }

        .SStime {
          color: #ff7300 !important;
        }

        .Bodyconetntdark {
          background-color: #202124 !important;
        }

        p {
          color: #e2e2e2 !important;
        }

        .cSesion1 {
          background-color: #282f34 !important;
        }

        p span {
          color: #ff7300 !important;
        }

        li span {
          color: #e2e2e2 !important;
        }

        .darklink {
          color: #e2e2e2 !important;
        }

        .darklink:hover {
          transition: 0.3s !important;
          text-decoration: none !important;
          color: #e2e2e2 !important;
        }

        .linkbody:hover {
          transition: 0.3s !important;
          text-decoration: none !important;
          color: #e2e2e2 !important;
        }

        h2 {
          color: #e2e2e2 !important;
        }

        h3 {
          color: #e2e2e2 !important;
        }

        h2 a {
          color: #e2e2e2 !important;
        }

        .fcp {
          color: #969696 !important;
        }

        .darkintro {
          color: #bbbdc1 !important;
        }

        .cPicks {
          color: #b1c7d8 !important;
        }

        .cSubs {
          color: #bdbdbd !important;
        }

        li {
          color: #ff7300 !important;
        }

        .footerContent a {
          color: #969696 !important;
        }

        .darkfotterlink {
          color: #bbbdc1 !important;
        }

        .cTitleDark {
          color: #ff7300 !important;
        }

        .darkcommunity {
          background-color: #272727 !important;
        }

        .cHighlightText {
          color: #ffffff !important;
        }

        .lightLogoWrapper,
        .lightLogo {
          display: block !important;
          width: auto !important;
          overflow: visible !important;
          float: none !important;
          max-height: inherit !important;
          max-width: inherit !important;
          visibility: inherit !important;
          height: 40px !important;
          text-align: left !important;
        }
      }
    </style>
  </head>

  <body
    class="wso2_body bgtest"
    style="
      font-family: 'Roboto', Helvetica, sans-serif;
      -webkit-text-size-adjust: 100%;
      -ms-text-size-adjust: 100%;
      height: 100% !important;
      width: 100% !important;
      margin: 0;
      padding: 0;
    "
    data-gr-c-s-loaded="true"
    bgcolor="#f8f9fa"
  >
    <table
      align="center"
      border="0"
      cellpadding="0"
      cellspacing="0"
      class="wso2_full_wrap bgtest"
      style="
        -ms-text-size-adjust: 100%;
        -webkit-text-size-adjust: 100%;
        height: 100% !important;
        margin: 0;
        mso-table-lspace: 0pt;
        mso-table-rspace: 0pt;
        padding: 0;
      "
      width="100%"
    >
      <tbody>
        <tr>
          <td
            align="center"
            id="bodyCell"
            style="
              -webkit-text-size-adjust: 100%;
              -ms-text-size-adjust: 100%;
              mso-table-lspace: 0pt;
              mso-table-rspace: 0pt;
              margin: 0;
            "
            valign="top"
          >
            <!-- BEGIN TEMPLATE // -->
            <table
              cellpadding="0"
              cellspacing="0"
              id="templateContainer"
              style="
                -webkit-text-size-adjust: 100%;
                -ms-text-size-adjust: 100%;
                mso-table-lspace: 0pt;
                mso-table-rspace: 0pt;
              "
              width="100%"
            >
              <tbody>
                <tr>
                  <td
                    align="center"
                    background="https://wso2.cachefly.net/wso2/sites/all/2022-optimized/bg-hr-mailer-new.png"
                    bgcolor="#f2be0b"
                    class="bgtest cBackimg"
                    style="
                      -webkit-text-size-adjust: 100%;
                      -ms-text-size-adjust: 100%;
                      mso-table-lspace: 0pt;
                      mso-table-rspace: 0pt;
                      margin: 0;
                      height: 275px;
                      background: url('https://wso2.cachefly.net/wso2/sites/all/2022-optimized/bg-hr-mailer-new.png');
                      background-size: auto;
                      background-repeat: no-repeat;
                      background-position: top;
                    "
                    valign="top"
                  >
                    <table
                      cellpadding="0"
                      cellspacing="0"
                      id="templateContainer"
                      style="
                        -webkit-text-size-adjust: 100%;
                        -ms-text-size-adjust: 100%;
                        mso-table-lspace: 0pt;
                        mso-table-rspace: 0pt;
                      "
                      width="100%"
                    >
                      <tbody>
                        <tr>
                          <td align="center" valign="top">
                            <table
                              border="0"
                              cellpadding="0"
                              cellspacing="0"
                              id="m_2377566871920059920templateHeader"
                              style="max-width: 650px; margin-top: 20px"
                              width="100%"
                            >
                              <tbody>
                                <tr>
                                  <td
                                    align="left"
                                    class="headerContent"
                                    style="
                                      -webkit-text-size-adjust: 100%;
                                      -ms-text-size-adjust: 100%;
                                      mso-table-lspace: 0pt;
                                      mso-table-rspace: 0pt;
                                      color: #505050;
                                      font-family: 'Roboto', Helvetica,
                                        sans-serif;
                                      font-size: 20px;
                                      font-weight: bold;
                                      line-height: 20px;
                                      vertical-align: middle;
                                      padding: 30px 0 30px 10px;
                                      text-align: left;
                                    "
                                    valign="top"
                                  >
                                    <a
                                      href="https://wso2.com/"
                                      style="text-decoration: none"
                                      target="_blank"
                                      ><img
                                        alt="WSO2 Logo"
                                        class="darkLogo"
                                        height="40"
                                        id="headerImage"
                                        src="https://wso2.cachefly.net/wso2/sites/all/image_resources/logos/WSO2-Logo-White.png"
                                        style="
                                          width: 100px;
                                          -ms-interpolation-mode: bicubic;
                                          height: auto;
                                          outline: none;
                                          text-decoration: none;
                                          border: 0;
                                        "
                                        width="100"
                                    /></a>
                                  </td>
                                  <!-- <td align="right" class="wso2_orange preheaderContent" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;mso-table-lspace: 0pt;mso-table-rspace: 0pt;color: #949494;font-family: 'Roboto', Helvetica,sans-serif;font-size: 11px;line-height: 12.5px;text-align: right;padding: 20px 10px 30px 0;vertical-align: middle;" valign="top"><a href="{{view_online}}" style="-webkit-text-size-adjust: 100%;-ms-text-size-adjust: 100%;color: #1e1e1e;font-weight: normal;text-decoration: underline;" target="_blank">View online</a></td> -->
                                </tr>
                              </tbody>
                            </table>
                          </td>
                        </tr>
                        <tr>
                          <td
                            align="center"
                            style="
                              -webkit-text-size-adjust: 100%;
                              -ms-text-size-adjust: 100%;
                              mso-table-lspace: 0pt;
                              mso-table-rspace: 0pt;
                              width: 100%;
                            "
                            valign="top"
                            width="100%"
                          >
                            <!-- BEGIN BODY // -->
                            <table
                              bgcolor="#ffffff"
                              border="0"
                              cellpadding="0"
                              cellspacing="0"
                              class="Bodyconetntdark"
                              id="templateBody"
                              style="
                                width: 100%;
                                max-width: 650px;
                                -ms-text-size-adjust: 100%;
                                -webkit-text-size-adjust: 100%;
                                mso-table-lspace: 0pt;
                                mso-table-rspace: 0pt;
                                margin: auto;
                              "
                              width="100%"
                            >
                              <tbody>
                                <tr>
                                  <td
                                    align="center"
                                    style="
                                      -webkit-text-size-adjust: 100%;
                                      -ms-text-size-adjust: 100%;
                                      mso-table-lspace: 0pt;
                                      mso-table-rspace: 0pt;
                                      color: #ffffff;
                                      font-family: 'Roboto', Helvetica,
                                        sans-serif;
                                      font-size: 16px;
                                      line-height: 5px;
                                      text-align: center;
                                      margin: 40px 30px 30px 40px;
                                      box-shadow: 0px 0px 26px 0
                                        rgb(0 0 0 / 57%);
                                    "
                                    valign="top"
                                  >
                                    <table
                                      align="left"
                                      border="0"
                                      cellpadding="0"
                                      cellspacing="0"
                                      style="text-align: left; margin-bottom: 0"
                                      width="100%"
                                    >
                                      <tbody>
                                        <tr>
                                          <td
                                            align="center"
                                            class="SSborder"
                                            style="
                                              -webkit-text-size-adjust: 100%;
                                              -ms-text-size-adjust: 100%;
                                              mso-table-lspace: 0pt;
                                              mso-table-rspace: 0pt;
                                              color: #ffffff;
                                              font-family: 'Roboto', Helvetica,
                                                sans-serif;
                                              font-size: 16px;
                                              line-height: 5px;
                                              text-align: center;
                                              margin: 40px 50px 30px 50px;
                                              padding: 40px 50px 30px 50px;
                                            "
                                            valign="top"
                                          >
                                            <table
                                              align="left"
                                              border="0"
                                              cellpadding="0"
                                              cellspacing="0"
                                              style="
                                                text-align: left;
                                                margin-bottom: 0;
                                              "
                                              width="100%"
                                            >
                                              <tbody>
                                                <tr>
                                                  <td
                                                    align="center"
                                                    style="
                                                      -webkit-text-size-adjust: 100%;
                                                      -ms-text-size-adjust: 100%;
                                                      mso-table-lspace: 0pt;
                                                      mso-table-rspace: 0pt;
                                                      color: #ff957d;
                                                      font-family: 'Roboto',
                                                        Helvetica, sans-serif;
                                                      font-size: 16px;
                                                      line-height: 24px;
                                                      text-align: center;
                                                      padding: 20px 0px 0px 0px;
                                                    "
                                                    valign="top"
                                                    class=""
                                                  >
                                                    <p
                                                      class="cTitleDark"
                                                      style="
                                                        font-family: 'Roboto',
                                                          Helvetica, sans-serif;
                                                        padding-bottom: 0;
                                                        font-size: 19px;
                                                        line-height: 23px;
                                                        padding-top: 0;
                                                        padding-left: 0;
                                                        padding-right: 0;
                                                        padding-right: 0;
                                                        color: #ff7300;
                                                        text-align: center;
                                                        margin-top: 0px;
                                                        margin-bottom: 12px;
                                                        font-weight: 500;
                                                      "
                                                    >
                                                      WSO2 Leave App
                                                    </p>

                                                    <p
                                                      style="
                                                        font-family: 'Roboto',
                                                          Helvetica, sans-serif;
                                                        padding-bottom: 0;
                                                        font-size: 24px;
                                                        line-height: 32px;
                                                        padding-top: 0;
                                                        padding-left: 0;
                                                        padding-right: 0;
                                                        padding-right: 0;
                                                        color: #2f373e;
                                                        text-align: center;
                                                        margin-top: 0px;
                                                        font-weight: 600;
                                                        margin-bottom: 6px;
                                                      "
                                                    >
                                                      Upcoming Sabbatical Leave
                                                    </p>
                                                  </td>
                                                </tr>
                                              </tbody>
                                            </table>
                                          </td>
                                        </tr>
                                      </tbody>
                                    </table>
                                  </td>
                                </tr>
                              </tbody>
                            </table>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td
                    align="center"
                    bgcolor="#f8f9fa"
                    class="bgtest"
                    style="
                      -webkit-text-size-adjust: 100%;
                      -ms-text-size-adjust: 100%;
                      mso-table-lspace: 0pt;
                      mso-table-rspace: 0pt;
                      width: 100%;
                      padding: 0px 0 0;
                    "
                    valign="top"
                    width="100%"
                  >
                    <!-- BEGIN BODY // -->
                    <table
                      bgcolor="#ffffff"
                      border="0"
                      cellpadding="0"
                      cellspacing="0"
                      class="Bodyconetntdark"
                      id="templateBody"
                      style="
                        width: 100%;
                        max-width: 650px;
                        -ms-text-size-adjust: 100%;
                        -webkit-text-size-adjust: 100%;
                        mso-table-lspace: 0pt;
                        mso-table-rspace: 0pt;
                        margin: auto;
                      "
                      width="100%"
                    >
                      <tbody>
                        <tr>
                          <td
                            align="center"
                            class="bodyContent"
                            style="
                              -webkit-text-size-adjust: 100%;
                              -ms-text-size-adjust: 100%;
                              mso-table-lspace: 0pt;
                              mso-table-rspace: 0pt;
                              color: #465868;
                              font-family: 'Roboto', Helvetica, sans-serif;
                              font-size: 16px;
                              line-height: 24px;
                              text-align: center;
                              padding: 0px 50px 40px 50px;
                              border-bottom: 2px solid #ff7300;
                            "
                            valign="top"
                          >
                            <p
                              class="cDottedline"
                              style="
                                font-family: 'Roboto', Helvetica, sans-serif;
                                padding-bottom: 5px;
                                font-size: 17px;
                                line-height: 28px;
                                padding-top: 40px;
                                padding-left: 0;
                                padding-right: 0;
                                padding-right: 0;
                                color: #465868;
                                text-align: left;
                                border-top: 2px dotted #c3c5c9;
                                margin-top: 0;
                              "
                            >
                              Dear <!-- [LEAD_NAME] -->,
                            </p>

                            <p
                              style="
                                font-family: 'Roboto', Helvetica, sans-serif;
                                padding-bottom: 5px;
                                font-size: 17px;
                                line-height: 28px;
                                padding-left: 0;
                                padding-right: 0;
                                padding-right: 0;
                                color: #465868;
                                text-align: justify;
                              "
                            >
                              This is a reminder that <!-- [EMPLOYEE_NAME] --> is scheduled to commence their
                              <!-- [LEAVE_DURATION] --> sabbatical leave from <!-- [LEAVE_START_DATE] --> to
                              <!-- [LEAVE_END_DATE] -->.
                            </p>
                            <p
                              style="
                                font-family: 'Roboto', Helvetica, sans-serif;
                                padding-bottom: 5px;
                                font-size: 17px;
                                line-height: 28px;
                                padding-left: 0;
                                padding-right: 0;
                                padding-right: 0;
                                color: #465868;
                                text-align: justify;
                              "
                            >
                              Please kindly work with the relevant employee on the upcoming sabbatical leave period and
                              that appropriate plans are in place to manage their workload, responsibilities,
                              objectives and commitments during their absence.
                            </p>
                            <p
                              style="
                                font-family: 'Roboto', Helvetica, sans-serif;
                                font-size: 17px;
                                line-height: 28px;
                                padding-top: 0;
                                padding-left: 0;
                                padding-right: 0;
                                padding-right: 0;
                                color: #465868;
                                text-align: left;
                                padding-top: 20px;
                              "
                            >
                              Best regards,<br />
                              WSO2 Leave App.
                            </p>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </td>
                </tr>
                <tr>
                  <td
                    align="center"
                    bgcolor="#e8eaed"
                    class="bgtest"
                    style="
                      -webkit-text-size-adjust: 100%;
                      -ms-text-size-adjust: 100%;
                      mso-table-lspace: 0pt;
                      mso-table-rspace: 0pt; /* background-color: #ffffff; */
                      padding: 60px 0px;
                    "
                    valign="top"
                  >
                    <!-- BEGIN FOOTER // -->
                    <table
                      border="0"
                      cellpadding="0"
                      cellspacing="0"
                      id="templateFooter"
                      style="
                        -ms-text-size-adjust: 100%;
                        -webkit-text-size-adjust: 100%; /* background-color: #ffffff; */
                        border-collapse: collapse !important;
                        mso-table-lspace: 0pt;
                        mso-table-rspace: 0pt;
                        max-width: 650px;
                      "
                      width="100%"
                    >
                      <tbody>
                        <tr>
                          <td
                            align="center"
                            bgcolor="#e8eaed"
                            class="bgtest footerBlock"
                            style="
                              -webkit-text-size-adjust: 100%;
                              -ms-text-size-adjust: 100%;
                              mso-table-lspace: 0pt;
                              mso-table-rspace: 0pt; /* background-color: #ffffff; */
                              padding: 0px 50px 0px 50px;
                            "
                            valign="top"
                          >
                            <!-- BEGIN FOOTER // -->
                            <table
                              border="0"
                              cellpadding="0"
                              cellspacing="0"
                              id="templateFooter"
                              style="
                                -ms-text-size-adjust: 100%;
                                -webkit-text-size-adjust: 100%; /* background-color: #ffffff; */
                                border-collapse: collapse !important;
                                mso-table-lspace: 0pt;
                                mso-table-rspace: 0pt;
                              "
                              width="100%"
                            >
                              <tbody>
                                <tr>
                                  <td
                                    align="left"
                                    class="Wrap_Border footerContent leftMarginMobile cWhiteSocialIcon"
                                    style="
                                      -webkit-text-size-adjust: 100%;
                                      -ms-text-size-adjust: 100%;
                                      mso-table-lspace: 0pt;
                                      mso-table-rspace: 0pt;
                                      color: #606060;
                                      font-family: 'Roboto', Helvetica,
                                        sans-serif;
                                      font-size: 10px;
                                      line-height: 14px;
                                      text-align: left;
                                      padding: 0px 0 20px;
                                    "
                                    valign="top"
                                  >
                                    <a
                                      href="https://twitter.com/wso2"
                                      style="
                                        -webkit-text-size-adjust: 100%;
                                        -ms-text-size-adjust: 100%;
                                        color: #606060;
                                        font-weight: normal;
                                        text-decoration: underline;
                                        padding-right: 10px;
                                      "
                                      ><img
                                        align="middle"
                                        alt="WSO2 Twitter"
                                        src="https://wso2.cachefly.net/wso2/sites/all/2022/images/twitter-dark-3.png"
                                        style="
                                          width: 30px;
                                          -ms-interpolation-mode: bicubic;
                                          height: auto;
                                          outline: none;
                                          text-decoration: none;
                                          border: 0;
                                          text-align: center;
                                          border-radius: 9px;
                                        " /></a
                                    >&nbsp;&nbsp;&nbsp;<a
                                      href="https://www.facebook.com/WSO2Inc"
                                      style="
                                        -webkit-text-size-adjust: 100%;
                                        -ms-text-size-adjust: 100%;
                                        color: #606060;
                                        font-weight: normal;
                                        text-decoration: underline;
                                        padding-right: 10px;
                                      "
                                      ><img
                                        align="middle"
                                        alt="WSO2 Facebook"
                                        src="https://wso2.cachefly.net/wso2/sites/all/2022/images/fb-dark-3.png"
                                        style="
                                          width: 30px;
                                          -ms-interpolation-mode: bicubic;
                                          height: auto;
                                          outline: none;
                                          text-decoration: none;
                                          border: 0;
                                          text-align: center;
                                          border-radius: 9px;
                                        " /></a
                                    >&nbsp;&nbsp;&nbsp;<a
                                      href="https://www.linkedin.com/company/wso2/"
                                      style="
                                        -webkit-text-size-adjust: 100%;
                                        -ms-text-size-adjust: 100%;
                                        color: #606060;
                                        font-weight: normal;
                                        text-decoration: underline;
                                        padding-right: 10px;
                                      "
                                      ><img
                                        align="middle"
                                        alt="WSO2 In"
                                        src="https://wso2.cachefly.net/wso2/sites/all/2022/images/linkedin-dark-3.png"
                                        style="
                                          width: 30px;
                                          -ms-interpolation-mode: bicubic;
                                          height: auto;
                                          outline: none;
                                          text-decoration: none;
                                          border: 0;
                                          text-align: center;
                                          border-radius: 9px;
                                        " /></a
                                    >&nbsp;&nbsp;&nbsp;<a
                                      href="https://www.youtube.com/user/WSO2TechFlicks?sub_confirmation=1"
                                      style="
                                        -webkit-text-size-adjust: 100%;
                                        -ms-text-size-adjust: 100%;
                                        color: #606060;
                                        font-weight: normal;
                                        text-decoration: underline;
                                        padding-right: 10px;
                                      "
                                      ><img
                                        align="middle"
                                        alt="WSO2 YT"
                                        src="https://wso2.cachefly.net/wso2/sites/all/2022/images/youtube-dark-3.png"
                                        style="
                                          width: 30px;
                                          -ms-interpolation-mode: bicubic;
                                          height: auto;
                                          outline: none;
                                          text-decoration: none;
                                          border: 0;
                                          text-align: center;
                                          border-radius: 9px;
                                        " /></a
                                    >&nbsp;&nbsp;&nbsp;<a
                                      href="http://instagram.com/wso2inc/"
                                      style="
                                        -webkit-text-size-adjust: 100%;
                                        -ms-text-size-adjust: 100%;
                                        color: #606060;
                                        font-weight: normal;
                                        text-decoration: underline;
                                        padding-right: 10px;
                                      "
                                      ><img
                                        align="middle"
                                        alt="WSO2 instagram"
                                        src="https://wso2.cachefly.net/wso2/sites/all/2022/images/instagram-dark-3.png"
                                        style="
                                          width: 30px;
                                          -ms-interpolation-mode: bicubic;
                                          height: auto;
                                          outline: none;
                                          text-decoration: none;
                                          border: 0;
                                          text-align: center;
                                          border-radius: 9px;
                                        "
                                    /></a>
                                  </td>
                                </tr>
                                <tr>
                                  <td
                                    align="left"
                                    class="wso2_orange3 footerContent leftMarginMobile"
                                    style="
                                      -webkit-text-size-adjust: 100%;
                                      -ms-text-size-adjust: 100%;
                                      mso-table-lspace: 0pt;
                                      mso-table-rspace: 0pt;
                                      color: #465868;
                                      font-family: 'Roboto', Helvetica,
                                        sans-serif;
                                      font-size: 13px;
                                      line-height: 18px;
                                      text-align: left;
                                      padding: 0 0px 20px;
                                      letter-spacing: 0.1px;
                                    "
                                    valign="top"
                                  >
                                    <a
                                      href="https://wso2.com/contact/"
                                      style="
                                        color: #465868;
                                        text-decoration: none;
                                      "
                                      >Contact Us</a
                                    >
                                    &nbsp;| &nbsp;<a
                                      href="http://wso2.com/privacy-policy"
                                      style="
                                        color: #465868;
                                        text-decoration: none;
                                      "
                                      >Privacy Policy</a
                                    >&nbsp;| &nbsp;<a
                                      href="https://wso2.com/subscription/"
                                      style="
                                        color: #465868;
                                        text-decoration: none;
                                      "
                                      >Get Support</a
                                    >
                                  </td>
                                </tr>
                                <tr>
                                  <td
                                    align="left"
                                    class="headerContent leftMarginMobile"
                                    style="
                                      -webkit-text-size-adjust: 100%;
                                      -ms-text-size-adjust: 100%;
                                      mso-table-lspace: 0pt;
                                      mso-table-rspace: 0pt;
                                      color: #505050;
                                      font-family: 'Roboto', Helvetica,
                                        sans-serif;
                                      font-size: 20px;
                                      font-weight: bold;
                                      line-height: 20px;
                                      vertical-align: middle;
                                      padding: 20px 0 18px;
                                    "
                                    valign="top"
                                  >
                                    <a
                                      href="https://wso2.com/"
                                      style="text-decoration: none"
                                      target="_blank"
                                      ><img
                                        alt="WSO2 Logo"
                                        height="40"
                                        id="headerImage"
                                        src="https://wso2.cachefly.net/wso2/sites/all/image_resources/logos/WSO2-Logo-Black.png"
                                        style="
                                          width: 100px;
                                          -ms-interpolation-mode: bicubic;
                                          height: auto;
                                          outline: none;
                                          text-decoration: none;
                                          border: 0;
                                        "
                                        width="100"
                                    /></a>
                                  </td>
                                </tr>
                                <tr>
                                  <td
                                    align="left"
                                    class="wso2_orange3 footerContent leftMarginMobile"
                                    style="
                                      -webkit-text-size-adjust: 100%;
                                      -ms-text-size-adjust: 100%;
                                      mso-table-lspace: 0pt;
                                      mso-table-rspace: 0pt;
                                      color: #465868;
                                      font-family: 'Roboto', Helvetica,
                                        sans-serif;
                                      font-size: 13px;
                                      line-height: 18px;
                                      text-align: left;
                                      padding: 0 0px 20px;
                                      letter-spacing: 0.1px;
                                    "
                                    valign="top"
                                  >
                                    ©
                                    <!-- [YEAR] -->
                                    WSO2, Inc. All Rights Reserved
                                  </td>
                                </tr>
                                <tr>
                                  <td
                                    align="left"
                                    class="wso2_orange3 footerContent leftMarginMobile"
                                    style="
                                      -webkit-text-size-adjust: 100%;
                                      -ms-text-size-adjust: 100%;
                                      mso-table-lspace: 0pt;
                                      mso-table-rspace: 0pt;
                                      color: #465868;
                                      font-family: 'Roboto', Helvetica,
                                        sans-serif;
                                      font-size: 13px;
                                      line-height: 18px;
                                      text-align: left;
                                      padding: 0 0px 20px;
                                      letter-spacing: 0.1px;
                                    "
                                    valign="top"
                                  >
                                  </td>
                                </tr>
                              </tbody>
                            </table>
                          </td>
                        </tr>
                      </tbody>
                    </table>
                  </td>
                </tr>
              </tbody>
            </table>
            <!-- // END BODY -->
          </td>
        </tr>
      </tbody>
    </table>
    <!-- // END TEMPLATE -->
  </body>
</html>`;
