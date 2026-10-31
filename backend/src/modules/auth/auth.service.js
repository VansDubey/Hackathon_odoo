import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";
import { pool } from "../../config/database.js";
import { env } from "../../config/env.js";

const PASSWORD_HASH_ROUNDS = 12;

function toPublicUser(row) {
  return {
    id: row.id,
    email: row.email,
    role: row.role,
    status: row.status,
    firstName: row.first_name,
    lastName: row.last_name,
    customerId: row.customer_id || null,
    createdAt: row.created_at
  };
}

function createAccessToken(user) {
  return jwt.sign(
    { sub: user.id, role: user.role },
    env.jwtSecret,
    { expiresIn: env.jwtExpiresIn }
  );
}

function handleDatabaseError(error) {
  if (error.code === "23505") {
    const conflict = new Error("An account with that email already exists");
    conflict.statusCode = 409;
    return conflict;
  }

  return error;
}

async function createUser(input, role) {
  const client = await pool.connect();

  try {
    await client.query("BEGIN");

    const userResult = await client.query(
      `INSERT INTO users (email, password_hash, role, first_name, last_name)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, email, role, status, first_name, last_name, created_at`,
      [input.email, await bcrypt.hash(input.password, PASSWORD_HASH_ROUNDS), role, input.firstName, input.lastName]
    );

    let user = userResult.rows[0];

    if (role === "CUSTOMER") {
      const customerResult = await client.query(
        `INSERT INTO customers (user_id, legal_name, display_name, billing_email)
         VALUES ($1, $2, $2, $3)
         RETURNING id AS customer_id`,
        [user.id, `${input.firstName} ${input.lastName}`, input.email]
      );
      user = { ...user, customer_id: customerResult.rows[0].customer_id };
    }

    await client.query("COMMIT");
    return user;
  } catch (error) {
    await client.query("ROLLBACK");
    throw handleDatabaseError(error);
  } finally {
    client.release();
  }
}

export async function registerCustomer(input) {
  const user = await createUser(input, "CUSTOMER");
  const publicUser = toPublicUser(user);

  return {
    user: publicUser,
    token: createAccessToken(publicUser)
  };
}

export async function createStaff(input) {
  const user = await createUser(input, "STAFF");
  const publicUser = toPublicUser(user);

  return {
    user: publicUser,
    token: createAccessToken(publicUser)
  };
}

export async function authenticateUser(email, password) {
  const result = await pool.query(
    `SELECT u.id, u.email, u.password_hash, u.role, u.status,
            u.first_name, u.last_name, u.created_at, c.id AS customer_id
     FROM users u
     LEFT JOIN customers c ON c.user_id = u.id
     WHERE u.email = $1`,
    [email]
  );

  const user = result.rows[0];
  const passwordMatches = user && await bcrypt.compare(password, user.password_hash);

  if (!user || !passwordMatches || user.status !== "ACTIVE") {
    const error = new Error("Invalid email or password");
    error.statusCode = 401;
    throw error;
  }

  await pool.query("UPDATE users SET last_login_at = NOW(), updated_at = NOW() WHERE id = $1", [user.id]);

  const publicUser = toPublicUser(user);
  return {
    user: publicUser,
    token: createAccessToken(publicUser)
  };
}

export async function findActiveUserById(userId) {
  const result = await pool.query(
    `SELECT u.id, u.email, u.role, u.status, u.first_name, u.last_name,
            u.created_at, c.id AS customer_id
     FROM users u
     LEFT JOIN customers c ON c.user_id = u.id
     WHERE u.id = $1 AND u.status = 'ACTIVE'`,
    [userId]
  );

  return result.rows[0] || null;
}

export { toPublicUser };
