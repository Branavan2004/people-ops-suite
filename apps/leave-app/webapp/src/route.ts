// Copyright (c) 2025 WSO2 LLC. (https://www.wso2.com).
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
import AssessmentIcon from "@mui/icons-material/Assessment";
import EditCalendarIcon from "@mui/icons-material/EditCalendar";
import EventAvailableIcon from "@mui/icons-material/EventAvailable";
import HistoryIcon from "@mui/icons-material/History";
import HowToRegIcon from "@mui/icons-material/HowToReg";
import LocalHospitalIcon from "@mui/icons-material/LocalHospital";
import WorkHistoryIcon from "@mui/icons-material/WorkHistory";
import { type RouteObject } from "react-router-dom";
import { Navigate } from "react-router-dom";

import React from "react";

import OutletWrapper from "@component/common/OutletWrapper";
import { Role } from "@slices/authSlice/auth";
import { isIncludedRole } from "@utils/utils";
import RecordEmployeeLeave from "@view/EmployeeLeave/RecordEmployeeLeave";
import SickNotes from "@view/EmployeeLeave/SickNotes";
import GeneralLeave from "@view/GeneralLeave/GeneralLeave";
import AdminSabbaticalTab from "@view/LeadReport/panel/AdminSabbaticalTab";
import LeadReportTab from "@view/LeadReport/panel/LeadReportTab";
import SabbaticalLeaveHistory from "@view/LeaveHistory/SabbaticalLeaveHistory";
import ApproveHistoryTab from "@view/SabbaticalLeave/Panel/ApproveHistoryTab";
import ApproveLeaveTab from "@view/SabbaticalLeave/Panel/ApproveLeaveTab";
import OtherAuthorizedApproveTab from "@view/SabbaticalLeave/Panel/OtherAuthorizedApproveTab";
import SabbaticalLeave from "@view/SabbaticalLeave/SabbaticalLeave";

import type { RouteDetail, RouteObjectWithRole } from "./types/types";
import GeneralLeaveHistory from "./view/LeaveHistory/GeneralLeaveHistory";

type RouteObjectWithMeta = RouteObjectWithRole & {
  text?: string;
  icon?: React.ReactElement<any, string | React.JSXElementConstructor<any>> | undefined;
  denyRoles?: string[];
  children?: RouteObjectWithMeta[];
};

export const routes: RouteObjectWithMeta[] = [
  {
    index: true,
    element: React.createElement(GeneralLeave),
    allowRoles: [Role.EMPLOYEE, Role.INTERN, Role.LEAD, Role.PEOPLE_OPS_TEAM],
  },
  {
    path: "apply",
    text: "Apply",
    icon: React.createElement(WorkHistoryIcon),
    element: React.createElement(OutletWrapper),
    allowRoles: [Role.EMPLOYEE, Role.INTERN, Role.LEAD, Role.PEOPLE_OPS_TEAM],
    children: [
      {
        index: true,
        element: React.createElement(Navigate, { to: "general", replace: true }),
        allowRoles: [Role.EMPLOYEE, Role.INTERN, Role.LEAD, Role.PEOPLE_OPS_TEAM],
      },
      {
        path: "general",
        text: "General",
        icon: React.createElement(WorkHistoryIcon),
        element: React.createElement(GeneralLeave),
        allowRoles: [Role.EMPLOYEE, Role.INTERN, Role.LEAD, Role.PEOPLE_OPS_TEAM],
      },
      {
        path: "sabbatical",
        text: "Sabbatical",
        icon: React.createElement(EventAvailableIcon),
        element: React.createElement(SabbaticalLeave),
        allowRoles: [Role.EMPLOYEE, Role.LEAD],
        denyRoles: [Role.INTERN],
      },
    ],
  },
  {
    path: "approve",
    text: "Approve",
    icon: React.createElement(HowToRegIcon),
    element: React.createElement(OutletWrapper),
    allowRoles: [Role.LEAD],
    children: [
      {
        path: "sabbatical",
        text: "Sabbatical",
        icon: React.createElement(EventAvailableIcon),
        element: React.createElement(ApproveLeaveTab),
        allowRoles: [Role.LEAD],
      },
      {
        path: "other-authorized",
        text: "Other Authorized",
        icon: React.createElement(EventAvailableIcon),
        element: React.createElement(OtherAuthorizedApproveTab),
        allowRoles: [Role.LEAD],
      },
      {
        path: "approval-history",
        text: "Approval History",
        icon: React.createElement(HistoryIcon),
        element: React.createElement(ApproveHistoryTab),
        allowRoles: [Role.LEAD],
      },
    ],
  },
  {
    path: "history",
    text: "My History",
    icon: React.createElement(HistoryIcon),
    element: React.createElement(OutletWrapper),
    allowRoles: [Role.EMPLOYEE, Role.INTERN, Role.LEAD],
    children: [
      {
        path: "general",
        text: "General",
        icon: React.createElement(WorkHistoryIcon),
        element: React.createElement(GeneralLeaveHistory),
        allowRoles: [Role.EMPLOYEE, Role.INTERN, Role.LEAD],
      },
      {
        path: "sabbatical",
        text: "Sabbatical",
        icon: React.createElement(EventAvailableIcon),
        element: React.createElement(SabbaticalLeaveHistory),
        allowRoles: [Role.EMPLOYEE, Role.LEAD],
        denyRoles: [Role.INTERN],
      },
    ],
  },
  {
    path: "employee-leave",
    text: "Employee Leave",
    icon: React.createElement(EditCalendarIcon),
    element: React.createElement(OutletWrapper),
    // People Ops and sick note readers; each page below narrows it further (recording leave for another
    // employee is a People Ops action, and Sick Notes is for the sick note roles only).
    allowRoles: [Role.PEOPLE_OPS_TEAM, Role.SICK_NOTE_READER],
    children: [
      {
        path: "record",
        text: "Record Leave",
        icon: React.createElement(EditCalendarIcon),
        element: React.createElement(RecordEmployeeLeave),
        allowRoles: [Role.PEOPLE_OPS_TEAM],
      },
      {
        path: "sick-notes",
        text: "Sick Notes",
        icon: React.createElement(LocalHospitalIcon),
        element: React.createElement(SickNotes),
        allowRoles: [Role.SICK_NOTE_READER],
      },
    ],
  },
  {
    path: "reports",
    text: "Reports",
    icon: React.createElement(AssessmentIcon),
    element: React.createElement(OutletWrapper),
    allowRoles: [Role.LEAD, Role.PEOPLE_OPS_TEAM],
    children: [
      {
        path: "general",
        text: "General",
        icon: React.createElement(AssessmentIcon),
        element: React.createElement(LeadReportTab),
        allowRoles: [Role.LEAD, Role.PEOPLE_OPS_TEAM],
      },
      {
        path: "sabbatical",
        text: "Sabbatical",
        icon: React.createElement(EventAvailableIcon),
        element: React.createElement(AdminSabbaticalTab),
        allowRoles: [Role.LEAD, Role.PEOPLE_OPS_TEAM],
      },
    ],
  },
];

