const express = require("express");
const { Client } = require("pg");

const app = express();
const PORT = 3000;

// Instance name from environment variable
const INSTANCE_NAME = process.env.INSTANCE_NAME || "unknown-instance";

/*
app.get("/health", (req, res) => {
  res.send(`OK from ${INSTANCE_NAME}`);
});
*/

app.get("/health", async (req, res) => {
  const dbConfig = {
    host: process.env.DB_HOST,
    port: Number(process.env.DB_PORT || 5432),
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
  };

  let dbStatus = "SKIPPED";

  // Ha nincs beállítva DB config, ne dobjon hibát, csak jelezze
  if (dbConfig.host && dbConfig.user && dbConfig.password && dbConfig.database) {
    const client = new Client(dbConfig);

    try {
      await client.connect();
      await client.query("SELECT 1");
      dbStatus = "OK";
    } catch (err) {
      dbStatus = "FAIL";
    } finally {
      // fontos: zárjuk a kapcsolatot
      try { await client.end(); } catch (_) {}
    }
  }

  res.send(`OK from ${INSTANCE_NAME} | DB: ${dbStatus}`);
});

app.listen(PORT, () => {
  console.log(`Server running on port ${PORT}`);
});
