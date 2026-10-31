import fs from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { pool } from "../config/database.js";

const currentDirectory = path.dirname(fileURLToPath(import.meta.url));
const migrationsDirectory = path.join(currentDirectory, "migrations");

async function runMigrations() {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");
    await client.query(`
      CREATE TABLE IF NOT EXISTS schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
      )
    `);

    const migrationFiles = (await fs.readdir(migrationsDirectory))
      .filter((fileName) => fileName.endsWith(".sql"))
      .sort();

    for (const migrationFile of migrationFiles) {
      const alreadyApplied = await client.query(
        "SELECT 1 FROM schema_migrations WHERE version = $1",
        [migrationFile]
      );

      if (alreadyApplied.rowCount > 0) {
        continue;
      }

      const migrationPath = path.join(migrationsDirectory, migrationFile);
      const migrationSql = await fs.readFile(migrationPath, "utf8");
      await client.query(migrationSql);
      await client.query(
        "INSERT INTO schema_migrations (version) VALUES ($1)",
        [migrationFile]
      );
      console.log(`Applied migration: ${migrationFile}`);
    }

    await client.query("COMMIT");
  } catch (error) {
    await client.query("ROLLBACK");
    throw error;
  } finally {
    client.release();
    await pool.end();
  }
}

runMigrations().catch((error) => {
  console.error("Database migration failed", error);
  process.exitCode = 1;
});
