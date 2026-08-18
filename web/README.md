# London Hotel Group — Property Information Hub

A single-page React app for managing property records across the London portfolio:
role-based access, per-property verification workflow, accommodation counts,
elevator/staircase registers, spreadsheet import, and CSV/Excel/PDF export.

## Requirements

- Node.js 18+ (developed against Node 22)

## Getting started

```bash
npm install
npm run dev
```

The dev server runs at http://localhost:5173.

## Scripts

| Script | Description |
| --- | --- |
| `npm run dev` | Start the Vite dev server with hot reload |
| `npm run build` | Produce a production build in `dist/` |
| `npm run preview` | Serve the production build locally |

## Project layout

```
index.html                 Vite entry document
london-property-hub.jsx    The application component (single file)
src/main.jsx               React root — mounts the component
src/index.css              Tailwind CSS entry
vite.config.js             Vite + React + Tailwind plugin config
```

## Stack

React 18, Vite 6, Tailwind CSS 4, Recharts, SheetJS (`xlsx`), lucide-react.

Fonts (Lora and Mulish) are loaded from Google Fonts at runtime by the
component itself, so the first render needs network access to look correct.
