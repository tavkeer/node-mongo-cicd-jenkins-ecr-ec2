const express = require("express");
const mongoose = require("mongoose");

const app = express();
const PORT = process.env.PORT || 3000;
const MONGO_URI = process.env.MONGO_URI || "mongodb://mongo:27017/devopsapp";

let serverStarted = false;

app.use(express.json());

const noteSchema = new mongoose.Schema(
  {
    title: {
      type: String,
      required: true,
      trim: true,
    },
    content: {
      type: String,
      required: true,
      trim: true,
    },
  },
  {
    timestamps: true,
  }
);

const Note = mongoose.model("Note", noteSchema);

app.get("/", (req, res) => {
  res.json({
    message: "DevOps base app is running.",
    project: "Node.js + MongoDB base project",
    endpoints: ["GET /health", "GET /api/notes", "POST /api/notes"],
  });
});

app.get("/health", (req, res) => {
  const isDbConnected = mongoose.connection.readyState === 1;

  res.status(isDbConnected ? 200 : 503).json({
    status: isDbConnected ? "UP" : "DOWN",
    app: "running",
    database: isDbConnected ? "connected" : "disconnected",
    uptimeSeconds: process.uptime(),
    timestamp: new Date().toISOString(),
  });
});

app.get("/api/notes", async (req, res) => {
  try {
    const notes = await Note.find().sort({ createdAt: -1 });
    res.status(200).json(notes);
  } catch (error) {
    res.status(500).json({ message: "Failed to fetch notes", error: error.message });
  }
});

app.post("/api/notes", async (req, res) => {
  try {
    const { title, content } = req.body;

    if (!title || !content) {
      return res.status(400).json({ message: "title and content are required" });
    }

    const note = await Note.create({ title, content });
    res.status(201).json(note);
  } catch (error) {
    res.status(500).json({ message: "Failed to create note", error: error.message });
  }
});

async function connectWithRetry() {
  try {
    await mongoose.connect(MONGO_URI);
    console.log("MongoDB connected successfully");

    if (!serverStarted) {
      app.listen(PORT, () => {
        serverStarted = true;
        console.log(`New Server is listening on port ${PORT}`);
      });
    }
  } catch (error) {
    console.error("MongoDB connection failed. Retrying in 5 seconds...");
    console.error(error.message);
    setTimeout(connectWithRetry, 5000);
  }
}

connectWithRetry();
