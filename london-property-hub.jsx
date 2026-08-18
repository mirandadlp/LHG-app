import React, { useState, useMemo, useRef } from "react";
import {
  BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, CartesianGrid,
  PieChart, Pie, Cell,
} from "recharts";
import * as XLSX from "xlsx";
import {
  LayoutDashboard, Building2, Search, FileBarChart, Upload, Settings2,
  ClipboardCheck, ChevronLeft, Plus, Trash2, Download, AlertTriangle,
  CheckCircle2, Clock, HelpCircle, History, FileText, X, Filter, Shield,
  PencilLine, Eye, ChevronRight, Bell, Star, MapPin, SlidersHorizontal,
  Bookmark, TicketPercent,
} from "lucide-react";

/* ============================================================
   LONDON HOTEL GROUP — PROPERTY INFORMATION MANAGEMENT
   Styled after the home-services app reference:
   · deep navy hero header with white serif headline and
     underline search + filter icon
   · soft lavender canvas
   · amber circular category icons with labels
   · navy voucher-banner pill with circular chevron
   · white service cards: square media panel left, navy bold
     title, yellow price chip, italic credit line
   · navy-pill bottom nav (active) + grey circles (inactive)
   · generous rounded corners on everything
   ============================================================ */

/* ---------------------------- Design tokens ---------------------------- */
const NAVY = "#1E2749";         // primary — hero, buttons, nav
const NAVY_DK = "#151B36";      // deepest — banner, outer frame
const LAV = "#E9EBF5";          // lavender page canvas
const LAV_SOFT = "#F3F4FA";     // lighter section panels
const AMBER = "#F5A623";        // circular category icons
const YELLOW = "#F6C244";       // price chips
const INK = "#1E2749";
const MUTED = "#8A8FA8";
const HAIR = "rgba(30,39,73,0.10)";
const RED = "#D64545";
const ORANGE = "#DD8A2E";
const OKGREEN = "#2E9E6B";

const DISPLAY = `'Lora', Georgia, 'Times New Roman', serif`;
const BODY = `'Mulish', -apple-system, 'Segoe UI', sans-serif`;

const FontLoader = () => (
  <style>{`
    @import url('https://fonts.googleapis.com/css2?family=Lora:wght@600;700&family=Mulish:ital,wght@0,400;0,600;0,700;0,800;1,400;1,600&display=swap');
    input[type=number]::-webkit-inner-spin-button { opacity: 0.4; }
    ::selection { background: rgba(246,194,68,0.45); }
    .scrollbar-none::-webkit-scrollbar { display: none; }
  `}</style>
);

const STATUS_STYLE = {
  "Not Started": { text: "#6E7288", dot: "#9CA1B8" },
  "In Progress": { text: ORANGE, dot: ORANGE },
  "Submitted": { text: "#3B6FB5", dot: "#3B6FB5" },
  "Changes Requested": { text: "#C0622D", dot: "#C0622D" },
  "Verified": { text: OKGREEN, dot: OKGREEN, star: true },
  "Overdue": { text: RED, dot: RED },
  "Needs Review": { text: "#8256B0", dot: "#8256B0" },
};

/* ---------------------------- Controlled lists ---------------------------- */
const INITIAL_OPTIONS = {
  boroughs: ["Croydon", "Lewisham", "Newham", "Greenwich", "Ealing", "Camden", "Barking & Dagenham"],
  councils: ["Croydon Council", "Lewisham Council", "Newham Council", "Royal Borough of Greenwich", "Ealing Council", "Camden Council", "Barking & Dagenham Council"],
  regions: ["London South", "London East", "London North", "London West"],
  propertyTypes: ["Hotel", "Hostel", "Temporary Accommodation", "Serviced Apartments", "Residential Housing", "Mixed Use"],
  operationalStatuses: ["Open", "Partially Open", "Closed for Refurbishment", "Pre-Opening"],
  buildingTypes: ["Purpose-built", "Converted Office", "Converted Residential", "Victorian Terrace", "New Build"],
  elevatorTypes: ["Passenger", "Service", "Goods", "Platform Lift"],
  documentTypes: ["Floor Plan", "Property Survey", "Building Specification", "Accessibility Report", "Safety Documentation", "Legacy Spreadsheet", "Photograph", "Certificate"],
};

/* ---------------------------- Accommodation model ---------------------------- */
const ACCOM = [
  { key: "singles", label: "Singles", group: "Rooms" },
  { key: "doubles", label: "Doubles", group: "Rooms" },
  { key: "triples", label: "Triples", group: "Rooms" },
  { key: "wcSc", label: "Water Closet SC Units", group: "Rooms" },
  { key: "flat1", label: "1 Bedroom Flats", group: "Flats" },
  { key: "flat2", label: "2 Bedroom Flats", group: "Flats" },
  { key: "flat3", label: "3 Bedroom Flats", group: "Flats" },
  { key: "wcFlats", label: "WC Flats", group: "Flats" },
  { key: "house2", label: "2 Bedroom Houses", group: "Houses" },
  { key: "house3", label: "3 Bedroom Houses", group: "Houses" },
  { key: "house4", label: "4 Bedroom Houses", group: "Houses" },
  { key: "house5", label: "5 Bedroom Houses", group: "Houses" },
  { key: "wcHouses", label: "WC Houses", group: "Houses" },
  { key: "other", label: "Other Accommodation Type", group: "Other" },
];
const FLAT_KEYS = ["flat1", "flat2", "flat3", "wcFlats"];
const HOUSE_KEYS = ["house2", "house3", "house4", "house5", "wcHouses"];
const blankAccom = (o = {}) => {
  const base = {};
  ACCOM.forEach((a) => (base[a.key] = null));
  return { ...base, ...o };
};
const num = (v) => (v === null || v === undefined || v === "" ? 0 : Number(v) || 0);
const accomTotal = (a) => ACCOM.reduce((s, f) => s + num(a?.[f.key]), 0);

/* ---------------------------- Field registry ---------------------------- */
const SECTIONS = [
  { id: "general", label: "General information" },
  { id: "dimensions", label: "Room dimensions" },
  { id: "accessibility", label: "Accessibility" },
  { id: "building", label: "Building" },
];

const BASE_FIELDS = [
  { id: "siteName", section: "general", label: "Site name", type: "text", required: true, help: "The name used on internal reporting." },
  { id: "propertyName", section: "general", label: "Property name", type: "text", required: true },
  { id: "addressLine1", section: "general", label: "Address line 1", type: "text", required: true },
  { id: "addressLine2", section: "general", label: "Address line 2", type: "text" },
  { id: "city", section: "general", label: "City / town", type: "text", required: true },
  { id: "postcode", section: "general", label: "Postal code", type: "postcode", required: true, help: "UK format, e.g. CR0 2RF." },
  { id: "borough", section: "general", label: "Borough", type: "select", options: "boroughs", required: true },
  { id: "council", section: "general", label: "Council", type: "select", options: "councils", required: true },
  { id: "region", section: "general", label: "Region", type: "select", options: "regions", required: true },
  { id: "propertyType", section: "general", label: "Property type", type: "select", options: "propertyTypes", required: true },
  { id: "ownershipCompany", section: "general", label: "Ownership company", type: "text" },
  { id: "managementCompany", section: "general", label: "Management company", type: "text" },
  { id: "manager", section: "general", label: "General manager / property manager", type: "text", required: true },
  { id: "managerEmail", section: "general", label: "Property manager email", type: "email", required: true },
  { id: "managerPhone", section: "general", label: "Property manager phone", type: "text" },
  { id: "operationalStatus", section: "general", label: "Operational status", type: "select", options: "operationalStatuses", required: true },
  { id: "openedDate", section: "general", label: "Date property opened", type: "date" },
  { id: "generalNotes", section: "general", label: "Notes", type: "notes" },
  { id: "singleSize", section: "dimensions", label: "Standard single room size", type: "measurement" },
  { id: "doubleSize", section: "dimensions", label: "Standard double room size", type: "measurement" },
  { id: "tripleSize", section: "dimensions", label: "Standard triple room size", type: "measurement" },
  { id: "avgBedroom", section: "dimensions", label: "Average bedroom size", type: "measurement" },
  { id: "minBedroom", section: "dimensions", label: "Minimum bedroom size", type: "measurement" },
  { id: "maxBedroom", section: "dimensions", label: "Maximum bedroom size", type: "measurement" },
  { id: "dimensionNotes", section: "dimensions", label: "Measurement notes", type: "notes", help: "Note how rooms were measured, e.g. internal floor area excluding en-suite." },
  { id: "wheelchairEntrance", section: "accessibility", label: "Wheelchair accessible entrance", type: "yesno", required: true },
  { id: "stepFree", section: "accessibility", label: "Step-free entrance", type: "yesno", required: true },
  { id: "accessibleBedrooms", section: "accessibility", label: "Accessible bedrooms", type: "yesno" },
  { id: "accessibleBedroomCount", section: "accessibility", label: "Number of accessible bedrooms", type: "number" },
  { id: "accessibleBathrooms", section: "accessibility", label: "Accessible bathrooms", type: "yesno" },
  { id: "accessibleElevators", section: "accessibility", label: "Accessible elevators", type: "yesno" },
  { id: "accessibleParking", section: "accessibility", label: "Accessible parking", type: "yesno" },
  { id: "rampAccess", section: "accessibility", label: "Ramp access", type: "yesno" },
  { id: "handrails", section: "accessibility", label: "Handrails", type: "yesno" },
  { id: "hearingAssistance", section: "accessibility", label: "Hearing assistance", type: "yesno" },
  { id: "visualAssistance", section: "accessibility", label: "Visual assistance features", type: "yesno" },
  { id: "otherAccessibility", section: "accessibility", label: "Other accessibility features", type: "text" },
  { id: "accessibilityNotes", section: "accessibility", label: "Accessibility notes", type: "notes" },
  { id: "floors", section: "building", label: "Number of floors", type: "number", required: true },
  { id: "buildingArea", section: "building", label: "Total building area", type: "measurement" },
  { id: "buildingCount", section: "building", label: "Number of buildings on site", type: "number" },
  { id: "entrances", section: "building", label: "Number of entrances", type: "number" },
  { id: "emergencyExits", section: "building", label: "Number of emergency exits", type: "number", required: true },
  { id: "parkingSpaces", section: "building", label: "Number of parking spaces", type: "number" },
  { id: "accessibleParkingSpaces", section: "building", label: "Number of accessible parking spaces", type: "number" },
  { id: "fireSafety", section: "building", label: "Fire safety information", type: "notes", help: "Alarm system, sprinklers, last fire risk assessment date." },
  { id: "buildingType", section: "building", label: "Building type", type: "select", options: "buildingTypes" },
  { id: "constructionYear", section: "building", label: "Construction year", type: "number" },
  { id: "renovationYear", section: "building", label: "Most recent renovation year", type: "number" },
  { id: "buildingNotes", section: "building", label: "Notes", type: "notes" },
];

/* ---------------------------- Sample portfolio ---------------------------- */
const lift = (o) => ({
  id: Math.random().toString(36).slice(2, 9), name: "", type: "Passenger", capacity: null,
  maxOccupancy: null, width: null, depth: null, height: null, doorWidth: null,
  accessible: "Yes", service: "No", passenger: "Yes", notes: "", ...o,
});
const stair = (o) => ({
  id: Math.random().toString(36).slice(2, 9), name: "", location: "", floorsServed: null,
  width: null, classification: "Standard", emergencyExit: "No", notes: "", ...o,
});

