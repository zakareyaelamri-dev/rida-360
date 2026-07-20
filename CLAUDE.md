# RIDA 360° Performance Assessment System

## What this project is
A 360-degree performance assessment web system for RIDA Technical Services (rida-ts.com),
a Libyan engineering company (Oil & Gas, EPC, metering, SCADA). Built and owned by the
HR Manager. The entire app currently lives in a single file: `index.html`.

## Current architecture (v3 — single file)
- Pure HTML/CSS/JS, no build step, no framework.
- Chart.js from CDN for radar charts.
- Persistence: `window.storage` key-value API (works inside Claude.ai artifacts).
  When deployed as a normal website this API does not exist — replace with Supabase
  (see "Planned migration" below) or, for quick demos, localStorage.
- Bilingual EN/AR with full RTL support. All UI strings live in the `T` dictionary
  (`T.en` / `T.ar`). NEVER hardcode user-facing text — always add keys to both languages.
- Language choice persists via storage key `rida360-lang`.

## Assessment methodology (official — do not change without explicit request)
360° rater weights:
- Manager 40% · Self 20% · Peers 20% · Subordinates 20%
- Redistribution rule: if the target has NO direct subordinates → Manager 50% · Self 25% · Peers 25%

Final grade formula:
- Behavioral section 40% + Technical KPIs & Objectives 60%
- Behavioral = 7 axes (A1–A7) defined in `BEHAV_AXES`, each with weight and 5–6 questions
  rated 1–5. Axis A6 (Leadership) applies ONLY to employees with subordinates (`leadersOnly`).
- Technical = 4 items in `TECH_QS` (weights 30/20/30/20), percentages 0–100,
  entered ONLY in the manager's evaluation form.
- Grade scale: Excellent 90–100 · Very Good 75–89 · Good 60–74 · Acceptable 45–59 · below = Below Standard.

## Org structure & rating chain (in `ORG` + chain functions)
Divisions: RSS (HR, IT, Finance, Legal, Logistics, Public Relations),
Operation (Technical, Service, Project, Construction, Repair Center),
Sales (Supply Chain, Sales, Business & Development), QHSE, RAS (AI Engineering).

Chain rules (function `getManagerOf`):
1. Employee → their Dept Manager (same division+dept)
2. Dept Managers & Coordinators → their Division Manager
3. Division Managers → CEO
4. Employees in a dept with no Dept Manager → Division Manager
5. `DB.overrides[empId]` (admin-set) wins over all rules
6. Peers: `DB.peerMap[empId]` (admin-picked list) if set, otherwise auto
   (same division+dept+role). Subordinates of X rate X.

## Workflow states
- Evaluation submitted → status `pending` → rater can still edit
- HR Manager (admin) confirms in Approvals → status `confirmed` → locked forever,
  included in results. Reject deletes it (rater must resubmit).
- Results/radar/report use CONFIRMED evaluations only.

## Roles & visibility (enforce in every new feature)
- Admin (isAdmin, the HR Manager): everything — employees CRUD, rater control,
  approvals, org, all results, all trainings.
- CEO (isCEO): rates division managers.
- Managers (anyone with subordinates): see own team results & trainings only.
- Employee: own results, own trainings, own rating tasks. Rater identities are
  NEVER shown to the evaluated employee. Employee IDs/passwords visible to admin only.

## Trainings module
`DB.trainings`: {id, empId, name, axis (A1–A7 or GEN), level (basic/inter/adv),
type (course/workshop/ojt/cert/online), provider, startDate, durVal, durUnit,
status (planned/progress/done/cancel), notes, createdBy}.
Created/edited by the direct manager only. Shown to the employee, in results,
and in the printed report.

## Print report
`printReport()` builds a one-page A4 report into `#print-area` and calls
`window.print()`. Contains: employee info (name, ID, title, division, dept,
direct manager), behavioral table per rater group, technical KPIs table,
development plan, trainings, final grade + Arabic/English grade label,
three signature blocks (Employee / Direct Manager / HR Manager).
Keep it to ONE page when modifying.

## Data model quick reference
DB = {
  employees: [{id, pw, name, role, division, dept, isAdmin, isCEO, title, phone, email}],
  evaluations: [{id, targetId, raterId, type: self|manager|peer|subordinate,
                 scores: {A1:[..], ...}, tech: {T1..T4}, devPlan: {strengths, areas, goals, recommend},
                 status: pending|confirmed, date}],
  overrides: {empId: managerId},
  peerMap: {empId: [peerIds]},
  trainings: [...]
}
Storage keys: `rida360-db-v3`, `rida360-lang`.

## Planned migration (when asked to "move to Supabase" / production)
1. Tables: employees, evaluations, trainings, peer_assignments, manager_overrides
   (see supabase_schema.sql in this repo — apply it in the Supabase SQL editor).
2. Replace window.storage calls (saveDB/loadDB) with Supabase client queries.
3. Replace the custom login with Supabase Auth (email+password); store employee_id
   in user metadata; drop the pw field entirely.
4. Row Level Security: employees read own rows; managers read subordinates
   (via a manager_chain view); admin role reads/writes all.
5. Keep the UI and the calculation engine EXACTLY as they are — only swap the
   data layer. All computation stays client-side initially.

## Conventions for edits
- Keep everything in index.html until the Supabase migration (then split into
  /src if a build step is introduced).
- Any new user-facing string → add to BOTH T.en and T.ar.
- Any new page → add nav item in buildNav() with role gating, and a pgX() renderer
  wired in go().
- Test both languages and RTL after UI changes.
- Never expose other employees' IDs, passwords, or rater identities outside admin pages.
