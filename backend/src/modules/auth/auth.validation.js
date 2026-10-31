const PASSWORD_PATTERN = /^(?=.*[a-z])(?=.*[A-Z])(?=.*[^A-Za-z0-9]).{9,}$/;
const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

function validationError(message) {
  const error = new Error(message);
  error.statusCode = 400;
  return error;
}

export function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

export function validatePassword(password) {
  if (!PASSWORD_PATTERN.test(String(password || ""))) {
    throw validationError(
      "Password must be more than 8 characters and include uppercase, lowercase, and special characters"
    );
  }
}

function validateName(value, fieldName) {
  const name = String(value || "").trim();

  if (!name || name.length > 100) {
    throw validationError(`${fieldName} is required and must be 100 characters or fewer`);
  }

  return name;
}

function validateEmail(email) {
  const normalizedEmail = normalizeEmail(email);

  if (normalizedEmail.length > 320 || !EMAIL_PATTERN.test(normalizedEmail)) {
    throw validationError("A valid email is required");
  }

  return normalizedEmail;
}

export function validateRegistrationInput(input = {}) {
  const email = validateEmail(input.email);
  const firstName = validateName(input.firstName, "firstName");
  const lastName = validateName(input.lastName, "lastName");
  const password = String(input.password || "");
  validatePassword(password);

  return { email, firstName, lastName, password };
}

export function validateLoginInput(input = {}) {
  const email = validateEmail(input.email);
  const password = String(input.password || "");

  if (!password) {
    throw validationError("Password is required");
  }

  return { email, password };
}

export function validateStaffInput(input = {}) {
  return validateRegistrationInput(input);
}
