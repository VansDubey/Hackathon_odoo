import jwt from "jsonwebtoken";
import { env } from "../config/env.js";
import { findActiveUserById, toPublicUser } from "../modules/auth/auth.service.js";

function unauthorized(message = "Authentication required") {
  const error = new Error(message);
  error.statusCode = 401;
  return error;
}

export async function requireAuth(req, res, next) {
  try {
    const authorization = req.headers.authorization || "";
    const [scheme, token] = authorization.split(" ");

    if (scheme !== "Bearer" || !token) {
      throw unauthorized();
    }

    const payload = jwt.verify(token, env.jwtSecret);
    const user = await findActiveUserById(payload.sub);

    if (!user) {
      throw unauthorized("User account is inactive or no longer exists");
    }

    req.user = toPublicUser(user);
    next();
  } catch (error) {
    if (error.name === "JsonWebTokenError" || error.name === "TokenExpiredError") {
      return next(unauthorized("Invalid or expired token"));
    }

    next(error);
  }
}

export function requireRole(...allowedRoles) {
  return (req, res, next) => {
    if (!req.user || !allowedRoles.includes(req.user.role)) {
      const error = new Error("You do not have permission to perform this action");
      error.statusCode = 403;
      return next(error);
    }

    next();
  };
}

export function requireCustomerOwner(req, res, next) {
  if (req.user?.role !== "CUSTOMER") {
    return next();
  }

  if (req.user.customerId !== req.params.customerId) {
    const error = new Error("You can only access your own customer records");
    error.statusCode = 403;
    return next(error);
  }

  next();
}