export const getActiveRoutesV2 = (
  routes: RouteObjectWithRole[] | undefined,
  roles: string[],
): RouteObjectWithRole[] => {
  if (!routes) return [];

  const routesObj: RouteObjectWithRole[] = [];

  routes.forEach((routeObj) => {
    if (
      (!routeObj.allowRoles || isIncludedRole(roles, routeObj.allowRoles)) &&
      (!routeObj.denyRoles || !isIncludedRole(roles, routeObj.denyRoles))
    ) {
      if (routeObj.index) {
        routesObj.push({ ...routeObj });
      } else {
        routesObj.push({
          ...routeObj,
          children: getActiveRoutesV2(routeObj.children, roles),
        });
      }
    }
  });

  return routesObj;
};

export const getActiveRoutes = (roles: string[]): RouteObject[] => {
  const routesObj: RouteObject[] = [];

  routes.forEach((routeObj) => {
    if (
      (!routeObj.allowRoles || isIncludedRole(roles, routeObj.allowRoles)) &&
      (!routeObj.denyRoles || !isIncludedRole(roles, routeObj.denyRoles))
    ) {
      routesObj.push({ ...routeObj });
    }
  });

  return routesObj;
};

export const getActiveRouteDetails = (roles: string[]): RouteDetail[] => {
  const routesObj: RouteDetail[] = [];

  const processRoute = (routeObj: RouteObjectWithMeta): RouteDetail | null => {
    // Skip routes without text (e.g., redirect routes)
    if (!routeObj.text) {
      return null;
    }

    if (
      (!routeObj.allowRoles || isIncludedRole(roles, routeObj.allowRoles)) &&
      (!routeObj.denyRoles || !isIncludedRole(roles, routeObj.denyRoles))
    ) {
      const routeDetail: RouteDetail = {
        path: routeObj.path ?? "",
        text: routeObj.text!,
        icon: routeObj.icon!,
        allowRoles: routeObj.allowRoles,
        denyRoles: routeObj.denyRoles,
        element: routeObj.element,
      };

      // Recursively process children
      if (routeObj.children && routeObj.children.length > 0) {
        const activeChildren: RouteDetail[] = [];
        routeObj.children.forEach((child) => {
          const processedChild = processRoute(child as RouteObjectWithMeta);
          if (processedChild) {
            activeChildren.push(processedChild);
          }
        });
        if (activeChildren.length > 0) {
          routeDetail.children = activeChildren;
        }
      }

      return routeDetail;
    }
    return null;
  };

  routes.forEach((routeObj) => {
    const processed = processRoute(routeObj);
    if (processed) {
      routesObj.push(processed);
    }
  });

  return routesObj;
};

interface GetActiveParentRoutesProps {
  routes: RouteObjectWithRole[] | undefined;
  roles: string[];
}

export const getActiveParentRoutes = ({ routes, roles }: GetActiveParentRoutesProps): string[] => {
  if (!routes) return [];

  const activeParentPaths: string[] = [];

  routes.forEach((routeObj) => {
    if (
      routeObj.path &&
      routeObj.element &&
      (!routeObj.allowRoles || isIncludedRole(roles, routeObj.allowRoles)) &&
      (!routeObj.denyRoles || !isIncludedRole(roles, routeObj.denyRoles))
    ) {
      activeParentPaths.push(routeObj.path);
    }
  });

  return activeParentPaths;
};