const SEED = [
  {
    id: "p-croydon",
    verification: "In Progress",
    values: {
      siteName: "Croydon Housing", propertyName: "Croydon Housing",
      addressLine1: "142 London Road", addressLine2: "Broad Green", city: "Croydon",
      postcode: "CR0 2TB", borough: "Croydon", council: "Croydon Council", region: "London South",
      propertyType: "Residential Housing", ownershipCompany: "London PropCo 3 Ltd",
      managementCompany: "London Operations Ltd", manager: "Jane Smith",
      managerEmail: "jane.smith@londonhotelgroup.co.uk", managerPhone: "020 7946 0112",
      operationalStatus: "Open", openedDate: "2016-04-11",
      generalNotes: "Legacy records held in three separate spreadsheets prior to migration.",
      singleSize: { v: 9.2, u: "m²" }, doubleSize: { v: 13.4, u: "m²" }, tripleSize: { v: 17.1, u: "m²" },
      avgBedroom: { v: 12.6, u: "m²" }, minBedroom: { v: 8.1, u: "m²" }, maxBedroom: { v: 22.4, u: "m²" },
      wheelchairEntrance: "Yes", stepFree: "Yes", accessibleBedrooms: "Yes", accessibleBedroomCount: 14,
      accessibleBathrooms: "Yes", accessibleElevators: "Yes", accessibleParking: "Yes",
      rampAccess: "Yes", handrails: "Yes", hearingAssistance: "No", visualAssistance: "No",
      floors: 7, buildingArea: { v: 8420, u: "m²" }, buildingCount: 2, entrances: 3,
      emergencyExits: 6, parkingSpaces: 42, accessibleParkingSpaces: 4,
      buildingType: "Converted Office", constructionYear: 1974, renovationYear: 2019,
      fireSafety: "L1 addressable alarm system. Sprinklers on floors 1–7. FRA completed March 2026.",
    },
    accommodation: blankAccom({
      singles: 105, doubles: 72, triples: 38, wcSc: 47,
      flat1: 33, flat2: 24, flat3: 12, wcFlats: 4, wcHouses: 4,
    }),
    elevators: [
      lift({ name: "Lift A — Main Core", type: "Passenger", capacity: 8, maxOccupancy: 8, width: 1.1, depth: 1.4, height: 2.2, doorWidth: 0.9, accessible: "Yes", passenger: "Yes", service: "No", notes: "Serves floors G–7." }),
      lift({ name: "Lift B — Goods", type: "Service", capacity: 12, maxOccupancy: 12, width: 1.4, depth: 2.1, height: 2.3, doorWidth: 1.1, accessible: "No", passenger: "No", service: "Yes", notes: "Housekeeping and deliveries only." }),
    ],
    staircases: [
      stair({ name: "Stair 1", location: "North core", floorsServed: 8, width: 1.2, classification: "Emergency", emergencyExit: "Yes" }),
      stair({ name: "Stair 2", location: "South core", floorsServed: 8, width: 1.1, classification: "Standard", emergencyExit: "No" }),
    ],
    documents: [
      { id: "d1", name: "Croydon-Housing-Floorplans-2019.pdf", type: "Floor Plan", date: "2026-06-02", by: "Jane Smith", notes: "Post-refurbishment set." },
      { id: "d2", name: "Croydon-Accessibility-Audit.pdf", type: "Accessibility Report", date: "2026-05-14", by: "Priya Raman", notes: "" },
    ],
    history: [
      { id: "h1", field: "Singles", prev: "98", next: "105", by: "Jane Smith", date: "2026-08-12 09:41", reason: "Property manager verification", approval: "Pending" },
      { id: "h2", field: "Number of accessible bedrooms", prev: "12", next: "14", by: "Jane Smith", date: "2026-08-12 09:38", reason: "Two rooms converted in 2025", approval: "Pending" },
      { id: "h3", field: "Most recent renovation year", prev: "—", next: "2019", by: "Priya Raman", date: "2026-07-30 15:02", reason: "Migrated from legacy spreadsheet", approval: "Approved" },
    ],
  },
  {
    id: "p-lewisham", verification: "Verified",
    values: {
      siteName: "Lewisham Lodge Hotel", propertyName: "Lewisham Lodge", addressLine1: "8 Rennell Street",
      city: "London", postcode: "SE13 7HD", borough: "Lewisham", council: "Lewisham Council",
      region: "London South", propertyType: "Hotel", ownershipCompany: "London PropCo 1 Ltd",
      managementCompany: "London Operations Ltd", manager: "David Okafor",
      managerEmail: "david.okafor@londonhotelgroup.co.uk", managerPhone: "020 7946 0187",
      operationalStatus: "Open", openedDate: "2012-09-01",
      singleSize: { v: 11, u: "m²" }, doubleSize: { v: 15.5, u: "m²" }, avgBedroom: { v: 14, u: "m²" },
      minBedroom: { v: 10.2, u: "m²" }, maxBedroom: { v: 26, u: "m²" },
      wheelchairEntrance: "Yes", stepFree: "Yes", accessibleBedrooms: "Yes", accessibleBedroomCount: 9,
      accessibleBathrooms: "Yes", accessibleElevators: "Yes", accessibleParking: "No",
      rampAccess: "Yes", handrails: "Yes", hearingAssistance: "Yes", visualAssistance: "Yes",
      floors: 5, buildingArea: { v: 5100, u: "m²" }, buildingCount: 1, entrances: 2, emergencyExits: 4,
      parkingSpaces: 18, accessibleParkingSpaces: 2, buildingType: "Purpose-built",
      constructionYear: 2005, renovationYear: 2022, fireSafety: "L2 system, annual certification current.",
    },
    accommodation: blankAccom({ singles: 64, doubles: 88, triples: 21, wcSc: 12, flat1: 6, flat2: 2 }),
    elevators: [
      lift({ name: "Guest Lift 1", capacity: 10, maxOccupancy: 10, width: 1.2, depth: 1.5, doorWidth: 0.9 }),
      lift({ name: "Guest Lift 2", capacity: 10, maxOccupancy: 10, width: 1.2, depth: 1.5, doorWidth: 0.9 }),
      lift({ name: "Service Lift", type: "Service", capacity: 14, accessible: "No", passenger: "No", service: "Yes" }),
    ],
    staircases: [stair({ name: "Main Stair", location: "Lobby", floorsServed: 6, width: 1.4, classification: "Emergency", emergencyExit: "Yes" })],
    documents: [{ id: "d3", name: "Lewisham-Fire-Cert-2026.pdf", type: "Certificate", date: "2026-03-11", by: "David Okafor", notes: "" }],
    history: [{ id: "h4", field: "Verification", prev: "Submitted", next: "Verified", by: "Priya Raman", date: "2026-07-22 11:15", reason: "Approved after review", approval: "Approved" }],
  },
  {
    id: "p-newham", verification: "Submitted",
    values: {
      siteName: "Newham Riverside House", propertyName: "Riverside House", addressLine1: "24 Cundy Road",
      city: "London", postcode: "E16 3DJ", borough: "Newham", council: "Newham Council",
      region: "London East", propertyType: "Temporary Accommodation", ownershipCompany: "London PropCo 2 Ltd",
      managementCompany: "London Operations Ltd", manager: "Aisha Khan",
      managerEmail: "aisha.khan@londonhotelgroup.co.uk", managerPhone: "020 7946 0233",
      operationalStatus: "Open", openedDate: "2018-02-19",
      singleSize: { v: 8.6, u: "m²" }, doubleSize: { v: 12.9, u: "m²" }, avgBedroom: { v: 11.4, u: "m²" },
      wheelchairEntrance: "Yes", stepFree: "No", accessibleBedrooms: "Yes", accessibleBedroomCount: 6,
      accessibleBathrooms: "Yes", accessibleElevators: "Yes", accessibleParking: "No", rampAccess: "Yes",
      handrails: "Yes", hearingAssistance: "No",
      floors: 6, buildingCount: 1, entrances: 2, emergencyExits: 4, parkingSpaces: 12,
      accessibleParkingSpaces: 1, buildingType: "Converted Office", constructionYear: 1988,
    },
    accommodation: blankAccom({ singles: 78, doubles: 54, triples: 44, wcSc: 30, flat1: 18, flat2: 22, flat3: 9, house3: 3 }),
    elevators: [lift({ name: "Lift 1", capacity: 8 }), lift({ name: "Lift 2", type: "Service", capacity: 10, accessible: "No", passenger: "No", service: "Yes" })],
    staircases: [stair({ name: "East Stair", location: "East wing", floorsServed: 7, width: 1.1, classification: "Emergency", emergencyExit: "Yes" })],
    documents: [],
    history: [{ id: "h5", field: "Triples", prev: "28", next: "44", by: "Aisha Khan", date: "2026-08-10 16:20", reason: "Reconfiguration completed July 2026", approval: "Pending" }],
  },
  {
    id: "p-greenwich", verification: "Verified",
    values: {
      siteName: "Greenwich Court Apartments", propertyName: "Greenwich Court", addressLine1: "3 Norman Road",
      city: "London", postcode: "SE10 9QX", borough: "Greenwich", council: "Royal Borough of Greenwich",
      region: "London South", propertyType: "Serviced Apartments", ownershipCompany: "London PropCo 1 Ltd",
      managementCompany: "London Operations Ltd", manager: "Tom Reilly",
      managerEmail: "tom.reilly@londonhotelgroup.co.uk", managerPhone: "020 7946 0301",
      operationalStatus: "Open", openedDate: "2021-06-30",
      singleSize: { v: 12, u: "m²" }, doubleSize: { v: 16.8, u: "m²" }, avgBedroom: { v: 15.2, u: "m²" },
      minBedroom: { v: 11, u: "m²" }, maxBedroom: { v: 24, u: "m²" },
      wheelchairEntrance: "Yes", stepFree: "Yes", accessibleBedrooms: "Yes", accessibleBedroomCount: 11,
      accessibleBathrooms: "Yes", accessibleElevators: "Yes", accessibleParking: "Yes", rampAccess: "Yes",
      handrails: "Yes", hearingAssistance: "Yes", visualAssistance: "Yes",
      floors: 9, buildingArea: { v: 11200, u: "m²" }, buildingCount: 1, entrances: 2, emergencyExits: 5,
      parkingSpaces: 60, accessibleParkingSpaces: 6, buildingType: "New Build",
      constructionYear: 2020, renovationYear: 2020, fireSafety: "Sprinklered throughout. L1 system.",
    },
    accommodation: blankAccom({ flat1: 64, flat2: 48, flat3: 18, wcFlats: 6, doubles: 12 }),
    elevators: [
      lift({ name: "Core A Lift 1", capacity: 13 }), lift({ name: "Core A Lift 2", capacity: 13 }),
      lift({ name: "Core B Lift", capacity: 8 }), lift({ name: "Service Lift", type: "Service", capacity: 16, accessible: "No", passenger: "No", service: "Yes" }),
    ],
    staircases: [stair({ name: "Core A Stair", location: "Core A", floorsServed: 10, width: 1.3, classification: "Emergency", emergencyExit: "Yes" }), stair({ name: "Core B Stair", location: "Core B", floorsServed: 10, width: 1.3, classification: "Emergency", emergencyExit: "Yes" })],
    documents: [{ id: "d4", name: "Greenwich-Survey-2021.pdf", type: "Property Survey", date: "2026-01-09", by: "Tom Reilly", notes: "" }],
    history: [],
  },
  {
    id: "p-ealing", verification: "Changes Requested",
    values: {
      siteName: "Ealing Park Hostel", propertyName: "Ealing Park", addressLine1: "77 Uxbridge Road",
      city: "London", postcode: "W5 5SL", borough: "Ealing", council: "Ealing Council",
      region: "London West", propertyType: "Hostel", ownershipCompany: "London PropCo 3 Ltd",
      managementCompany: "London Operations Ltd", manager: "Marta Nowak",
      managerEmail: "marta.nowak@londonhotelgroup.co.uk",
      operationalStatus: "Open", openedDate: "2019-11-05",
      avgBedroom: { v: 10.1, u: "m²" },
      wheelchairEntrance: "No", stepFree: "No", accessibleBedrooms: "No", accessibleBedroomCount: 0,
      accessibleBathrooms: "No", accessibleElevators: "N/A", rampAccess: "No", handrails: "Yes",
      floors: 4, buildingCount: 1, entrances: 1, emergencyExits: 2, buildingType: "Victorian Terrace",
      constructionYear: 1901,
    },
    accommodation: blankAccom({ singles: 40, doubles: 36, triples: 26, wcSc: 8 }),
    elevators: [],
    staircases: [stair({ name: "Main Stair", location: "Central", floorsServed: 5, width: 0.9, classification: "Emergency", emergencyExit: "Yes" })],
    documents: [],
    history: [{ id: "h6", field: "Verification", prev: "Submitted", next: "Changes Requested", by: "Priya Raman", date: "2026-08-05 10:02", reason: "Room dimensions and fire safety information missing", approval: "Approved" }],
  },
  {
    id: "p-camden", verification: "Not Started",
    values: {
      siteName: "Camden Row Residences", propertyName: "Camden Row", addressLine1: "12 Bayham Street",
      city: "London", postcode: "NW1 0EY", borough: "Camden", council: "Camden Council",
      region: "London North", propertyType: "Mixed Use", manager: "Unassigned",
      managerEmail: "", operationalStatus: "Open",
    },
    accommodation: blankAccom({ singles: 22, doubles: 18, flat1: 9, flat2: 6 }),
    elevators: [], staircases: [], documents: [], history: [],
  },
  {
    id: "p-barking", verification: "Overdue",
    values: {
      siteName: "Barking Gateway House", propertyName: "Gateway House", addressLine1: "5 Abbey Road",
      city: "Barking", postcode: "IG11 7BT", borough: "Barking & Dagenham", council: "Barking & Dagenham Council",
      region: "London East", propertyType: "Temporary Accommodation", ownershipCompany: "London PropCo 2 Ltd",
      manager: "Sam Whitfield", managerEmail: "sam.whitfield@londonhotelgroup.co.uk",
      operationalStatus: "Partially Open", floors: 5, emergencyExits: 3, buildingCount: 1,
      wheelchairEntrance: "Yes", stepFree: "Yes", accessibleBedroomCount: 4, accessibleBedrooms: "Yes",
    },
    accommodation: blankAccom({ singles: 55, doubles: 31, triples: 12, wcSc: 20, flat2: 14, house3: 6, house4: 2 }),
    elevators: [lift({ name: "Lift 1", capacity: 8 })],
    staircases: [stair({ name: "Stair A", location: "North", floorsServed: 6, width: 1.1, emergencyExit: "Yes", classification: "Emergency" })],
    documents: [], history: [],
  },
];

/* ---------------------------- Helpers ---------------------------- */
const isFilled = (v) => {
  if (v === null || v === undefined || v === "") return false;
  if (typeof v === "object") return v.v !== null && v.v !== undefined && v.v !== "";
  return true;
};
function completeness(p, fields) {
  const applicable = fields.filter((f) => f.type !== "file");
  let filled = applicable.filter((f) => isFilled(p.values[f.id])).length;
  let total = applicable.length + 3;
  if (accomTotal(p.accommodation) > 0) filled += 1;
  if (p.elevators.length > 0 || p.values.__noLifts) filled += 1;
  if (p.staircases.length > 0) filled += 1;
  return Math.round((filled / total) * 100);
}
function missingFields(p, fields) {
  const req = fields.filter((f) => f.required && !isFilled(p.values[f.id]));
  const opt = fields.filter((f) => !f.required && f.type !== "file" && !isFilled(p.values[f.id]));
  return { required: req, optional: opt };
}
const stamp = () => new Date().toISOString().slice(0, 16).replace("T", " ");
const fmt = (n) => (n ?? 0).toLocaleString("en-GB");
const pctColor = (pct) => (pct >= 90 ? OKGREEN : pct >= 70 ? AMBER : RED);

/* ---------------------------- Small UI pieces ---------------------------- */
function StatusPill({ status, small }) {
  const s = STATUS_STYLE[status] || STATUS_STYLE["Not Started"];
  return (
    <span className={`inline-flex items-center gap-1.5 rounded-full bg-white font-bold ${small ? "px-2.5 py-0.5 text-[10px]" : "px-3.5 py-1 text-[11px]"}`}
      style={{ color: s.text, boxShadow: "0 2px 8px rgba(30,39,73,0.10)", border: `1px solid ${HAIR}` }}>
      {s.star ? <Star size={11} fill={YELLOW} color={YELLOW} /> : <span className="h-1.5 w-1.5 rounded-full" style={{ background: s.dot }} />}
      {status}
    </span>
  );
}

/* Yellow price-chip — like "$30/h" in the reference */
function Chip({ children, tone = "yellow" }) {
  const tones = {
    yellow: { background: YELLOW, color: NAVY_DK },
    navy: { background: NAVY, color: "#fff" },
    soft: { background: LAV, color: NAVY },
  };
  return (
    <span className="inline-flex items-center gap-1 rounded-full px-3 py-1 text-[11px] font-extrabold" style={tones[tone]}>
      {children}
    </span>
  );
}

function Ring({ pct, size = 56, stroke = 6, light }) {
  const r = (size - stroke) / 2;
  const c = 2 * Math.PI * r;
  return (
    <svg width={size} height={size} className="shrink-0">
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={light ? "rgba(255,255,255,0.18)" : "rgba(30,39,73,0.10)"} strokeWidth={stroke} />
      <circle cx={size / 2} cy={size / 2} r={r} fill="none" stroke={light ? YELLOW : pctColor(pct)} strokeWidth={stroke}
        strokeDasharray={c} strokeDashoffset={c - (c * pct) / 100} strokeLinecap="round"
        style={{ transition: "stroke-dashoffset 0.6s ease" }}
        transform={`rotate(-90 ${size / 2} ${size / 2})`} />
      <text x="50%" y="50%" dominantBaseline="central" textAnchor="middle"
        style={{ fontSize: size / 4.2, fontWeight: 800, fill: light ? "#fff" : INK, fontFamily: BODY }}>{pct}%</text>
    </svg>
  );
}

function Card({ children, className = "", style = {} }) {
  return (
    <div className={`rounded-[24px] bg-white ${className}`}
      style={{ boxShadow: "0 2px 6px rgba(30,39,73,0.05), 0 10px 26px rgba(30,39,73,0.07)", ...style }}>
      {children}
    </div>
  );
}

function SectionTitle({ children, right }) {
  return (
    <div className="mb-3 flex items-center justify-between">
      <h2 className="text-[19px] font-bold" style={{ fontFamily: DISPLAY, color: INK }}>{children}</h2>
      {right}
    </div>
  );
}

function Kpi({ label, value, sub, tone }) {
  return (
    <Card className="p-4">
      <div className="text-[10px] font-extrabold uppercase tracking-[0.08em]" style={{ color: MUTED }}>{label}</div>
      <div className="mt-1 text-[24px] font-bold leading-tight" style={{ color: tone || INK, fontFamily: DISPLAY }}>{value}</div>
      {sub && <div className="mt-0.5 text-[11px]" style={{ color: MUTED }}>{sub}</div>}
    </Card>
  );
}

function Btn({ children, onClick, variant = "default", size = "md", disabled, title }) {
  const sizes = { sm: "px-4 py-1.5 text-[12px]", md: "px-6 py-2.5 text-[13px]" };
  const styles = {
    default: { background: disabled ? "#9AA0BC" : NAVY, color: "#fff" },
    amber: { background: disabled ? "#F3D9A8" : AMBER, color: NAVY_DK },
    yellow: { background: disabled ? "#F5E4AE" : YELLOW, color: NAVY_DK },
    subtle: { background: "#fff", color: NAVY, border: `1.5px solid ${NAVY}` },
    ghost: { background: "rgba(30,39,73,0.07)", color: NAVY },
  };
  return (
    <button title={title} disabled={disabled} onClick={onClick}
      className={`inline-flex items-center justify-center gap-1.5 rounded-full font-extrabold transition active:scale-[0.97] ${sizes[size]} ${disabled ? "cursor-not-allowed" : "hover:brightness-110"}`}
      style={styles[variant]}>
      {children}
    </button>
  );
}

/* Lavender-fill inputs with navy focus ring */
const inputCls = "w-full rounded-2xl px-3.5 py-2.5 text-[13px] outline-none transition focus:ring-2";
const inputStyle = (readOnly) => ({
  background: readOnly ? "rgba(30,39,73,0.04)" : LAV_SOFT,
  color: readOnly ? MUTED : INK,
  border: `1px solid ${readOnly ? "transparent" : HAIR}`,
  fontFamily: BODY,
  "--tw-ring-color": "rgba(30,39,73,0.35)",
});

