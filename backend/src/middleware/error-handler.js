export function notFoundHandler(req, res) {
  res.status(404).json({
    message: `Route not found: ${req.method} ${req.originalUrl}`
  });
}

export function errorHandler(error, req, res, next) {
  console.error(error);

  res.status(error.statusCode || 500).json({
    message: error.statusCode ? error.message : "Internal server error",
    ...(process.env.NODE_ENV === "development" && { error: error.message })
  });
}
