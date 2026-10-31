import express from "express";
import cors from "cors";
import helmet from "helmet";
import { env } from "./config/env.js";
import { pool } from "./config/database.js";
import { errorHandler, notFoundHandler } from "./middleware/error-handler.js";

const app = express();

app.use(helmet());
app.use(cors({ origin: env.clientUrl }));
app.use(express.json({ limit: "1mb" }));
app.use((req, res, next) => {
  const startedAt = Date.now();

  res.on("finish", () => {
    const duration = Date.now() - startedAt;
    console.log(`${req.method} ${req.originalUrl} ${res.statusCode} ${duration}ms`);
  });

  next();
});

app.get("/api/health", async (req, res, next) => {
  try {
    await pool.query("SELECT 1");
    res.json({
      status: "ok",
      service: "subscription-management-api",
      database: "ok"
    });
  } catch (error) {
    next(error);
  }
});

app.use(notFoundHandler);
app.use(errorHandler);

export default app;