function Field({ field, value, onChange, readOnly, options }) {
  const [help, setHelp] = useState(false);
  const missingReq = field.required && !isFilled(value);
  const emailBad = field.type === "email" && isFilled(value) && !/^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/.test(value);
  const postBad = field.type === "postcode" && isFilled(value) && !/^[A-Z]{1,2}\d[A-Z\d]?\s?\d[A-Z]{2}$/i.test(value);

  let control;
  if (field.type === "select" || field.type === "custom-select") {
    const list = field.type === "custom-select" ? field.optionList || [] : options[field.options] || [];
    control = (
      <select disabled={readOnly} className={inputCls} style={inputStyle(readOnly)} value={value ?? ""} onChange={(e) => onChange(e.target.value)}>
        <option value="">Select…</option>
        {list.map((o) => <option key={o} value={o}>{o}</option>)}
      </select>
    );
  } else if (field.type === "yesno") {
    control = (
      <div className="inline-flex gap-1.5">
        {["Yes", "No", "N/A"].map((o) => (
          <button key={o} disabled={readOnly} onClick={() => onChange(o)}
            className="rounded-full px-4 py-1.5 text-[12px] font-bold transition"
            style={value === o
              ? { background: NAVY, color: "#fff", boxShadow: "0 4px 12px rgba(30,39,73,0.28)" }
              : { background: "#fff", color: MUTED, border: `1px solid ${HAIR}` }}>{o}</button>
        ))}
      </div>
    );
  } else if (field.type === "measurement") {
    const v = value || { v: "", u: "m²" };
    control = (
      <div className="flex gap-2">
        <input type="number" step="0.1" disabled={readOnly} className={inputCls} style={inputStyle(readOnly)} value={v.v ?? ""}
          onChange={(e) => onChange({ ...v, v: e.target.value === "" ? null : Number(e.target.value) })} placeholder="0.0" />
        <select disabled={readOnly} className={`${inputCls} w-24`} style={inputStyle(readOnly)} value={v.u} onChange={(e) => onChange({ ...v, u: e.target.value })}>
          <option>m²</option><option>ft²</option><option>m</option><option>ft</option>
        </select>
      </div>
    );
  } else if (field.type === "notes" || field.type === "multiline") {
    control = <textarea rows={3} disabled={readOnly} className={inputCls} style={inputStyle(readOnly)} value={value ?? ""} onChange={(e) => onChange(e.target.value)} />;
  } else if (field.type === "number" || field.type === "decimal") {
    control = <input type="number" step={field.type === "decimal" ? "0.01" : "1"} min="0" disabled={readOnly} className={inputCls} style={inputStyle(readOnly)}
      value={value ?? ""} onChange={(e) => onChange(e.target.value === "" ? null : Math.max(0, Number(e.target.value)))} />;
  } else if (field.type === "date") {
    control = <input type="date" disabled={readOnly} className={inputCls} style={inputStyle(readOnly)} value={value ?? ""} onChange={(e) => onChange(e.target.value)} />;
  } else if (field.type === "file") {
    control = <div className="rounded-2xl border border-dashed px-3.5 py-2.5 text-xs" style={{ borderColor: HAIR, color: MUTED }}>Upload from the Documents tab</div>;
  } else {
    control = <input type="text" disabled={readOnly} className={inputCls} style={inputStyle(readOnly)} value={value ?? ""} onChange={(e) => onChange(e.target.value)} />;
  }

  return (
    <div>
      <div className="mb-1.5 flex items-center gap-1.5">
        <label className="text-[12px] font-bold" style={{ color: NAVY }}>{field.label}</label>
        {field.required && <Star size={9} fill={AMBER} color={AMBER} />}
        {field.help && (
          <button onClick={() => setHelp(!help)} style={{ color: MUTED }} className="hover:opacity-70"><HelpCircle size={13} /></button>
        )}
      </div>
      {help && <div className="mb-1.5 rounded-2xl px-3.5 py-2 text-[11px] font-semibold" style={{ background: "rgba(246,194,68,0.2)", color: "#8A6A10" }}>{field.help}</div>}
      {control}
      {field.unit && <div className="mt-1 text-[11px]" style={{ color: MUTED }}>Recorded in {field.unit}</div>}
      {missingReq && !readOnly && <div className="mt-1 text-[11px] font-semibold" style={{ color: RED }}>Complete this before submitting.</div>}
      {emailBad && <div className="mt-1 text-[11px] font-semibold" style={{ color: RED }}>Enter a valid email address.</div>}
      {postBad && <div className="mt-1 text-[11px] font-semibold" style={{ color: RED }}>This does not look like a UK postcode.</div>}
    </div>
  );
}

function Modal({ title, children, onClose, wide }) {
  return (
    <div className="fixed inset-0 z-50 flex items-start justify-center overflow-y-auto p-6"
      style={{ background: "rgba(21,27,54,0.55)", backdropFilter: "blur(6px)" }}>
      <div className={`mt-8 w-full ${wide ? "max-w-4xl" : "max-w-xl"} rounded-[28px] bg-white`}
        style={{ boxShadow: "0 30px 70px rgba(21,27,54,0.4)" }}>
        <div className="flex items-center justify-between px-7 py-5" style={{ borderBottom: `1px solid ${HAIR}` }}>
          <h3 className="text-[18px] font-bold" style={{ fontFamily: DISPLAY, color: INK }}>{title}</h3>
          <button onClick={onClose} className="flex h-8 w-8 items-center justify-center rounded-full transition hover:brightness-110" style={{ background: NAVY, color: "#fff" }}><X size={15} /></button>
        </div>
        <div className="max-h-[70vh] overflow-y-auto px-7 py-5">{children}</div>
      </div>
    </div>
  );
}

/* Pill chip tabs */
function PillTabs({ tabs, value, onChange }) {
  return (
    <div className="flex flex-wrap gap-2">
      {tabs.map((t) => {
        const active = value === t.id;
        return (
          <button key={t.id} onClick={() => onChange(t.id)}
            className="rounded-full px-4 py-2 text-[12px] font-extrabold transition active:scale-95"
            style={active
              ? { background: NAVY, color: "#fff", boxShadow: "0 6px 16px rgba(30,39,73,0.30)" }
              : { background: "#fff", color: MUTED, border: `1px solid ${HAIR}` }}>
            {t.label}
          </button>
        );
      })}
    </div>
  );
}

/* ============================================================
   MAIN APPLICATION
   ============================================================ */
