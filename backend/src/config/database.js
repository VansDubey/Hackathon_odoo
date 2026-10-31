import pg from "pg";
import { env } from "./env.js";

const { Pool } = pg;

export const pool = new Pool({
  connectionString: env.databaseUrl,
  ssl: env.databaseSsl ? { rejectUnauthorized: false } : false
});

export async function connectDatabase() {
  await pool.query("SELECT 1");
  console.log("Connected to PostgreSQL");
}

export async function closeDatabase() {
  await pool.end();
}
