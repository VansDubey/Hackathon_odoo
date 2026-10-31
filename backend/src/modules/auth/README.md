# Authentication

Endpoints:

- `POST /api/auth/register` creates a Customer account and customer profile.
- `POST /api/auth/login` authenticates an active account and returns a JWT.
- `GET /api/auth/me` returns the authenticated user.
- `POST /api/auth/staff` creates a Staff account and requires an Admin JWT.

Passwords must be at least 9 characters and contain uppercase, lowercase, and special characters. Passwords are stored as bcrypt hashes. Public registration always creates a Customer; roles cannot be selected by the client.

Set `JWT_SECRET` to a random value of at least 32 characters in `backend/.env`.
