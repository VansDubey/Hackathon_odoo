import { Router } from "express";
import { requireAuth, requireRole } from "../../middleware/auth.js";
import {
  authenticateUser,
  createStaff,
  registerCustomer
} from "./auth.service.js";
import {
  validateLoginInput,
  validateRegistrationInput,
  validateStaffInput
} from "./auth.validation.js";

const router = Router();

router.post("/register", async (req, res, next) => {
  try {
    const input = validateRegistrationInput(req.body);
    const result = await registerCustomer(input);
    res.status(201).json(result);
  } catch (error) {
    next(error);
  }
});

router.post("/login", async (req, res, next) => {
  try {
    const input = validateLoginInput(req.body);
    const result = await authenticateUser(input.email, input.password);
    res.json(result);
  } catch (error) {
    next(error);
  }
});

router.post("/staff", requireAuth, requireRole("ADMIN"), async (req, res, next) => {
  try {
    const input = validateStaffInput(req.body);
    const result = await createStaff(input);
    res.status(201).json(result);
  } catch (error) {
    next(error);
  }
});

router.get("/me", requireAuth, (req, res) => {
  res.json({ user: req.user });
});

export default router;
