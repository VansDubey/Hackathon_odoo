import "dotenv/config";

function parsePort(value) {
  const port = Number(value || 5000);

  if (!Number.isInteger(port) || port < 1 || port > 65535) {
    throw new Error("PORT must be an integer between 1 and 65535");
  }

  return port;
}

function parseBoolean(value, defaultValue = false) {
  if (value === undefined) {
    return defaultValue;
  }

  if (value !== "true" && value !== "false") {
    throw new Error("DATABASE_SSL must be either true or false");
  }

  return value === "true";
}

function validateClientUrl(value) {
  try {
    return new URL(value || "http://localhost:5173").origin;
  } catch {
    throw new Error("CLIENT_URL must be a valid URL");
  }
}

const databaseUrl = process.env.DATABASE_URL?.trim();

if (!databaseUrl) {
  throw new Error("DATABASE_URL is not configured");
}

export const env = Object.freeze({
  nodeEnv: process.env.NODE_ENV || "development",
  port: parsePort(process.env.PORT),
  clientUrl: validateClientUrl(process.env.CLIENT_URL),
  databaseUrl,
  databaseSsl: parseBoolean(process.env.DATABASE_SSL)
});
