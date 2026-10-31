import "dotenv/config";
import app from "./app.js";
import { env } from "./config/env.js";
import { closeDatabase, connectDatabase } from "./config/database.js";

let server;
let shuttingDown = false;

async function startServer() {
  await connectDatabase();

  server = app.listen(env.port, () => {
    console.log(`Backend server running on http://localhost:${env.port}`);
  });
}

async function shutdown(signal) {
  if (shuttingDown) {
    return;
  }

  shuttingDown = true;
  console.log(`Received ${signal}; shutting down gracefully`);

  try {
    if (server) {
      await new Promise((resolve, reject) => {
        server.close((error) => (error ? reject(error) : resolve()));
      });
    }

    await closeDatabase();
    process.exit(0);
  } catch (error) {
    console.error("Graceful shutdown failed", error);
    process.exit(1);
  }
}

process.on("SIGINT", () => shutdown("SIGINT"));
process.on("SIGTERM", () => shutdown("SIGTERM"));

startServer().catch((error) => {
  console.error("Unable to start the backend", error);
  process.exit(1);
});