export default function LondonPropertyHub() {
  const [role, setRole] = useState(null);
  const [identity, setIdentity] = useState(null);
  const [view, setView] = useState("dashboard");
  const [selected, setSelected] = useState(null);
  const [properties, setProperties] = useState(SEED);
  const [customFields, setCustomFields] = useState([
    { id: "cf_boilers", section: "building", label: "Number of boilers", type: "number", required: false, custom: true, help: "Added by Corporate Admin, July 2026." },
  ]);
  const [options, setOptions] = useState(INITIAL_OPTIONS);
  const [filters, setFilters] = useState({ scope: "Entire Company", borough: "", council: "", region: "", propertyType: "", verification: "", q: "" });
  const [toast, setToast] = useState(null);
  const [flags, setFlags] = useState([]);
  const [showFilters, setShowFilters] = useState(false);

  const fields = useMemo(() => [...BASE_FIELDS, ...customFields], [customFields]);
  const notify = (msg) => { setToast(msg); setTimeout(() => setToast(null), 3200); };

  const isAdmin = role === "Corporate Administrator";
  const isManager = role === "Property Manager";
  const isLeadership = role === "Leadership";
  const canEditProperty = (p) => isAdmin || (isManager && p.values.manager === identity);

  const visible = useMemo(() => {
    if (isManager) return properties.filter((p) => p.values.manager === identity);
    return properties;
  }, [properties, role, identity]);

  const filtered = useMemo(() => {
    return visible.filter((p) => {
      if (filters.borough && p.values.borough !== filters.borough) return false;
      if (filters.council && p.values.council !== filters.council) return false;
      if (filters.region && p.values.region !== filters.region) return false;
      if (filters.propertyType && p.values.propertyType !== filters.propertyType) return false;
      if (filters.verification && p.verification !== filters.verification) return false;
      if (filters.q) {
        const hay = [p.values.siteName, p.values.propertyName, p.values.addressLine1, p.values.city,
          p.values.postcode, p.values.borough, p.values.council, p.values.region, p.values.manager]
          .filter(Boolean).join(" ").toLowerCase();
        if (!hay.includes(filters.q.toLowerCase())) return false;
      }
      return true;
    });
  }, [visible, filters]);

  const filterActive = filters.borough || filters.council || filters.region || filters.propertyType || filters.verification || filters.q;

  function updateProperty(id, updater, historyEntry) {
    setProperties((prev) => prev.map((p) => {
      if (p.id !== id) return p;
      const next = updater({ ...p });
      if (historyEntry) {
        next.history = [{ id: Math.random().toString(36).slice(2, 9), date: stamp(), by: identity, approval: "Pending", ...historyEntry }, ...p.history];
      }
      return next;
    }));
  }

  function setFieldValue(p, fieldId, value, label) {
    const prev = p.values[fieldId];
    const show = (v) => (v === null || v === undefined || v === "" ? "—" : typeof v === "object" ? `${v.v ?? "—"} ${v.u}` : String(v));
    if (show(prev) === show(value)) return;
    updateProperty(p.id, (d) => ({
      ...d,
      values: { ...d.values, [fieldId]: value },
      verification: d.verification === "Not Started" ? "In Progress" : d.verification,
    }), { field: label, prev: show(prev), next: show(value), reason: isManager ? "Property manager verification" : "Corporate administrator edit" });
  }

  function setAccom(p, key, value, label) {
    const prev = num(p.accommodation[key]);
    const nextVal = value === "" || value === null ? null : Math.max(0, Number(value));
    if (prev === num(nextVal)) return;
    const changed = Math.abs(num(nextVal) - prev);
    const big = prev > 0 && changed >= 10 && changed / prev >= 0.5;
    updateProperty(p.id, (d) => ({
      ...d,
      accommodation: { ...d.accommodation, [key]: nextVal },
      verification: d.verification === "Not Started" ? "In Progress" : d.verification,
    }), { field: label, prev: String(prev), next: String(num(nextVal)), reason: isManager ? "Property manager verification" : "Corporate administrator edit" });
    if (big) setFlags((f) => [...f.filter((x) => !(x.pid === p.id && x.key === key)), { pid: p.id, key, label, prev, next: num(nextVal) }]);
  }

  const agg = useMemo(() => {
    const a = { properties: filtered.length, units: 0, singles: 0, doubles: 0, triples: 0, flats: 0, houses: 0, lifts: 0, accessibleRooms: 0, verified: 0, awaiting: 0, wcSc: 0 };
    filtered.forEach((p) => {
      a.units += accomTotal(p.accommodation);
      a.singles += num(p.accommodation.singles);
      a.doubles += num(p.accommodation.doubles);
      a.triples += num(p.accommodation.triples);
      a.wcSc += num(p.accommodation.wcSc);
      FLAT_KEYS.forEach((k) => (a.flats += num(p.accommodation[k])));
      HOUSE_KEYS.forEach((k) => (a.houses += num(p.accommodation[k])));
      a.lifts += p.elevators.length;
      a.accessibleRooms += num(p.values.accessibleBedroomCount);
      if (p.verification === "Verified") a.verified += 1; else a.awaiting += 1;
    });
    a.avgComplete = filtered.length ? Math.round(filtered.reduce((s, p) => s + completeness(p, fields), 0) / filtered.length) : 0;
    return a;
  }, [filtered, fields]);

  const reportRows = (set) => set.map((p) => ({
    Site: p.values.siteName || "",
    Address: [p.values.addressLine1, p.values.addressLine2, p.values.city, p.values.postcode].filter(Boolean).join(", "),
    Borough: p.values.borough || "", Council: p.values.council || "", Region: p.values.region || "",
    "Property type": p.values.propertyType || "",
    Singles: num(p.accommodation.singles), Doubles: num(p.accommodation.doubles), Triples: num(p.accommodation.triples),
    "WC SC units": num(p.accommodation.wcSc),
    Flats: FLAT_KEYS.reduce((s, k) => s + num(p.accommodation[k]), 0),
    Houses: HOUSE_KEYS.reduce((s, k) => s + num(p.accommodation[k]), 0),
    "Total units": accomTotal(p.accommodation),
    Elevators: p.elevators.length, Staircases: p.staircases.length,
    "Accessible bedrooms": num(p.values.accessibleBedroomCount),
    "Step-free entrance": p.values.stepFree || "",
    Manager: p.values.manager || "",
    "Verification status": p.verification,
    "Completeness %": completeness(p, fields),
    "Last updated": p.history[0]?.date || "—",
  }));

  function download(blob, filename) {
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url; a.download = filename; a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }
  function exportCSV(set, name = "london-portfolio") {
    const rows = reportRows(set);
    const head = Object.keys(rows[0] || { Site: "" });
    const csv = [head.join(","), ...rows.map((r) => head.map((h) => `"${String(r[h] ?? "").replace(/"/g, '""')}"`).join(","))].join("\n");
    download(new Blob([csv], { type: "text/csv;charset=utf-8;" }), `${name}.csv`);
    notify(`Exported ${rows.length} properties to CSV.`);
  }
  function exportXLSX(set, name = "london-portfolio") {
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(reportRows(set)), "Portfolio");
    const summary = [
      { Metric: "Properties", Value: set.length },
      { Metric: "Total accommodation units", Value: set.reduce((s, p) => s + accomTotal(p.accommodation), 0) },
      { Metric: "Total elevators", Value: set.reduce((s, p) => s + p.elevators.length, 0) },
      { Metric: "Verified properties", Value: set.filter((p) => p.verification === "Verified").length },
      { Metric: "Filter applied", Value: filterActive ? "Yes" : "Entire company" },
      { Metric: "Generated", Value: stamp() },
    ];
    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(summary), "Summary");
    const out = XLSX.write(wb, { bookType: "xlsx", type: "array" });
    download(new Blob([out], { type: "application/octet-stream" }), `${name}.xlsx`);
    notify(`Exported ${set.length} properties to Excel.`);
  }
  function exportPDF(set) {
    const rows = reportRows(set);
    const head = Object.keys(rows[0] || {});
    const html = `<html><head><title>London Hotel Group — Portfolio Report</title>
      <style>body{font-family:Georgia,serif;padding:32px;color:#1E2749}
      h1{font-size:22px;margin:0}p{color:#8A8FA8;font-size:12px;font-family:Arial}
      table{border-collapse:collapse;width:100%;font-size:10px;margin-top:16px;font-family:Arial}
      th{background:#1E2749;color:#fff;text-align:left;padding:7px 6px}
      td{border-bottom:1px solid rgba(30,39,73,0.12);padding:6px}</style></head><body>
      <h1>London Hotel Group — Property Portfolio Report</h1>
      <p>${set.length} properties · ${fmt(set.reduce((s, p) => s + accomTotal(p.accommodation), 0))} accommodation units · Generated ${stamp()}${filterActive ? " · Filters applied" : ""}</p>
      <table><thead><tr>${head.map((h) => `<th>${h}</th>`).join("")}</tr></thead>
      <tbody>${rows.map((r) => `<tr>${head.map((h) => `<td>${r[h] ?? ""}</td>`).join("")}</tr>`).join("")}</tbody></table>
      <script>window.onload=()=>window.print()<\/script></body></html>`;
    const w = window.open("", "_blank");
    if (!w) { notify("Pop-up blocked. Allow pop-ups to print to PDF, or export Excel instead."); return; }
    w.document.write(html); w.document.close();
    notify("Print dialog opened — choose 'Save as PDF'.");
  }

  /* ---------------------------- Login ---------------------------- */
  if (!role) {
    const roles = [
      { name: "Corporate Administrator", who: "Priya Raman", desc: "Full access. Creates properties, adds fields, approves submissions, exports.", icon: Shield },
      { name: "Property Manager", who: "Jane Smith", desc: "Croydon Housing. Reviews, corrects and submits their own property record.", icon: PencilLine },
      { name: "Leadership", who: "Meher N.", desc: "Read-only. Dashboards, filters, search, reports and exports.", icon: Eye },
    ];
    return (
      <div style={{ fontFamily: BODY, background: "#262B3F" }} className="flex min-h-screen items-center justify-center p-5">
        <FontLoader />
        <div className="w-full max-w-lg overflow-hidden rounded-[36px]" style={{ background: LAV, boxShadow: "0 30px 80px rgba(0,0,0,0.45)" }}>
          {/* Navy hero — like the reference header */}
          <div className="p-7 sm:p-9" style={{ background: `linear-gradient(160deg, #2A3560, ${NAVY} 60%, ${NAVY_DK})` }}>
            <div className="flex items-center justify-between">
              <div className="flex items-center gap-3">
                <div className="flex h-11 w-11 items-center justify-center rounded-full" style={{ background: AMBER }}>
                  <Building2 size={20} color={NAVY_DK} />
                </div>
                <div>
                  <div className="text-[13px] font-extrabold text-white">London Hotel Group</div>
                  <div className="text-[10px] text-white/60">Property Information Hub</div>
                </div>
              </div>
              <Bell size={19} color="#fff" />
            </div>
            <h1 className="mt-6 text-[30px] font-bold leading-[1.15] text-white" style={{ fontFamily: DISPLAY }}>
              One Accurate Record<br />for Every Property
            </h1>
            <p className="mt-2 text-[12px] leading-relaxed text-white/70">
              We make sure every unit count, lift and staircase<br />is verified by the people on the ground.
            </p>
          </div>

          {/* Role list — service-card style */}
          <div className="p-6 sm:p-7">
            <h2 className="text-[17px] font-bold" style={{ fontFamily: DISPLAY, color: INK }}>Choose your role</h2>
            <div className="mt-3 space-y-3">
              {roles.map((r) => (
                <button key={r.name} onClick={() => { setRole(r.name); setIdentity(r.who); setView("dashboard"); }}
                  className="group flex w-full items-center gap-4 rounded-[22px] bg-white p-3.5 text-left transition hover:-translate-y-0.5 active:scale-[0.99]"
                  style={{ boxShadow: "0 8px 22px rgba(30,39,73,0.10)" }}>
                  <div className="flex h-14 w-14 shrink-0 items-center justify-center rounded-[18px]" style={{ background: AMBER, boxShadow: "0 6px 14px rgba(245,166,35,0.4)" }}>
                    <r.icon size={22} color={NAVY_DK} />
                  </div>
                  <div className="min-w-0 flex-1">
                    <div className="text-[13px] font-extrabold" style={{ color: INK }}>{r.name}</div>
                    <div className="text-[11px] italic" style={{ color: MUTED }}>by: {r.who}</div>
                    <div className="mt-0.5 truncate text-[11px]" style={{ color: "#5C6180" }}>{r.desc}</div>
                  </div>
                  <div className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full transition group-hover:translate-x-0.5" style={{ background: NAVY_DK }}>
                    <ChevronRight size={16} color="#fff" />
                  </div>
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    );
  }

  /* ---------------------------- Shell ---------------------------- */
  const nav = [
    { id: "dashboard", label: "Home", icon: LayoutDashboard },
    { id: "directory", label: "Properties", icon: Building2 },
    { id: "search", label: "Explore", icon: Search },
    { id: "approvals", label: "Approvals", icon: ClipboardCheck, hide: isLeadership },
    { id: "reports", label: "Reports", icon: FileBarChart },
    { id: "import", label: "Import", icon: Upload, hide: !isAdmin },
    { id: "admin", label: "Fields", icon: Settings2, hide: !isAdmin },
  ].filter((n) => !n.hide);

  const selectedProp = properties.find((p) => p.id === selected);
  const initials = identity ? identity.split(" ").map((w) => w[0]).join("").slice(0, 2).toUpperCase() : "";
  const heroTitles = {
    dashboard: ["Best Overview of", "Your Portfolio"],
    directory: ["Every Property,", "One Record Each"],
    search: ["Find Anything in", "Your Portfolio"],
    approvals: ["Verified by the", "People on the Ground"],
    reports: ["Board-Ready in", "One Export"],
    import: ["Bring Legacy Data", "Into the Fold"],
    admin: ["Shape the Record", "As You Grow"],
  };
  const heroTitle = selected ? null : heroTitles[view] || heroTitles.dashboard;

  return (
    <div style={{ fontFamily: BODY, background: "#262B3F", color: INK }} className="min-h-screen p-0 antialiased sm:p-4">
      <FontLoader />
      <div className="mx-auto min-h-screen max-w-[1200px] overflow-hidden sm:min-h-[calc(100vh-32px)] sm:rounded-[36px]" style={{ background: LAV }}>

        {/* ---- Navy hero header — like the reference ---- */}
        <header className="relative overflow-hidden px-5 pb-7 pt-6 sm:rounded-b-[36px] sm:px-8"
          style={{ background: `linear-gradient(160deg, #2A3560, ${NAVY} 55%, ${NAVY_DK})` }}>
          {/* soft decorative blobs */}
          <div className="pointer-events-none absolute -right-16 -top-20 h-56 w-56 rounded-full" style={{ background: "rgba(255,255,255,0.05)" }} />
          <div className="pointer-events-none absolute -left-10 top-24 h-40 w-40 rounded-full" style={{ background: "rgba(245,166,35,0.08)" }} />

          <div className="relative flex items-center justify-between">
            <div className="flex items-center gap-3">
              <div className="flex h-11 w-11 items-center justify-center rounded-full text-[13px] font-extrabold"
                style={{ background: AMBER, color: NAVY_DK, boxShadow: "0 4px 12px rgba(245,166,35,0.4)" }}>
                {initials}
              </div>
              <div>
                <div className="text-[13px] font-extrabold text-white">{identity}</div>
                <div className="flex items-center gap-1 text-[10px] text-white/60">
                  <MapPin size={9} />{role} · London Portfolio
                </div>
              </div>
            </div>
            <button onClick={() => { setRole(null); setSelected(null); setFilters({ scope: "Entire Company", borough: "", council: "", region: "", propertyType: "", verification: "", q: "" }); }}
              title="Switch role" className="flex h-10 w-10 items-center justify-center rounded-full transition hover:bg-white/10 active:scale-95">
              <Bell size={19} color="#fff" />
            </button>
          </div>

          {heroTitle && (
            <>
              <h1 className="relative mt-5 text-[27px] font-bold leading-[1.15] text-white" style={{ fontFamily: DISPLAY }}>
                {heroTitle[0]}<br />{heroTitle[1]}
              </h1>
              <p className="relative mt-1.5 text-[11px] text-white/65">
                We make sure every figure is verified by the expert on the ground
              </p>
            </>
          )}

          {/* Underline search + filter icon — like the reference */}
          <div className="relative mt-5 flex items-center gap-3" style={{ borderBottom: "1.5px solid rgba(255,255,255,0.35)" }}>
            <Search size={17} color="rgba(255,255,255,0.75)" />
            <input
              value={filters.q}
              onChange={(e) => { setFilters((f) => ({ ...f, q: e.target.value })); if (view !== "search" && !selected) { setView("search"); setSelected(null); } }}
              onFocus={() => { if (!selected) setView("search"); }}
              placeholder="Search here"
              className="w-full bg-transparent py-2.5 text-[13px] text-white outline-none placeholder:text-white/50" />
            <button onClick={() => setShowFilters(!showFilters)} title="Filters"
              className="pb-0.5 transition active:scale-90">
              <SlidersHorizontal size={17} color={filterActive ? YELLOW : "rgba(255,255,255,0.75)"} />
            </button>
          </div>
        </header>

        {/* Slide-down filter tray */}
        {showFilters && (
          <div className="px-5 pt-4 sm:px-8">
            <Card className="p-4">
              <FilterBar filters={filters} setFilters={setFilters} options={options} />
            </Card>
          </div>
        )}

        {/* ---- Categories — amber circular icons, like the reference ---- */}
        {!selectedProp && (
          <div className="px-5 pt-5 sm:px-8">
            <SectionTitle>Categories</SectionTitle>
            <div className="scrollbar-none flex gap-4 overflow-x-auto pb-1">
              {nav.map((n) => {
                const active = view === n.id;
                return (
                  <button key={n.id} onClick={() => { setView(n.id); setSelected(null); }}
                    className="flex shrink-0 flex-col items-center gap-1.5 transition active:scale-95">
                    <div className="flex h-[62px] w-[62px] items-center justify-center rounded-full transition"
                      style={active
                        ? { background: NAVY, boxShadow: "0 8px 18px rgba(30,39,73,0.35)" }
                        : { background: AMBER, boxShadow: "0 6px 14px rgba(245,166,35,0.35)" }}>
                      <n.icon size={24} color={active ? YELLOW : NAVY_DK} strokeWidth={2.2} />
                    </div>
                    <span className="text-[11px] font-bold" style={{ color: active ? NAVY : "#5C6180" }}>{n.label}</span>
                  </button>
                );
              })}
            </div>
          </div>
        )}

        {/* ---- Voucher-style banner — navy pill with chevron ---- */}
        {!selectedProp && view === "dashboard" && agg.awaiting > 0 && (
          <div className="px-5 pt-4 sm:px-8">
            <button onClick={() => setView(isLeadership ? "directory" : "approvals")}
              className="flex w-full items-center justify-between rounded-full py-2.5 pl-5 pr-2 transition hover:brightness-110 active:scale-[0.99]"
              style={{ background: NAVY_DK, boxShadow: "0 10px 24px rgba(21,27,54,0.35)" }}>
              <span className="flex items-center gap-2.5 text-[12px] font-extrabold text-white">
                <TicketPercent size={16} color={YELLOW} />
                {agg.awaiting} {agg.awaiting === 1 ? "Property" : "Properties"} Awaiting Verification — Review Now
              </span>
              <span className="flex h-8 w-8 items-center justify-center rounded-full bg-white">
                <ChevronRight size={16} color={NAVY_DK} />
              </span>
            </button>
          </div>
        )}

        {/* ---- Main content ---- */}
        <main className="px-5 pb-36 pt-5 sm:px-8">
          {selectedProp ? (
            <PropertyDetail
              p={selectedProp} fields={fields} options={options} role={role} identity={identity}
              canEdit={canEditProperty(selectedProp)} isAdmin={isAdmin}
              onBack={() => setSelected(null)} setFieldValue={setFieldValue} setAccom={setAccom}
              updateProperty={updateProperty} notify={notify}
              flags={flags.filter((f) => f.pid === selectedProp.id)}
              resolveFlag={(key, revert) => {
                const f = flags.find((x) => x.pid === selectedProp.id && x.key === key);
                if (revert && f) setAccom(selectedProp, key, f.prev, ACCOM.find((a) => a.key === key).label);
                setFlags((all) => all.filter((x) => !(x.pid === selectedProp.id && x.key === key)));
                notify(revert ? "Change reverted to the previous value." : "Change confirmed and recorded.");
              }}
            />
          ) : view === "dashboard" ? (
            <Dashboard agg={agg} filtered={filtered} fields={fields} onOpen={setSelected} filterActive={filterActive} />
          ) : view === "directory" ? (
            <Directory list={filtered} fields={fields} onOpen={setSelected}
              options={options} isAdmin={isAdmin} onCreate={(vals) => {
                const id = "p-" + Math.random().toString(36).slice(2, 7);
                setProperties((prev) => [...prev, { id, verification: "Not Started", values: vals, accommodation: blankAccom(), elevators: [], staircases: [], documents: [], history: [{ id: "n1", field: "Property record", prev: "—", next: "Created", by: identity, date: stamp(), reason: "New property added", approval: "Approved" }] }]);
                notify(`${vals.siteName} added. Send a verification request to populate it.`);
                setSelected(id);
              }} />
          ) : view === "search" ? (
            <SearchScreen list={visible} fields={fields} onOpen={setSelected} q={filters.q} />
          ) : view === "approvals" ? (
            <Approvals list={visible} fields={fields} isAdmin={isAdmin} onOpen={setSelected}
              act={(p, status, comment) => {
                updateProperty(p.id, (d) => ({ ...d, verification: status }), { field: "Verification", prev: p.verification, next: status, reason: comment || "Reviewed by corporate", approval: "Approved" });
                notify(`${p.values.siteName} marked as ${status}.`);
              }}
              request={(p) => {
                updateProperty(p.id, (d) => ({ ...d, verification: "In Progress" }), { field: "Verification", prev: p.verification, next: "In Progress", reason: "Verification requested", approval: "Approved" });
                notify(`Verification requested from ${p.values.manager || "the property manager"}.`);
              }} />
          ) : view === "reports" ? (
            <Reports list={filtered} all={visible} fields={fields}
              rows={reportRows} exportCSV={exportCSV} exportXLSX={exportXLSX} exportPDF={exportPDF}
              filterActive={filterActive} />
          ) : view === "import" ? (
            <ImportScreen properties={properties} fields={fields} notify={notify}
              onImport={(newProps) => { setProperties((prev) => [...prev, ...newProps]); notify(`${newProps.length} properties imported.`); setView("directory"); }} />
          ) : (
            <AdminFields fields={fields} customFields={customFields} setCustomFields={setCustomFields}
              options={options} setOptions={setOptions} notify={notify} />
          )}
        </main>
      </div>

      {/* ---- Bottom nav — navy active pill + grey circles, like the reference ---- */}
      <div className="fixed bottom-4 left-1/2 z-40 flex -translate-x-1/2 items-center gap-3 rounded-full bg-white px-3 py-2"
        style={{ boxShadow: "0 16px 40px rgba(21,27,54,0.30)" }}>
        {nav.slice(0, 4).map((n) => {
          const active = view === n.id && !selected;
          return active ? (
            <button key={n.id} onClick={() => { setView(n.id); setSelected(null); }}
              className="flex items-center gap-2 rounded-full py-2.5 pl-4 pr-5 transition active:scale-95"
              style={{ background: NAVY_DK, boxShadow: "0 8px 18px rgba(21,27,54,0.35)" }}>
              <n.icon size={17} color={YELLOW} />
              <span className="text-[12px] font-extrabold text-white">{n.label}</span>
            </button>
          ) : (
            <button key={n.id} onClick={() => { setView(n.id); setSelected(null); }}
              title={n.label}
              className="flex h-11 w-11 items-center justify-center rounded-full transition active:scale-95 hover:brightness-95"
              style={{ background: "#C9CCDD" }}>
              <n.icon size={18} color="#fff" strokeWidth={2.4} />
            </button>
          );
        })}
      </div>

      {toast && (
        <div className="fixed bottom-24 left-1/2 z-50 -translate-x-1/2 rounded-full px-6 py-3 text-[12px] font-extrabold text-white"
          style={{ background: NAVY_DK, boxShadow: "0 12px 30px rgba(0,0,0,0.35)", maxWidth: "90vw" }}>
          {toast}
        </div>
      )}
    </div>
  );
}

/* ============================================================
   FILTER BAR — pill chips
   ============================================================ */
function FilterBar({ filters, setFilters, options }) {
  const set = (k, v) => setFilters((f) => ({ ...f, [k]: v }));
  const clear = () => setFilters({ scope: "Entire Company", borough: "", council: "", region: "", propertyType: "", verification: "", q: "" });
  const sel = "rounded-full px-4 py-2 text-[12px] font-bold outline-none transition";
  const selStyle = (active) => ({
    background: active ? NAVY : LAV_SOFT, color: active ? "#fff" : "#5C6180",
    border: `1px solid ${active ? NAVY : HAIR}`, appearance: "none", WebkitAppearance: "none",
    paddingRight: "1.9rem",
    backgroundImage: `url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='10' height='6' viewBox='0 0 10 6'%3E%3Cpath d='M1 1l4 4 4-4' stroke='${active ? "%23F6C244" : "%238A8FA8"}' stroke-width='1.6' fill='none' stroke-linecap='round'/%3E%3C/svg%3E")`,
    backgroundRepeat: "no-repeat", backgroundPosition: "right 0.8rem center",
  });
  return (
    <div className="flex flex-wrap items-center gap-2">
      <span className="flex items-center gap-1.5 text-[10px] font-extrabold uppercase tracking-[0.1em]" style={{ color: MUTED }}><Filter size={12} />Scope</span>
      <select className={sel} style={selStyle(!!filters.borough)} value={filters.borough} onChange={(e) => set("borough", e.target.value)}>
        <option value="">All boroughs</option>{options.boroughs.map((o) => <option key={o}>{o}</option>)}
      </select>
      <select className={sel} style={selStyle(!!filters.council)} value={filters.council} onChange={(e) => set("council", e.target.value)}>
        <option value="">All councils</option>{options.councils.map((o) => <option key={o}>{o}</option>)}
      </select>
      <select className={sel} style={selStyle(!!filters.region)} value={filters.region} onChange={(e) => set("region", e.target.value)}>
        <option value="">All regions</option>{options.regions.map((o) => <option key={o}>{o}</option>)}
      </select>
      <select className={sel} style={selStyle(!!filters.propertyType)} value={filters.propertyType} onChange={(e) => set("propertyType", e.target.value)}>
        <option value="">All types</option>{options.propertyTypes.map((o) => <option key={o}>{o}</option>)}
      </select>
      <select className={sel} style={selStyle(!!filters.verification)} value={filters.verification} onChange={(e) => set("verification", e.target.value)}>
        <option value="">All statuses</option>{Object.keys(STATUS_STYLE).map((o) => <option key={o}>{o}</option>)}
      </select>
      <button onClick={clear} className="rounded-full px-4 py-2 text-[12px] font-extrabold transition hover:brightness-105" style={{ background: YELLOW, color: NAVY_DK }}>
        Entire company
      </button>
    </div>
  );
}

/* ============================================================
   DASHBOARD
   ============================================================ */
function Dashboard({ agg, filtered, fields, onOpen, filterActive }) {
  const byBorough = useMemo(() => {
    const m = {};
    filtered.forEach((p) => {
      const b = p.values.borough || "Unassigned";
      m[b] = (m[b] || 0) + accomTotal(p.accommodation);
    });
    return Object.entries(m).map(([name, units]) => ({ name, units })).sort((a, b) => b.units - a.units);
  }, [filtered]);

  const byStatus = useMemo(() => {
    const m = {};
    filtered.forEach((p) => (m[p.verification] = (m[p.verification] || 0) + 1));
    return Object.entries(m).map(([name, value]) => ({ name, value }));
  }, [filtered]);
  const STATUS_HEX = { "Verified": OKGREEN, "In Progress": AMBER, "Submitted": "#3B6FB5", "Changes Requested": "#C0622D", "Not Started": "#9CA1B8", "Overdue": RED, "Needs Review": "#8256B0" };

  const attention = filtered.filter((p) => completeness(p, fields) < 80 || ["Overdue", "Changes Requested", "Not Started"].includes(p.verification));

  return (
    <div>
      {/* Hero stat card — navy, carousel-style */}
      <div className="mb-2 overflow-hidden rounded-[28px] p-6 sm:p-7" style={{ background: `linear-gradient(150deg, #2A3560, ${NAVY} 65%, ${NAVY_DK})`, boxShadow: "0 16px 40px rgba(30,39,73,0.30)" }}>
        <div className="flex flex-wrap items-end justify-between gap-6">
          <div>
            <Chip>TOTAL UNITS</Chip>
            <div className="mt-2 text-[50px] font-bold leading-none text-white" style={{ fontFamily: DISPLAY }}>{fmt(agg.units)}</div>
            <div className="mt-2 flex items-center gap-1.5 text-[11px] italic text-white/65">
              <MapPin size={11} color={YELLOW} />across {agg.properties} {agg.properties === 1 ? "property" : "properties"} · sum of every accommodation type
            </div>
          </div>
          <div className="flex flex-wrap gap-6 sm:gap-8">
            {[["Singles", agg.singles], ["Doubles", agg.doubles], ["Triples", agg.triples], ["Flats", agg.flats], ["Houses", agg.houses]].map(([l, v]) => (
              <div key={l} className="text-right">
                <div className="text-[22px] font-bold text-white" style={{ fontFamily: DISPLAY }}>{fmt(v)}</div>
                <div className="text-[10px] font-bold uppercase tracking-[0.08em]" style={{ color: "rgba(255,255,255,0.5)" }}>{l}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
      {/* carousel dots */}
      <div className="mb-5 flex justify-center gap-1.5">
        <span className="h-1.5 w-1.5 rounded-full" style={{ background: NAVY }} />
        <span className="h-1.5 w-4 rounded-full" style={{ background: NAVY }} />
        <span className="h-1.5 w-1.5 rounded-full" style={{ background: "#B9BDD2" }} />
      </div>

      {filterActive && (
        <div className="mb-4"><Chip>★ Filters applied — every figure reflects this selection</Chip></div>
      )}

      <div className="grid grid-cols-2 gap-3 md:grid-cols-3 xl:grid-cols-6">
        <Kpi label="Properties" value={fmt(agg.properties)} />
        <Kpi label="WC SC Units" value={fmt(agg.wcSc)} />
        <Kpi label="Elevators" value={fmt(agg.lifts)} />
        <Kpi label="Accessible Beds" value={fmt(agg.accessibleRooms)} />
        <Kpi label="Verified" value={`${agg.verified} of ${agg.properties}`} tone={OKGREEN} />
        <Kpi label="Awaiting" value={fmt(agg.awaiting)} tone={agg.awaiting ? RED : INK} />
      </div>

      <div className="mt-6">
        <SectionTitle right={<span className="text-[11px] font-bold" style={{ color: MUTED }}>Live totals ▾</span>}>Units by Borough</SectionTitle>
        <div className="grid gap-4 lg:grid-cols-3">
          <Card className="p-5 lg:col-span-2">
            <div style={{ height: 250 }}>
              <ResponsiveContainer>
                <BarChart data={byBorough} margin={{ top: 8, right: 8, left: -12, bottom: 4 }}>
                  <CartesianGrid strokeDasharray="0" stroke="rgba(30,39,73,0.06)" vertical={false} />
                  <XAxis dataKey="name" tick={{ fontSize: 11, fill: MUTED, fontFamily: BODY }} interval={0} angle={-18} textAnchor="end" height={54} axisLine={false} tickLine={false} />
                  <YAxis tick={{ fontSize: 11, fill: MUTED, fontFamily: BODY }} axisLine={false} tickLine={false} />
                  <Tooltip contentStyle={{ fontSize: 12, borderRadius: 16, border: "none", boxShadow: "0 8px 24px rgba(30,39,73,0.18)", fontFamily: BODY }} cursor={{ fill: "rgba(30,39,73,0.04)" }} />
                  <Bar dataKey="units" fill={NAVY} radius={[10, 10, 10, 10]} name="Units" maxBarSize={42} />
                </BarChart>
              </ResponsiveContainer>
            </div>
          </Card>
          <Card className="p-5">
            <div className="mb-1 text-[14px] font-bold" style={{ fontFamily: DISPLAY }}>Verification Status</div>
            <div style={{ height: 172 }}>
              <ResponsiveContainer>
                <PieChart>
                  <Pie data={byStatus} dataKey="value" nameKey="name" innerRadius={45} outerRadius={68} paddingAngle={3} cornerRadius={6}>
                    {byStatus.map((e) => <Cell key={e.name} fill={STATUS_HEX[e.name] || "#9CA1B8"} />)}
                  </Pie>
                  <Tooltip contentStyle={{ fontSize: 12, borderRadius: 16, border: "none", boxShadow: "0 8px 24px rgba(30,39,73,0.18)", fontFamily: BODY }} />
                </PieChart>
              </ResponsiveContainer>
            </div>
            <div className="space-y-1.5">
              {byStatus.map((s) => (
                <div key={s.name} className="flex items-center justify-between text-[11px] font-semibold">
                  <span className="flex items-center gap-2" style={{ color: "#5C6180" }}>
                    <span className="h-2 w-2 rounded-full" style={{ background: STATUS_HEX[s.name] }} />{s.name}
                  </span>
                  <span className="font-extrabold">{s.value}</span>
                </div>
              ))}
            </div>
          </Card>
        </div>
      </div>

      <div className="mt-6">
        <SectionTitle right={<span className="text-[11px] font-bold" style={{ color: MUTED }}>More ▾</span>}>Needs Attention</SectionTitle>
        <div className="grid gap-4 lg:grid-cols-3">
          <Card className="p-5">
            <div className="text-[14px] font-bold" style={{ fontFamily: DISPLAY }}>Average Completeness</div>
            <div className="mt-4 flex items-center gap-5">
              <Ring pct={agg.avgComplete} size={76} stroke={8} />
              <div className="text-[12px] leading-relaxed" style={{ color: MUTED }}>
                Across {agg.properties} properties in this view.<br />
                <span className="font-extrabold" style={{ color: attention.length ? RED : OKGREEN }}>
                  {attention.length} {attention.length === 1 ? "property needs" : "properties need"} attention.
                </span>
              </div>
            </div>
          </Card>
          <Card className="p-4 lg:col-span-2">
            {attention.length === 0 ? (
              <div className="py-6 text-center text-[13px]" style={{ color: MUTED }}>Every property in this view is verified and complete.</div>
            ) : (
              <div className="space-y-2.5">
                {attention.map((p) => (
                  <button key={p.id} onClick={() => onOpen(p.id)}
                    className="group flex w-full items-center gap-3.5 rounded-[20px] p-2.5 text-left transition hover:-translate-y-0.5"
                    style={{ background: LAV_SOFT, border: `1px solid ${HAIR}` }}>
                    {/* mini media square */}
                    <div className="flex h-[52px] w-[52px] shrink-0 flex-col items-center justify-center rounded-[16px]" style={{ background: `linear-gradient(150deg, #2A3560, ${NAVY})` }}>
                      <span className="text-[15px] font-bold leading-none text-white" style={{ fontFamily: DISPLAY }}>{fmt(accomTotal(p.accommodation))}</span>
                      <span className="text-[7px] font-bold uppercase tracking-[0.08em] text-white/55">units</span>
                    </div>
                    <div className="min-w-0 flex-1">
                      <div className="truncate text-[13px] font-extrabold" style={{ color: INK }}>{p.values.siteName}</div>
                      <div className="flex items-center gap-1 text-[11px] italic" style={{ color: MUTED }}>by: {p.values.manager || "Unassigned"}</div>
                    </div>
                    <div className="flex items-center gap-2.5">
                      <Chip>{completeness(p, fields)}%</Chip>
                      <StatusPill status={p.verification} small />
                      <ChevronRight size={15} color={MUTED} className="transition group-hover:translate-x-0.5" />
                    </div>
                  </button>
                ))}
              </div>
            )}
          </Card>
        </div>
      </div>
    </div>
  );
}

/* ============================================================
   DIRECTORY — service-card list, like "Recommended Service"
   ============================================================ */
function Directory({ list, fields, onOpen, options, isAdmin, onCreate }) {
  const [creating, setCreating] = useState(false);
  const [draft, setDraft] = useState({ siteName: "", propertyName: "", addressLine1: "", city: "", postcode: "", borough: "", council: "", region: "", propertyType: "", manager: "", managerEmail: "", operationalStatus: "Open" });

  return (
    <div>
      <SectionTitle right={isAdmin && <Btn size="sm" variant="amber" onClick={() => setCreating(true)}><Plus size={14} />Add Property</Btn>}>
        All Properties
      </SectionTitle>

      <div className="grid gap-4 lg:grid-cols-2">
        {list.map((p) => {
          const pct = completeness(p, fields);
          return (
            <button key={p.id} onClick={() => onOpen(p.id)}
              className="group flex items-stretch gap-4 rounded-[24px] bg-white p-3.5 text-left transition hover:-translate-y-0.5"
              style={{ boxShadow: "0 8px 24px rgba(30,39,73,0.09)" }}>
              {/* Media square — navy gradient stat panel, like the photo thumbnail */}
              <div className="flex h-[104px] w-[104px] shrink-0 flex-col items-center justify-center gap-1 rounded-[18px]"
                style={{ background: `linear-gradient(150deg, #2A3560, ${NAVY} 70%)` }}>
                <div className="text-[26px] font-bold leading-none text-white" style={{ fontFamily: DISPLAY }}>{fmt(accomTotal(p.accommodation))}</div>
                <div className="text-[8px] font-extrabold uppercase tracking-[0.12em] text-white/55">Total Units</div>
                <div className="mt-1 flex gap-2 text-[9px] font-bold text-white/70">
                  <span>{p.elevators.length} lifts</span>·<span>{p.values.floors ?? "—"} fl</span>
                </div>
              </div>
              {/* Body */}
              <div className="flex min-w-0 flex-1 flex-col justify-between py-0.5">
                <div>
                  <div className="flex items-start justify-between gap-2">
                    <div className="truncate text-[15px] font-bold" style={{ fontFamily: DISPLAY, color: INK }}>{p.values.siteName}</div>
                    <Bookmark size={15} color="#C9CCDD" className="mt-0.5 shrink-0" />
                  </div>
                  <div className="mt-1.5 flex flex-wrap items-center gap-1.5">
                    <Chip>{p.values.borough || "—"}</Chip>
                    <StatusPill status={p.verification} small />
                  </div>
                </div>
                <div className="flex items-end justify-between gap-2">
                  <div className="truncate text-[11px] italic" style={{ color: MUTED }}>by: {p.values.manager || "Unassigned"}</div>
                  <div className="flex items-center gap-1 text-[11px] font-extrabold" style={{ color: pctColor(pct) }}>{pct}% complete</div>
                </div>
              </div>
            </button>
          );
        })}
        {list.length === 0 && (
          <Card className="p-12 text-center text-[13px] lg:col-span-2" style={{ color: MUTED }}>
            No properties match these filters. Reset the scope to see the whole company.
          </Card>
        )}
      </div>

      {creating && (
        <Modal title="Add a Property" onClose={() => setCreating(false)}>
          <div className="grid gap-4 sm:grid-cols-2">
            {["siteName", "propertyName", "addressLine1", "city", "postcode", "manager", "managerEmail"].map((id) => {
              const f = BASE_FIELDS.find((x) => x.id === id);
              return <Field key={id} field={f} value={draft[id]} options={options} onChange={(v) => setDraft({ ...draft, [id]: v })} />;
            })}
            {["borough", "council", "region", "propertyType"].map((id) => {
              const f = BASE_FIELDS.find((x) => x.id === id);
              return <Field key={id} field={f} value={draft[id]} options={options} onChange={(v) => setDraft({ ...draft, [id]: v })} />;
            })}
          </div>
          <div className="mt-5 flex justify-end gap-2">
            <Btn variant="subtle" onClick={() => setCreating(false)}>Cancel</Btn>
            <Btn variant="amber" disabled={!draft.siteName || !draft.borough} onClick={() => { onCreate(draft); setCreating(false); }}>Create Property</Btn>
          </div>
        </Modal>
      )}
    </div>
  );
}

/* ============================================================
   SEARCH ("Explore")
   ============================================================ */
function SearchScreen({ list, fields, onOpen, q }) {
  const results = (q || "").trim() === "" ? list : list.filter((p) => {
    const hay = [p.values.siteName, p.values.propertyName, p.values.addressLine1, p.values.addressLine2,
      p.values.city, p.values.postcode, p.values.borough, p.values.council, p.values.region, p.values.manager]
      .filter(Boolean).join(" ").toLowerCase();
    return hay.includes(q.toLowerCase());
  });
  return (
    <div>
      <SectionTitle right={<span className="text-[11px] font-bold" style={{ color: MUTED }}>{results.length} {results.length === 1 ? "result" : "results"}</span>}>
        {q ? `Results for "${q}"` : "Explore the Portfolio"}
      </SectionTitle>
      <div className="mb-4 text-[12px]" style={{ color: MUTED }}>
        {q ? "Matching name, site, address, borough, council, region or manager." : "Use the search bar in the header, or browse every property you can see."}
      </div>
      <div className="grid gap-4 lg:grid-cols-2">
        {results.map((p) => (
          <button key={p.id} onClick={() => onOpen(p.id)}
            className="flex items-stretch gap-4 rounded-[24px] bg-white p-3.5 text-left transition hover:-translate-y-0.5"
            style={{ boxShadow: "0 8px 24px rgba(30,39,73,0.09)" }}>
            <div className="flex h-[96px] w-[96px] shrink-0 flex-col items-center justify-center gap-0.5 rounded-[18px]"
              style={{ background: `linear-gradient(150deg, #2A3560, ${NAVY} 70%)` }}>
              <Ring pct={completeness(p, fields)} size={54} stroke={6} light />
            </div>
            <div className="flex min-w-0 flex-1 flex-col justify-between py-0.5">
              <div>
                <div className="truncate text-[15px] font-bold" style={{ fontFamily: DISPLAY, color: INK }}>{p.values.siteName}</div>
                <div className="mt-0.5 flex items-center gap-1 truncate text-[11px]" style={{ color: MUTED }}>
                  <MapPin size={10} color={AMBER} />{[p.values.addressLine1, p.values.city, p.values.postcode].filter(Boolean).join(", ")}
                </div>
                <div className="mt-1.5 flex flex-wrap gap-1.5">
                  <Chip>{fmt(accomTotal(p.accommodation))} units</Chip>
                  <Chip tone="soft">{p.elevators.length} lifts</Chip>
                </div>
              </div>
              <div className="flex items-end justify-between">
                <span className="text-[11px] italic" style={{ color: MUTED }}>by: {p.values.manager || "Unassigned"}</span>
                <StatusPill status={p.verification} small />
              </div>
            </div>
          </button>
        ))}
      </div>
      {q && results.length === 0 && (
        <Card className="p-12 text-center text-[13px]" style={{ color: MUTED }}>Nothing matches "{q}". Try a borough, postcode or manager name.</Card>
      )}
    </div>
  );
}

/* ============================================================
   APPROVALS
   ============================================================ */
function Approvals({ list, fields, isAdmin, onOpen, act, request }) {
  const [comment, setComment] = useState({});
  const submitted = list.filter((p) => p.verification === "Submitted");
  const others = list.filter((p) => p.verification !== "Submitted");
  return (
    <div>
      <SectionTitle>Approvals</SectionTitle>
      <p className="mb-5 text-[12px]" style={{ color: MUTED }}>Review what property managers have submitted, then approve it or send it back with a comment.</p>

      <Card className="mb-5 p-5 sm:p-6">
        <div className="mb-4 flex items-center gap-2 text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>
          <ClipboardCheck size={16} color={AMBER} />Awaiting Review · {submitted.length}
        </div>
        {submitted.length === 0 ? (
          <div className="py-6 text-center text-[13px]" style={{ color: MUTED }}>Nothing is waiting for review. Request verification below to start a round.</div>
        ) : submitted.map((p) => (
          <div key={p.id} className="mb-3 rounded-[20px] p-4" style={{ background: LAV_SOFT, border: `1px solid ${HAIR}` }}>
            <div className="flex flex-wrap items-center justify-between gap-2">
              <button onClick={() => onOpen(p.id)} className="text-[14px] font-extrabold underline-offset-2 hover:underline" style={{ color: NAVY }}>{p.values.siteName}</button>
              <div className="flex items-center gap-2">
                <Chip>{completeness(p, fields)}%</Chip>
                <span className="text-[11px] italic" style={{ color: MUTED }}>by: {p.values.manager}</span>
              </div>
            </div>
            <div className="mt-2 text-[12px]" style={{ color: "#5C6180" }}>{p.history.length} recorded changes in this round. Most recent: {p.history[0]?.field} — {p.history[0]?.prev} → {p.history[0]?.next}</div>
            {isAdmin && (
              <div className="mt-3 flex flex-wrap items-center gap-2">
                <input value={comment[p.id] || ""} onChange={(e) => setComment({ ...comment, [p.id]: e.target.value })}
                  placeholder="Add a comment for the property manager"
                  className="min-w-[220px] flex-1 rounded-full bg-white px-4 py-2 text-[12px] outline-none transition focus:ring-2"
                  style={{ border: `1px solid ${HAIR}`, "--tw-ring-color": "rgba(30,39,73,0.3)" }} />
                <Btn size="sm" variant="amber" onClick={() => act(p, "Verified", comment[p.id])}><CheckCircle2 size={14} />Approve</Btn>
                <Btn size="sm" variant="subtle" onClick={() => act(p, "Changes Requested", comment[p.id])}>Request Changes</Btn>
              </div>
            )}
          </div>
        ))}
      </Card>

      <Card className="p-5 sm:p-6">
        <div className="mb-4 text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>Verification Rounds</div>
        <div className="space-y-2.5">
          {others.map((p) => (
            <div key={p.id} className="flex flex-wrap items-center justify-between gap-2 rounded-[20px] px-4 py-3" style={{ background: LAV_SOFT, border: `1px solid ${HAIR}` }}>
              <div>
                <button onClick={() => onOpen(p.id)} className="text-[13px] font-extrabold underline-offset-2 hover:underline" style={{ color: NAVY }}>{p.values.siteName}</button>
                <div className="flex items-center gap-1 text-[11px] italic" style={{ color: MUTED }}>
                  by: {p.values.manager || "No manager assigned"} · {p.values.borough}
                </div>
              </div>
              <div className="flex items-center gap-2">
                <StatusPill status={p.verification} small />
                {isAdmin && <Btn size="sm" variant="ghost" onClick={() => request(p)}>Request Verification</Btn>}
              </div>
            </div>
          ))}
        </div>
      </Card>
    </div>
  );
}

/* ============================================================
   REPORTS + EXPORT
   ============================================================ */
const ALL_COLUMNS = ["Site", "Address", "Borough", "Council", "Region", "Property type", "Singles", "Doubles", "Triples",
  "WC SC units", "Flats", "Houses", "Total units", "Elevators", "Staircases", "Accessible bedrooms",
  "Step-free entrance", "Manager", "Verification status", "Completeness %", "Last updated"];

function Reports({ list, all, fields, rows, exportCSV, exportXLSX, exportPDF, filterActive }) {
  const [cols, setCols] = useState(["Site", "Address", "Borough", "Council", "Singles", "Doubles", "Triples", "Flats", "Houses", "Total units", "Elevators", "Verification status", "Last updated"]);
  const data = rows(list);
  const toggle = (c) => setCols((p) => (p.includes(c) ? p.filter((x) => x !== c) : [...p, c]));

  return (
    <div>
      <SectionTitle>Reports</SectionTitle>
      <p className="mb-5 text-[12px]" style={{ color: MUTED }}>Choose the columns, use the header filters, then export. Exports contain exactly what you see here.</p>

      <Card className="mb-4 p-5">
        <div className="mb-3 text-[14px] font-bold" style={{ fontFamily: DISPLAY }}>Columns</div>
        <div className="flex flex-wrap gap-2">
          {ALL_COLUMNS.map((c) => (
            <button key={c} onClick={() => toggle(c)}
              className="rounded-full px-4 py-1.5 text-[11px] font-bold transition"
              style={cols.includes(c)
                ? { background: NAVY, color: "#fff", boxShadow: "0 4px 12px rgba(30,39,73,0.25)" }
                : { background: LAV_SOFT, color: "#5C6180", border: `1px solid ${HAIR}` }}>{c}</button>
          ))}
        </div>
      </Card>

      <Card className="mb-4 p-5">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <div className="text-[14px] font-bold" style={{ fontFamily: DISPLAY }}>Property Portfolio Report</div>
            <div className="mt-1 flex items-center gap-2">
              <Chip>{list.length} properties</Chip>
              <Chip tone="soft">{fmt(list.reduce((s, p) => s + accomTotal(p.accommodation), 0))} units</Chip>
              <span className="text-[11px] italic" style={{ color: MUTED }}>{filterActive ? "filtered" : "entire company"}</span>
            </div>
          </div>
          <div className="flex flex-wrap gap-2">
            <Btn size="sm" variant="amber" onClick={() => exportXLSX(list, filterActive ? "london-filtered" : "london-portfolio")}><Download size={14} />Excel</Btn>
            <Btn size="sm" variant="subtle" onClick={() => exportCSV(list, filterActive ? "london-filtered" : "london-portfolio")}><Download size={14} />CSV</Btn>
            <Btn size="sm" variant="subtle" onClick={() => exportPDF(list)}><Download size={14} />PDF</Btn>
            <Btn size="sm" onClick={() => exportXLSX(all, "london-entire-portfolio")}>Export Entire Portfolio</Btn>
          </div>
        </div>
      </Card>

      <Card className="overflow-hidden">
        <div className="overflow-x-auto">
          <table className="w-full text-[12px]">
            <thead>
              <tr style={{ background: NAVY }}>
                {cols.map((c) => <th key={c} className="whitespace-nowrap px-3.5 py-3 text-left text-[10px] font-extrabold uppercase tracking-[0.06em] text-white">{c}</th>)}
              </tr>
            </thead>
            <tbody>
              {data.map((r, i) => (
                <tr key={i} className="transition hover:bg-black/[0.02]" style={{ borderBottom: "1px solid rgba(30,39,73,0.06)" }}>
                  {cols.map((c) => <td key={c} className="whitespace-nowrap px-3.5 py-2.5" style={{ color: "#5C6180" }}>{String(r[c] ?? "")}</td>)}
                </tr>
              ))}
              <tr className="font-extrabold" style={{ background: "rgba(246,194,68,0.18)" }}>
                {cols.map((c) => {
                  const numericCols = ["Singles", "Doubles", "Triples", "WC SC units", "Flats", "Houses", "Total units", "Elevators", "Staircases", "Accessible bedrooms"];
                  return <td key={c} className="whitespace-nowrap px-3.5 py-2.5" style={{ color: "#8A6A10" }}>
                    {c === "Site" ? "Company total" : numericCols.includes(c) ? fmt(data.reduce((s, r) => s + (Number(r[c]) || 0), 0)) : ""}
                  </td>;
                })}
              </tr>
            </tbody>
          </table>
        </div>
      </Card>
    </div>
  );
}

/* ============================================================
   DATA IMPORT
   ============================================================ */
function ImportScreen({ properties, fields, notify, onImport }) {
  const [raw, setRaw] = useState(null);
  const [mapping, setMapping] = useState({});
  const fileRef = useRef();

  const targets = [
    ...BASE_FIELDS.filter((f) => f.section === "general").map((f) => ({ id: f.id, label: f.label })),
    ...ACCOM.map((a) => ({ id: "accom:" + a.key, label: `Accommodation — ${a.label}` })),
  ];

  function handleFile(e) {
    const file = e.target.files?.[0];
    if (!file) return;
    const reader = new FileReader();
    reader.onload = (ev) => {
      try {
        const wb = XLSX.read(ev.target.result, { type: "array" });
        const rows = XLSX.utils.sheet_to_json(wb.Sheets[wb.SheetNames[0]], { defval: "" });
        if (!rows.length) { notify("That file has no rows to import."); return; }
        const headers = Object.keys(rows[0]);
        const auto = {};
        headers.forEach((h) => {
          const norm = h.toLowerCase().replace(/[^a-z0-9]/g, "");
          const hit = targets.find((t) => t.label.toLowerCase().replace(/[^a-z0-9]/g, "").includes(norm) || norm.includes(t.label.toLowerCase().replace(/[^a-z0-9]/g, "")));
          auto[h] = hit ? hit.id : "";
        });
        setMapping(auto);
        setRaw({ headers, rows, name: file.name });
      } catch {
        notify("That file could not be read. Upload a .xlsx or .csv file.");
      }
    };
    reader.readAsArrayBuffer(file);
  }

  function sampleFile() {
    const demo = [
      { "Site Name": "Hackney Wick House", "Address Line 1": "18 Wallis Road", "City": "London", "Postal Code": "E9 5LN", "Borough": "Newham", "Council": "Newham Council", "Region": "London East", "Property Type": "Temporary Accommodation", "Manager": "Leah Turner", "Singles": 44, "Doubles": 26, "Triples": 8, "1 Bedroom Flats": 12 },
      { "Site Name": "Croydon Housing", "Address Line 1": "142 London Road", "City": "Croydon", "Postal Code": "CR0 2TB", "Borough": "Croydon", "Council": "Croydon Council", "Region": "London South", "Property Type": "Residential Housing", "Manager": "Jane Smith", "Singles": 105, "Doubles": 72, "Triples": 38 },
      { "Site Name": "Southwark Bridge Rooms", "Address Line 1": "4 Sumner Street", "City": "London", "Postal Code": "SE1 9JA", "Borough": "Lewisham", "Council": "Lewisham Council", "Region": "London South", "Property Type": "Hotel", "Manager": "", "Singles": 31, "Doubles": 40 },
    ];
    const wb = XLSX.utils.book_new();
    XLSX.utils.book_append_sheet(wb, XLSX.utils.json_to_sheet(demo), "Legacy");
    const out = XLSX.write(wb, { bookType: "xlsx", type: "array" });
    const url = URL.createObjectURL(new Blob([out]));
    const a = document.createElement("a"); a.href = url; a.download = "legacy-property-spreadsheet.xlsx"; a.click();
    notify("Sample legacy spreadsheet downloaded. Upload it to try the import.");
  }

  const preview = useMemo(() => {
    if (!raw) return [];
    return raw.rows.map((row) => {
      const values = {}; const accommodation = blankAccom();
      Object.entries(mapping).forEach(([header, target]) => {
        if (!target) return;
        const v = row[header];
        if (target.startsWith("accom:")) accommodation[target.slice(6)] = v === "" ? null : Number(v) || 0;
        else values[target] = v === "" ? undefined : v;
      });
      const dup = properties.find((p) => (p.values.siteName || "").toLowerCase() === String(values.siteName || "").toLowerCase());
      const missingReq = BASE_FIELDS.filter((f) => f.required && f.section === "general" && !isFilled(values[f.id])).map((f) => f.label);
      return { values, accommodation, dup, missingReq };
    });
  }, [raw, mapping, properties]);

  const unmapped = raw ? raw.headers.filter((h) => !mapping[h]) : [];
  const importable = preview.filter((r) => !r.dup);

  return (
    <div>
      <SectionTitle>Import</SectionTitle>
      <p className="mb-5 text-[12px]" style={{ color: MUTED }}>Bring legacy spreadsheets into the central record. Nothing is written until you review the preview.</p>

      {!raw ? (
        <Card className="p-12 text-center">
          <div className="mx-auto flex h-16 w-16 items-center justify-center rounded-full" style={{ background: AMBER, boxShadow: "0 8px 20px rgba(245,166,35,0.4)" }}>
            <Upload size={26} color={NAVY_DK} />
          </div>
          <div className="mt-4 text-[18px] font-bold" style={{ fontFamily: DISPLAY }}>Upload an Excel or CSV File</div>
          <p className="mx-auto mt-1.5 max-w-md text-[12px] leading-relaxed" style={{ color: MUTED }}>The first sheet is read and its column headers are matched to fields automatically. You can correct any match before importing.</p>
          <input ref={fileRef} type="file" accept=".xlsx,.xls,.csv" onChange={handleFile} className="hidden" />
          <div className="mt-5 flex justify-center gap-2">
            <Btn variant="amber" onClick={() => fileRef.current?.click()}>Choose File</Btn>
            <Btn variant="subtle" onClick={sampleFile}>Download a Sample Legacy File</Btn>
          </div>
        </Card>
      ) : (
        <>
          <Card className="mb-4 p-5">
            <div className="flex flex-wrap items-center justify-between gap-2">
              <div>
                <div className="text-[14px] font-bold" style={{ fontFamily: DISPLAY }}>{raw.name}</div>
                <div className="mt-1 flex gap-2">
                  <Chip tone="soft">{raw.rows.length} rows</Chip>
                  <Chip tone="soft">{raw.headers.length} columns</Chip>
                  <Chip>{unmapped.length} unmatched</Chip>
                </div>
              </div>
              <Btn size="sm" variant="subtle" onClick={() => { setRaw(null); setMapping({}); }}>Start Over</Btn>
            </div>
          </Card>

          <Card className="mb-4 p-5">
            <div className="mb-4 text-[14px] font-bold" style={{ fontFamily: DISPLAY }}>Map Columns to Fields</div>
            <div className="grid gap-2.5 md:grid-cols-2">
              {raw.headers.map((h) => (
                <div key={h} className="flex items-center gap-2">
                  <div className="w-1/2 truncate rounded-full px-4 py-2 text-[11px] font-semibold" style={{ background: LAV_SOFT, color: "#5C6180" }} title={h}>{h}</div>
                  <select value={mapping[h] || ""} onChange={(e) => setMapping({ ...mapping, [h]: e.target.value })}
                    className="w-1/2 rounded-full px-3.5 py-2 text-[11px] font-bold outline-none transition focus:ring-2"
                    style={{ background: mapping[h] ? NAVY : "#E3E5F0", color: mapping[h] ? "#fff" : "#5C6180", border: "none", "--tw-ring-color": "rgba(246,194,68,0.6)" }}>
                    <option value="">Do not import</option>
                    {targets.map((t) => <option key={t.id} value={t.id}>{t.label}</option>)}
                  </select>
                </div>
              ))}
            </div>
          </Card>

          <Card className="mb-4 overflow-hidden">
            <div className="px-5 py-4 text-[14px] font-bold" style={{ fontFamily: DISPLAY, borderBottom: `1px solid ${HAIR}` }}>Preview</div>
            <div className="overflow-x-auto">
              <table className="w-full text-[12px]">
                <thead>
                  <tr style={{ borderBottom: `1px solid ${HAIR}` }}>
                    {["Site", "Borough", "Units", "Issues"].map((h) => <th key={h} className="px-4 py-2.5 text-left text-[10px] font-extrabold uppercase tracking-[0.06em]" style={{ color: MUTED }}>{h}</th>)}
                  </tr>
                </thead>
                <tbody>
                  {preview.map((r, i) => (
                    <tr key={i} style={{ borderBottom: "1px solid rgba(30,39,73,0.05)", background: r.dup ? "rgba(214,69,69,0.05)" : "transparent" }}>
                      <td className="px-4 py-2.5 font-bold">{r.values.siteName || <span style={{ color: RED }}>No site name</span>}</td>
                      <td className="px-4 py-2.5" style={{ color: "#5C6180" }}>{r.values.borough || "—"}</td>
                      <td className="px-4 py-2.5">{accomTotal(r.accommodation)}</td>
                      <td className="px-4 py-2.5">
                        {r.dup ? <span className="inline-flex items-center gap-1 font-semibold" style={{ color: RED }}><AlertTriangle size={12} />Duplicate — already in the system, will be skipped</span>
                          : r.missingReq.length ? <span style={{ color: ORANGE }}>Missing: {r.missingReq.join(", ")}</span>
                          : <span className="inline-flex items-center gap-1 font-semibold" style={{ color: OKGREEN }}><Star size={11} fill={YELLOW} color={YELLOW} />Ready to import</span>}
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Card>

          <div className="flex justify-end gap-2">
            <Btn variant="subtle" onClick={() => { setRaw(null); setMapping({}); }}>Cancel</Btn>
            <Btn variant="amber" disabled={importable.length === 0} onClick={() => onImport(importable.map((r) => ({
              id: "p-" + Math.random().toString(36).slice(2, 7),
              verification: "Not Started",
              values: { ...r.values, operationalStatus: r.values.operationalStatus || "Open" },
              accommodation: r.accommodation, elevators: [], staircases: [], documents: [],
              history: [{ id: "i" + Math.random().toString(36).slice(2, 6), field: "Property record", prev: "—", next: "Imported", by: "Import", date: stamp(), reason: `Imported from ${raw.name}`, approval: "Approved" }],
            })))}>Import {importable.length} Properties</Btn>
          </div>
        </>
      )}
    </div>
  );
}

/* ============================================================
   ADMIN — FIELD CONFIGURATION
   ============================================================ */
function AdminFields({ fields, customFields, setCustomFields, options, setOptions, notify }) {
  const [draft, setDraft] = useState({ label: "", help: "", section: "building", type: "number", required: false, optionList: "", unit: "" });
  const [listKey, setListKey] = useState("boroughs");
  const [newOpt, setNewOpt] = useState("");

  const add = () => {
    if (!draft.label.trim()) return;
    const f = {
      id: "cf_" + Math.random().toString(36).slice(2, 8),
      label: draft.label.trim(), help: draft.help, section: draft.section,
      type: draft.type === "dropdown" ? "custom-select" : draft.type,
      optionList: draft.optionList ? draft.optionList.split(",").map((s) => s.trim()).filter(Boolean) : undefined,
      unit: draft.unit || undefined, required: draft.required, custom: true,
    };
    setCustomFields((p) => [...p, f]);
    setDraft({ label: "", help: "", section: "building", type: "number", required: false, optionList: "", unit: "" });
    notify(`"${f.label}" is now collected on every property record.`);
  };

  const inp = "w-full rounded-2xl px-4 py-2.5 text-[12px] outline-none transition focus:ring-2";
  const inpS = { background: LAV_SOFT, border: `1px solid ${HAIR}`, "--tw-ring-color": "rgba(30,39,73,0.3)" };
  const L = ({ children }) => <div className="mb-1.5 text-[12px] font-bold" style={{ color: NAVY }}>{children}</div>;

  return (
    <div>
      <SectionTitle>Fields</SectionTitle>
      <p className="mb-5 text-[12px]" style={{ color: MUTED }}>Add what the business decides it needs next. New fields appear on every property immediately — no rebuild.</p>

      <div className="grid gap-5 lg:grid-cols-2">
        <Card className="p-6">
          <div className="mb-4 text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>Create a Field</div>
          <div className="grid gap-4">
            <div><L>Field name</L>
              <input className={inp} style={inpS} value={draft.label} onChange={(e) => setDraft({ ...draft, label: e.target.value })} placeholder="e.g. Number of boilers" /></div>
            <div><L>Help text</L>
              <input className={inp} style={inpS} value={draft.help} onChange={(e) => setDraft({ ...draft, help: e.target.value })} placeholder="Shown to property managers as guidance" /></div>
            <div className="grid grid-cols-2 gap-4">
              <div><L>Section</L>
                <select className={inp} style={inpS} value={draft.section} onChange={(e) => setDraft({ ...draft, section: e.target.value })}>
                  {SECTIONS.map((s) => <option key={s.id} value={s.id}>{s.label}</option>)}
                </select></div>
              <div><L>Data type</L>
                <select className={inp} style={inpS} value={draft.type} onChange={(e) => setDraft({ ...draft, type: e.target.value })}>
                  {["text", "number", "decimal", "date", "yesno", "dropdown", "measurement", "notes"].map((t) => <option key={t} value={t}>{t}</option>)}
                </select></div>
            </div>
            {draft.type === "dropdown" && (
              <div><L>Dropdown options</L>
                <input className={inp} style={inpS} value={draft.optionList} onChange={(e) => setDraft({ ...draft, optionList: e.target.value })} placeholder="Comma separated, e.g. Gas, Electric, District" /></div>
            )}
            {["number", "decimal"].includes(draft.type) && (
              <div><L>Measurement unit</L>
                <input className={inp} style={inpS} value={draft.unit} onChange={(e) => setDraft({ ...draft, unit: e.target.value })} placeholder="e.g. kW, litres, units" /></div>
            )}
            <label className="flex items-center gap-3 text-[12px] font-semibold" style={{ color: "#5C6180" }}>
              <button onClick={() => setDraft({ ...draft, required: !draft.required })}
                className="relative h-[26px] w-[46px] rounded-full transition"
                style={{ background: draft.required ? NAVY : "rgba(30,39,73,0.15)" }}>
                <span className="absolute top-[3px] h-[20px] w-[20px] rounded-full transition-all"
                  style={{ left: draft.required ? "23px" : "3px", background: draft.required ? YELLOW : "#fff", boxShadow: "0 1px 4px rgba(0,0,0,0.25)" }} />
              </button>
              Required before a property can be submitted
            </label>
            <div><Btn variant="amber" onClick={add} disabled={!draft.label.trim()}><Plus size={14} />Add Field</Btn></div>
          </div>
        </Card>

        <div className="space-y-5">
          <Card className="p-6">
            <div className="mb-4 text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>Custom Fields in Use · {customFields.length}</div>
            {customFields.length === 0 ? <div className="py-4 text-center text-[13px]" style={{ color: MUTED }}>No custom fields yet.</div> :
              customFields.map((f) => (
                <div key={f.id} className="mb-2.5 flex items-center justify-between rounded-[20px] px-4 py-3" style={{ background: LAV_SOFT, border: `1px solid ${HAIR}` }}>
                  <div>
                    <div className="text-[13px] font-extrabold">{f.label}</div>
                    <div className="text-[11px]" style={{ color: MUTED }}>{SECTIONS.find((s) => s.id === f.section)?.label} · {f.type}{f.required ? " · required" : ""}</div>
                  </div>
                  <button onClick={() => setCustomFields((p) => p.filter((x) => x.id !== f.id))}
                    className="flex h-8 w-8 items-center justify-center rounded-full transition hover:brightness-95" style={{ background: "#fff", color: RED, border: `1px solid ${HAIR}` }}><Trash2 size={14} /></button>
                </div>
              ))}
          </Card>

          <Card className="p-6">
            <div className="mb-4 text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>Dropdown Lists</div>
            <select className={`${inp} mb-3`} style={inpS} value={listKey} onChange={(e) => setListKey(e.target.value)}>
              {Object.keys(options).map((k) => <option key={k} value={k}>{k}</option>)}
            </select>
            <div className="mb-3 flex flex-wrap gap-2">
              {options[listKey].map((o) => (
                <span key={o} className="inline-flex items-center gap-1.5 rounded-full px-3.5 py-1.5 text-[11px] font-bold" style={{ background: NAVY, color: "#fff" }}>
                  {o}<button onClick={() => setOptions({ ...options, [listKey]: options[listKey].filter((x) => x !== o) })} style={{ color: YELLOW }} className="hover:opacity-70"><X size={11} /></button>
                </span>
              ))}
            </div>
            <div className="flex gap-2">
              <input className={inp} style={inpS} value={newOpt} onChange={(e) => setNewOpt(e.target.value)} placeholder="Add an option" />
              <Btn size="sm" variant="amber" onClick={() => { if (newOpt.trim()) { setOptions({ ...options, [listKey]: [...options[listKey], newOpt.trim()] }); setNewOpt(""); } }}>Add</Btn>
            </div>
          </Card>
        </div>
      </div>
    </div>
  );
}

/* ============================================================
   PROPERTY DETAIL
   ============================================================ */
const TABS = [
  { id: "overview", label: "Overview" },
  { id: "general", label: "General" },
  { id: "accommodation", label: "Accommodation" },
  { id: "dimensions", label: "Dimensions" },
  { id: "elevators", label: "Elevators" },
  { id: "staircases", label: "Staircases" },
  { id: "accessibility", label: "Accessibility" },
  { id: "building", label: "Building" },
  { id: "documents", label: "Documents" },
  { id: "history", label: "History" },
];

function PropertyDetail({ p, fields, options, role, identity, canEdit, isAdmin, onBack, setFieldValue, setAccom, updateProperty, notify, flags, resolveFlag }) {
  const [tab, setTab] = useState("overview");
  const [showMissing, setShowMissing] = useState(false);
  const pct = completeness(p, fields);
  const missing = missingFields(p, fields);
  const readOnly = !canEdit;
  const sectionFields = (id) => fields.filter((f) => f.section === id);

  const submit = () => {
    if (missing.required.length) { setShowMissing(true); notify("Complete the required fields before submitting."); return; }
    updateProperty(p.id, (d) => ({ ...d, verification: "Submitted" }),
      { field: "Verification", prev: p.verification, next: "Submitted", reason: "Submitted for review by property manager", approval: "Approved" });
    notify("Submitted for review. Corporate will approve or send it back.");
  };

  return (
    <div>
      <button onClick={onBack} className="mb-4 inline-flex items-center gap-1.5 rounded-full bg-white px-4 py-2 text-[12px] font-extrabold transition hover:-translate-x-0.5"
        style={{ color: NAVY, border: `1px solid ${HAIR}`, boxShadow: "0 4px 12px rgba(30,39,73,0.08)" }}>
        <ChevronLeft size={15} />Back
      </button>

      {/* Header — navy hero card with yellow chips */}
      <div className="mb-5 overflow-hidden rounded-[28px]" style={{ boxShadow: "0 14px 36px rgba(30,39,73,0.20)" }}>
        <div className="relative flex flex-wrap items-start justify-between gap-4 p-6 sm:p-7" style={{ background: `linear-gradient(150deg, #2A3560, ${NAVY} 65%, ${NAVY_DK})` }}>
          <div className="pointer-events-none absolute -right-14 -top-16 h-48 w-48 rounded-full" style={{ background: "rgba(255,255,255,0.05)" }} />
          <div className="relative flex items-start gap-5">
            <Ring pct={pct} size={68} stroke={7} light />
            <div>
              <h1 className="text-[24px] font-bold leading-tight text-white" style={{ fontFamily: DISPLAY }}>{p.values.siteName || "Untitled property"}</h1>
              <div className="mt-1 flex items-center gap-1.5 text-[12px] text-white/70">
                <MapPin size={12} color={YELLOW} />
                {[p.values.addressLine1, p.values.addressLine2, p.values.city, p.values.postcode].filter(Boolean).join(", ") || "No address recorded"}
              </div>
              <div className="mt-3 flex flex-wrap items-center gap-2">
                <StatusPill status={p.verification} />
                {[p.values.borough, p.values.propertyType].filter(Boolean).map((t) => <Chip key={t}>{t}</Chip>)}
                {readOnly && <Chip tone="navy">Read-Only</Chip>}
              </div>
              <div className="mt-2 text-[11px] italic text-white/60">by: {p.values.manager || "Unassigned"}</div>
            </div>
          </div>
          <div className="relative flex flex-wrap gap-2">
            <Btn variant="yellow" size="sm" onClick={() => setShowMissing(true)}>Missing Information</Btn>
            {canEdit && p.verification !== "Submitted" && (
              <button onClick={submit} className="inline-flex items-center gap-1.5 rounded-full bg-white px-4 py-1.5 text-[12px] font-extrabold transition hover:brightness-95 active:scale-95" style={{ color: NAVY }}>
                <CheckCircle2 size={14} />Submit for Review
              </button>
            )}
            {isAdmin && p.verification === "Submitted" && (
              <>
                <Btn size="sm" variant="yellow" onClick={() => { updateProperty(p.id, (d) => ({ ...d, verification: "Verified" }), { field: "Verification", prev: "Submitted", next: "Verified", reason: "Approved by corporate", approval: "Approved" }); notify("Property verified."); }}>Approve</Btn>
                <button onClick={() => { updateProperty(p.id, (d) => ({ ...d, verification: "Changes Requested" }), { field: "Verification", prev: "Submitted", next: "Changes Requested", reason: "Changes requested by corporate", approval: "Approved" }); notify("Sent back to the property manager."); }}
                  className="rounded-full bg-white px-4 py-1.5 text-[12px] font-extrabold transition hover:brightness-95" style={{ color: NAVY }}>Request Changes</button>
              </>
            )}
          </div>
        </div>
        {canEdit && (
          <div className="flex items-center gap-1.5 bg-white px-6 py-3 text-[11px] font-bold sm:px-7" style={{ color: "#8A6A10", background: "rgba(246,194,68,0.14)" }}>
            <Star size={11} fill={YELLOW} color={YELLOW} />Changes save as you type and are written to the audit history automatically.
          </div>
        )}
      </div>

      {/* Large-change flags */}
      {flags.map((f) => (
        <div key={f.key} className="mb-4 flex flex-wrap items-center justify-between gap-3 rounded-[24px] px-5 py-4"
          style={{ background: "rgba(246,194,68,0.18)", border: `1.5px solid ${YELLOW}` }}>
          <div className="flex items-start gap-2.5">
            <AlertTriangle size={17} className="mt-0.5" color="#8A6A10" />
            <div className="text-[12px]" style={{ color: "#6E540C" }}>
              <div className="font-extrabold">Large change detected — {f.label}</div>
              <div>Previous value: {f.prev}. New value: {f.next}. Please confirm this is correct.</div>
            </div>
          </div>
          <div className="flex gap-2">
            <Btn size="sm" onClick={() => resolveFlag(f.key, false)}>Confirm</Btn>
            <Btn size="sm" variant="subtle" onClick={() => resolveFlag(f.key, true)}>Revert to {f.prev}</Btn>
          </div>
        </div>
      ))}

      {/* Pill tabs */}
      <div className="mb-5"><PillTabs tabs={TABS} value={tab} onChange={setTab} /></div>

      {tab === "overview" && <Overview p={p} fields={fields} pct={pct} missing={missing} onMissing={() => setShowMissing(true)} />}

      {["general", "dimensions", "accessibility", "building"].includes(tab) && (
        <Card className="p-6">
          <div className="mb-5 text-[16px] font-bold" style={{ fontFamily: DISPLAY }}>{SECTIONS.find((s) => s.id === tab)?.label}</div>
          <div className="grid gap-5 md:grid-cols-2 xl:grid-cols-3">
            {sectionFields(tab).map((f) => (
              <div key={f.id} className={f.type === "notes" ? "md:col-span-2 xl:col-span-3" : ""}>
                <Field field={f} value={p.values[f.id]} options={options} readOnly={readOnly}
                  onChange={(v) => setFieldValue(p, f.id, v, f.label)} />
                {f.custom && <div className="mt-1 inline-flex items-center gap-1 text-[9px] font-extrabold uppercase tracking-[0.1em]" style={{ color: "#8A6A10" }}><Star size={8} fill={YELLOW} color={YELLOW} />Custom Field</div>}
              </div>
            ))}
          </div>
        </Card>
      )}

      {tab === "accommodation" && <AccommodationTab p={p} readOnly={readOnly} setAccom={setAccom} />}
      {tab === "elevators" && <Repeatable p={p} kind="elevators" readOnly={readOnly} options={options} updateProperty={updateProperty} identity={identity} />}
      {tab === "staircases" && <Repeatable p={p} kind="staircases" readOnly={readOnly} options={options} updateProperty={updateProperty} identity={identity} />}
      {tab === "documents" && <Documents p={p} readOnly={readOnly} options={options} updateProperty={updateProperty} identity={identity} notify={notify} />}
      {tab === "history" && <HistoryTab p={p} />}

      {showMissing && (
        <Modal title={`Missing Information — ${p.values.siteName}`} onClose={() => setShowMissing(false)} wide>
          <div className="mb-5 flex items-center gap-5 rounded-[24px] p-5" style={{ background: LAV_SOFT }}>
            <Ring pct={pct} size={64} stroke={7} />
            <div className="text-[13px]" style={{ color: "#5C6180" }}>
              <div><span className="font-extrabold">{fields.length - missing.required.length - missing.optional.length}</span> fields completed</div>
              <div><span className="font-extrabold" style={{ color: RED }}>{missing.required.length}</span> required outstanding · <span className="font-extrabold" style={{ color: ORANGE }}>{missing.optional.length}</span> optional</div>
              <div className="mt-1 text-[11px]" style={{ color: MUTED }}>{p.history.filter((h) => h.approval === "Pending").length} changes awaiting approval</div>
            </div>
          </div>
          {[["Required", missing.required, RED], ["Optional", missing.optional, ORANGE]].map(([title, list, tone]) => (
            <div key={title} className="mb-5">
              <div className="mb-2.5 text-[15px] font-bold" style={{ color: tone, fontFamily: DISPLAY }}>{title} · {list.length}</div>
              {list.length === 0 ? <div className="text-[13px]" style={{ color: MUTED }}>Nothing outstanding.</div> : (
                <div className="grid gap-2 sm:grid-cols-2">
                  {list.map((f) => (
                    <div key={f.id} className="flex items-center justify-between rounded-full px-4 py-2 text-[12px]" style={{ background: LAV_SOFT, border: `1px solid ${HAIR}` }}>
                      <span className="font-semibold">{f.label}</span>
                      <span className="text-[10px]" style={{ color: MUTED }}>{SECTIONS.find((s) => s.id === f.section)?.label}</span>
                    </div>
                  ))}
                </div>
              )}
            </div>
          ))}
        </Modal>
      )}
    </div>
  );
}

function Overview({ p, fields, pct, missing, onMissing }) {
  const total = accomTotal(p.accommodation);
  const stats = [
    { l: "Total Units", v: fmt(total), hot: true },
    { l: "Elevators", v: p.elevators.length },
    { l: "Staircases", v: p.staircases.length },
    { l: "Floors", v: p.values.floors ?? "—" },
    { l: "Accessible Beds", v: num(p.values.accessibleBedroomCount) },
    { l: "Documents", v: p.documents.length },
  ];
  return (
    <div className="grid gap-4 lg:grid-cols-3">
      <div className="space-y-4 lg:col-span-2">
        <Card className="p-5">
          <div className="mb-4 text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>Record Summary</div>
          <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
            {stats.map((s) => (
              <div key={s.l} className="rounded-[20px] p-4" style={{ background: s.hot ? `linear-gradient(150deg, #2A3560, ${NAVY})` : LAV_SOFT }}>
                <div className="text-[22px] font-bold" style={{ color: s.hot ? YELLOW : INK, fontFamily: DISPLAY }}>{s.v}</div>
                <div className="text-[9px] font-extrabold uppercase tracking-[0.1em]" style={{ color: s.hot ? "rgba(255,255,255,0.6)" : MUTED }}>{s.l}</div>
              </div>
            ))}
          </div>
        </Card>
        <Card className="p-5">
          <div className="mb-4 text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>Accommodation Mix</div>
          <div style={{ height: 200 }}>
            <ResponsiveContainer>
              <BarChart data={ACCOM.filter((a) => num(p.accommodation[a.key]) > 0).map((a) => ({ name: a.label, count: num(p.accommodation[a.key]) }))}
                margin={{ top: 4, right: 8, left: -18, bottom: 4 }}>
                <CartesianGrid strokeDasharray="0" stroke="rgba(30,39,73,0.06)" vertical={false} />
                <XAxis dataKey="name" tick={{ fontSize: 10, fill: MUTED, fontFamily: BODY }} interval={0} angle={-24} textAnchor="end" height={64} axisLine={false} tickLine={false} />
                <YAxis tick={{ fontSize: 11, fill: MUTED, fontFamily: BODY }} axisLine={false} tickLine={false} />
                <Tooltip contentStyle={{ fontSize: 12, borderRadius: 16, border: "none", boxShadow: "0 8px 24px rgba(30,39,73,0.18)", fontFamily: BODY }} cursor={{ fill: "rgba(30,39,73,0.04)" }} />
                <Bar dataKey="count" fill={NAVY} radius={[8, 8, 8, 8]} maxBarSize={34} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>
      <div className="space-y-4">
        <Card className="p-5">
          <div className="mb-3 text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>Completeness</div>
          <div className="flex items-center gap-4">
            <Ring pct={pct} size={68} stroke={8} />
            <div className="text-[12px]" style={{ color: MUTED }}>
              <div style={{ color: RED }} className="font-bold">{missing.required.length} required outstanding</div>
              <div style={{ color: ORANGE }} className="font-bold">{missing.optional.length} optional outstanding</div>
              <button onClick={onMissing} className="mt-1.5 font-extrabold underline-offset-2 hover:underline" style={{ color: NAVY }}>View Missing Information</button>
            </div>
          </div>
        </Card>
        <Card className="p-5">
          <div className="mb-3 text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>Responsibility</div>
          <dl className="space-y-2 text-[12px]">
            {[["Manager", p.values.manager], ["Email", p.values.managerEmail], ["Phone", p.values.managerPhone],
              ["Ownership", p.values.ownershipCompany], ["Management", p.values.managementCompany],
              ["Opened", p.values.openedDate]].map(([k, v]) => (
              <div key={k} className="flex justify-between gap-2">
                <dt style={{ color: MUTED }}>{k}</dt><dd className="truncate text-right font-semibold">{v || "—"}</dd>
              </div>
            ))}
          </dl>
        </Card>
        <Card className="p-5">
          <div className="mb-3 text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>Recent Changes</div>
          {p.history.slice(0, 4).map((h) => (
            <div key={h.id} className="mb-2.5 text-[11px]">
              <div className="font-bold">{h.field}: {h.prev} → {h.next}</div>
              <div className="italic" style={{ color: MUTED }}>by: {h.by} · {h.date}</div>
            </div>
          ))}
          {p.history.length === 0 && <div className="text-[11px]" style={{ color: MUTED }}>No changes recorded yet.</div>}
        </Card>
      </div>
    </div>
  );
}

function AccommodationTab({ p, readOnly, setAccom }) {
  const total = accomTotal(p.accommodation);
  const groups = ["Rooms", "Flats", "Houses", "Other"];
  return (
    <div className="space-y-4">
      <div className="rounded-[28px] p-6 sm:p-7" style={{ background: `linear-gradient(150deg, #2A3560, ${NAVY} 65%, ${NAVY_DK})`, boxShadow: "0 14px 36px rgba(30,39,73,0.25)" }}>
        <div className="flex flex-wrap items-end justify-between gap-6">
          <div>
            <Chip>TOTAL ACCOMMODATION UNITS</Chip>
            <div className="mt-2 text-[44px] font-bold leading-none text-white" style={{ fontFamily: DISPLAY }}>{fmt(total)}</div>
            <div className="mt-2 text-[11px] italic text-white/60">Calculated automatically. Blank counts as zero.</div>
          </div>
          <div className="flex gap-8">
            {[["Rooms", ["singles", "doubles", "triples", "wcSc"]], ["Flats", FLAT_KEYS], ["Houses", HOUSE_KEYS]].map(([label, keys]) => (
              <div key={label} className="text-right">
                <div className="text-[22px] font-bold text-white" style={{ fontFamily: DISPLAY }}>{fmt(keys.reduce((s, k) => s + num(p.accommodation[k]), 0))}</div>
                <div className="text-[10px] font-bold uppercase tracking-[0.08em]" style={{ color: "rgba(255,255,255,0.5)" }}>{label}</div>
              </div>
            ))}
          </div>
        </div>
      </div>
      {groups.map((g) => (
        <Card key={g} className="p-5 sm:p-6">
          <div className="mb-4 text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>{g}</div>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            {ACCOM.filter((a) => a.group === g).map((a) => (
              <div key={a.key}>
                <label className="mb-1.5 block text-[12px] font-bold" style={{ color: NAVY }}>{a.label}</label>
                <input type="number" min="0" disabled={readOnly}
                  className="w-full rounded-2xl px-4 py-2.5 text-[15px] font-extrabold outline-none transition focus:ring-2"
                  style={{ background: readOnly ? "rgba(30,39,73,0.04)" : LAV_SOFT, border: `1px solid ${readOnly ? "transparent" : HAIR}`, color: readOnly ? MUTED : INK, "--tw-ring-color": "rgba(30,39,73,0.3)" }}
                  value={p.accommodation[a.key] ?? ""} placeholder="0"
                  onChange={(e) => setAccom(p, a.key, e.target.value, a.label)} />
              </div>
            ))}
          </div>
        </Card>
      ))}
    </div>
  );
}

function Repeatable({ p, kind, readOnly, options, updateProperty, identity }) {
  const isLift = kind === "elevators";
  const items = p[kind];
  const add = () => updateProperty(p.id, (d) => ({ ...d, [kind]: [...d[kind], isLift ? lift({ name: `Lift ${d.elevators.length + 1}` }) : stair({ name: `Stair ${d.staircases.length + 1}` })] }),
    { field: isLift ? "Elevators" : "Staircases", prev: String(items.length), next: String(items.length + 1), reason: "Record added" });
  const remove = (id) => updateProperty(p.id, (d) => ({ ...d, [kind]: d[kind].filter((x) => x.id !== id) }),
    { field: isLift ? "Elevators" : "Staircases", prev: String(items.length), next: String(items.length - 1), reason: "Record removed" });
  const edit = (id, key, v) => updateProperty(p.id, (d) => ({ ...d, [kind]: d[kind].map((x) => (x.id === id ? { ...x, [key]: v } : x)) }));

  const inp = "w-full rounded-2xl px-3.5 py-2 text-[12px] outline-none transition focus:ring-2";
  const inpS = { background: readOnly ? "rgba(30,39,73,0.04)" : LAV_SOFT, border: `1px solid ${readOnly ? "transparent" : HAIR}`, color: readOnly ? MUTED : INK, "--tw-ring-color": "rgba(30,39,73,0.3)" };
  const L = ({ children }) => <label className="mb-1.5 block text-[11px] font-bold" style={{ color: NAVY }}>{children}</label>;
  const YesNo = ({ value, onSet }) => (
    <div className="inline-flex gap-1.5">
      {["Yes", "No"].map((o) => (
        <button key={o} disabled={readOnly} onClick={() => onSet(o)}
          className="rounded-full px-3.5 py-1 text-[11px] font-bold transition"
          style={value === o
            ? { background: NAVY, color: "#fff" }
            : { background: "#fff", color: MUTED, border: `1px solid ${HAIR}` }}>{o}</button>
      ))}
    </div>
  );

  return (
    <div className="space-y-4">
      <Card className="flex flex-wrap items-center justify-between gap-3 p-5 sm:p-6">
        <div>
          <div className="text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>Number of {isLift ? "Elevators" : "Staircases"}: {items.length}</div>
          <div className="text-[11px]" style={{ color: MUTED }}>{isLift ? "A property can have any number of lifts. Add one record per lift." : "Add one record per staircase, including emergency stairs."}</div>
        </div>
        {!readOnly && <Btn size="sm" variant="amber" onClick={add}><Plus size={14} />Add {isLift ? "Elevator" : "Staircase"}</Btn>}
      </Card>

      {items.length === 0 && <Card className="p-12 text-center text-[13px]" style={{ color: MUTED }}>No {isLift ? "elevators" : "staircases"} recorded. {!readOnly && "Add one to start."}</Card>}

      {items.map((it, i) => (
        <Card key={it.id} className="p-5 sm:p-6">
          <div className="mb-4 flex items-center justify-between">
            <div className="flex items-center gap-2.5">
              <div className="flex h-9 w-9 items-center justify-center rounded-full text-[12px] font-extrabold" style={{ background: AMBER, color: NAVY_DK }}>{i + 1}</div>
              <div className="text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>{isLift ? "Elevator" : "Staircase"}{it.name ? ` — ${it.name}` : ""}</div>
            </div>
            {!readOnly && <button onClick={() => remove(it.id)} className="flex h-8 w-8 items-center justify-center rounded-full transition hover:brightness-95" style={{ background: LAV_SOFT, color: RED, border: `1px solid ${HAIR}` }}><Trash2 size={14} /></button>}
          </div>
          <div className="grid gap-4 sm:grid-cols-2 lg:grid-cols-4">
            <div><L>{isLift ? "Name / identifier" : "Staircase identifier"}</L><input className={inp} style={inpS} disabled={readOnly} value={it.name} onChange={(e) => edit(it.id, "name", e.target.value)} /></div>
            {isLift ? (
              <>
                <div><L>Type</L><select className={inp} style={inpS} disabled={readOnly} value={it.type} onChange={(e) => edit(it.id, "type", e.target.value)}>{options.elevatorTypes.map((o) => <option key={o}>{o}</option>)}</select></div>
                <div><L>Capacity (persons)</L><input type="number" min="0" className={inp} style={inpS} disabled={readOnly} value={it.capacity ?? ""} onChange={(e) => edit(it.id, "capacity", e.target.value === "" ? null : Number(e.target.value))} /></div>
                <div><L>Maximum occupancy</L><input type="number" min="0" className={inp} style={inpS} disabled={readOnly} value={it.maxOccupancy ?? ""} onChange={(e) => edit(it.id, "maxOccupancy", e.target.value === "" ? null : Number(e.target.value))} /></div>
                {[["width", "Width (m)"], ["depth", "Depth (m)"], ["height", "Height (m)"], ["doorWidth", "Door width (m)"]].map(([k, l]) => (
                  <div key={k}><L>{l}</L><input type="number" step="0.01" min="0" className={inp} style={inpS} disabled={readOnly} value={it[k] ?? ""} onChange={(e) => edit(it.id, k, e.target.value === "" ? null : Number(e.target.value))} /></div>
                ))}
                {[["accessible", "Accessible elevator"], ["service", "Service elevator"], ["passenger", "Passenger elevator"]].map(([k, l]) => (
                  <div key={k}><L>{l}</L><YesNo value={it[k]} onSet={(o) => edit(it.id, k, o)} /></div>
                ))}
              </>
            ) : (
              <>
                <div><L>Location</L><input className={inp} style={inpS} disabled={readOnly} value={it.location} onChange={(e) => edit(it.id, "location", e.target.value)} /></div>
                <div><L>Floors served</L><input type="number" min="0" className={inp} style={inpS} disabled={readOnly} value={it.floorsServed ?? ""} onChange={(e) => edit(it.id, "floorsServed", e.target.value === "" ? null : Number(e.target.value))} /></div>
                <div><L>Width (m)</L><input type="number" step="0.01" min="0" className={inp} style={inpS} disabled={readOnly} value={it.width ?? ""} onChange={(e) => edit(it.id, "width", e.target.value === "" ? null : Number(e.target.value))} /></div>
                <div><L>Classification</L><select className={inp} style={inpS} disabled={readOnly} value={it.classification} onChange={(e) => edit(it.id, "classification", e.target.value)}>{["Standard", "Accessible", "Emergency", "Accessible & Emergency"].map((o) => <option key={o}>{o}</option>)}</select></div>
                <div><L>Emergency exit staircase</L><YesNo value={it.emergencyExit} onSet={(o) => edit(it.id, "emergencyExit", o)} /></div>
              </>
            )}
            <div className="sm:col-span-2 lg:col-span-4"><L>Notes</L><input className={inp} style={inpS} disabled={readOnly} value={it.notes} onChange={(e) => edit(it.id, "notes", e.target.value)} /></div>
          </div>
        </Card>
      ))}
    </div>
  );
}

function Documents({ p, readOnly, options, updateProperty, identity, notify }) {
  const [draft, setDraft] = useState({ name: "", type: "Floor Plan", notes: "" });
  const ref = useRef();
  const add = (filename) => {
    const name = filename || draft.name;
    if (!name) return;
    updateProperty(p.id, (d) => ({ ...d, documents: [...d.documents, { id: Math.random().toString(36).slice(2, 8), name, type: draft.type, date: stamp().slice(0, 10), by: identity, notes: draft.notes }] }),
      { field: "Documents", prev: String(p.documents.length), next: String(p.documents.length + 1), reason: `Uploaded ${name}` });
    setDraft({ name: "", type: draft.type, notes: "" });
    notify(`${name} attached to this property.`);
  };
  const inp = "w-full rounded-2xl px-3.5 py-2 text-[12px] outline-none transition focus:ring-2";
  const inpS = { background: LAV_SOFT, border: `1px solid ${HAIR}`, "--tw-ring-color": "rgba(30,39,73,0.3)" };
  return (
    <div className="space-y-4">
      {!readOnly && (
        <Card className="p-5 sm:p-6">
          <div className="mb-4 text-[15px] font-bold" style={{ fontFamily: DISPLAY }}>Attach a Document</div>
          <div className="grid gap-4 sm:grid-cols-4">
            <div className="sm:col-span-2">
              <label className="mb-1.5 block text-[11px] font-bold" style={{ color: NAVY }}>File</label>
              <input ref={ref} type="file" onChange={(e) => e.target.files?.[0] && add(e.target.files[0].name)}
                className="w-full text-[11px] file:mr-3 file:rounded-full file:border-0 file:px-4 file:py-2 file:text-[11px] file:font-extrabold"
                style={{ color: MUTED }} />
            </div>
            <div>
              <label className="mb-1.5 block text-[11px] font-bold" style={{ color: NAVY }}>Document type</label>
              <select className={inp} style={inpS} value={draft.type} onChange={(e) => setDraft({ ...draft, type: e.target.value })}>
                {options.documentTypes.map((o) => <option key={o}>{o}</option>)}
              </select>
            </div>
            <div>
              <label className="mb-1.5 block text-[11px] font-bold" style={{ color: NAVY }}>Notes</label>
              <input className={inp} style={inpS} value={draft.notes} onChange={(e) => setDraft({ ...draft, notes: e.target.value })} />
            </div>
          </div>
        </Card>
      )}
      <Card className="overflow-hidden">
        <table className="w-full text-[12px]">
          <thead>
            <tr style={{ background: NAVY }}>
              {["File Name", "Type", "Uploaded", "By", "Notes"].map((h) => <th key={h} className="px-4 py-3 text-left text-[10px] font-extrabold uppercase tracking-[0.06em] text-white">{h}</th>)}
            </tr>
          </thead>
          <tbody>
            {p.documents.map((d) => (
              <tr key={d.id} style={{ borderBottom: "1px solid rgba(30,39,73,0.05)" }}>
                <td className="px-4 py-3"><span className="flex items-center gap-2 font-bold"><FileText size={14} color={AMBER} />{d.name}</span></td>
                <td className="px-4 py-3" style={{ color: "#5C6180" }}>{d.type}</td>
                <td className="px-4 py-3" style={{ color: "#5C6180" }}>{d.date}</td>
                <td className="px-4 py-3 italic" style={{ color: "#5C6180" }}>by: {d.by}</td>
                <td className="px-4 py-3" style={{ color: "#5C6180" }}>{d.notes || "—"}</td>
              </tr>
            ))}
            {p.documents.length === 0 && <tr><td colSpan={5} className="px-4 py-12 text-center text-[13px]" style={{ color: MUTED }}>No documents yet. Floor plans, surveys and certificates belong here.</td></tr>}
          </tbody>
        </table>
      </Card>
    </div>
  );
}

function HistoryTab({ p }) {
  return (
    <Card className="overflow-hidden">
      <div className="flex items-center gap-2 px-5 py-4 text-[15px] font-bold" style={{ fontFamily: DISPLAY, borderBottom: `1px solid ${HAIR}` }}>
        <History size={15} color={AMBER} />Audit History · {p.history.length}
      </div>
      <div className="overflow-x-auto">
        <table className="w-full text-[12px]">
          <thead>
            <tr style={{ background: NAVY }}>
              {["Field", "Previous", "New", "Changed By", "Date", "Reason", "Approval"].map((h) => <th key={h} className="whitespace-nowrap px-4 py-3 text-left text-[10px] font-extrabold uppercase tracking-[0.06em] text-white">{h}</th>)}
            </tr>
          </thead>
          <tbody>
            {p.history.map((h) => (
              <tr key={h.id} style={{ borderBottom: "1px solid rgba(30,39,73,0.05)" }}>
                <td className="px-4 py-3 font-bold">{h.field}</td>
                <td className="px-4 py-3" style={{ color: MUTED }}>{h.prev}</td>
                <td className="px-4 py-3 font-extrabold" style={{ color: NAVY }}>{h.next}</td>
                <td className="px-4 py-3" style={{ color: "#5C6180" }}>{h.by}</td>
                <td className="whitespace-nowrap px-4 py-3" style={{ color: "#5C6180" }}>{h.date}</td>
                <td className="px-4 py-3" style={{ color: "#5C6180" }}>{h.reason}</td>
                <td className="px-4 py-3">
                  <span className="inline-flex items-center gap-1 rounded-full px-3 py-0.5 text-[10px] font-extrabold"
                    style={h.approval === "Approved" ? { background: "rgba(46,158,107,0.14)", color: OKGREEN } : { background: "rgba(246,194,68,0.2)", color: "#8A6A10" }}>
                    {h.approval === "Approved" ? <Star size={10} fill={YELLOW} color={YELLOW} /> : <Clock size={10} />}{h.approval}
                  </span>
                </td>
              </tr>
            ))}
            {p.history.length === 0 && <tr><td colSpan={7} className="px-4 py-12 text-center text-[13px]" style={{ color: MUTED }}>No changes recorded yet. Every edit from here on is logged.</td></tr>}
          </tbody>
        </table>
      </div>
    </Card>
  );
}
