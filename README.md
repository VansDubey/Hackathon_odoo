# Subscription Management & Recurring Billing System

JavaScript monorepo for the Brightloop-inspired subscription management platform.

## Structure

- `backend`: Express and PostgreSQL API.
- `frontend`: React and Vite application.
- `plan.md`: implementation roadmap.

## Start the project

```bash
npm install
npm run install:all
npm run dev
```

The backend runs on `http://localhost:5000` and the frontend runs on `http://localhost:5173`.

Copy `backend/.env.example` to `backend/.env`, then update `DATABASE_URL` with your PostgreSQL credentials.
