import "dotenv/config";
import app from "./app.js";
import { closeDatabase, connectDatabase } from "./config/database.js";

const port = process.env.PORT || 5000;

async function startServer() {
  await connectDatabase();

  const server = app.listen(port, () => {
    console.log(`Backend server running on http://localhost:${port}`);
  });

  const shutdown = async () => {
    server.close(async () => {
      await closeDatabase();
      process.exit(0);
    });
  };

  process.on("SIGINT", shutdown);
  process.on("SIGTERM", shutdown);
}

startServer().catch((error) => {
  console.error("Unable to start the backend", error);
  process.exit(1);
});
