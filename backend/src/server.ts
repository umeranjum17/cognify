import express from 'express';
import cors from 'cors';
import helmet from 'helmet';
import morgan from 'morgan';
import dotenv from 'dotenv';
import { chatRouter } from './routes/chat.js';
import { configRouter } from './routes/config.js';
import { creditsRouter } from './routes/credits.js';
import { mermaidRouter } from './routes/mermaid.js';
import { oauthRouter } from './routes/oauth.js';
import { webhookRouter } from './routes/webhook.js';
import { errorHandler } from './middleware/errorHandler.js';
import { devAuthRouter } from './routes/devauth.js';

// Load environment variables
dotenv.config();

const app = express();
const PORT = process.env.PORT || 3000;

// Security middleware
app.use(helmet());
app.use(cors({
  origin: '*',
  credentials: true,
  methods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With']
}));

// Logging
app.use(morgan('dev'));

// Body parser
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true }));

// Health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// API Routes
app.use('/api/chat', chatRouter);
app.use('/api/config', configRouter);
app.use('/api/credits', creditsRouter);
app.use('/api/mermaid', mermaidRouter);
app.use('/api/oauth', oauthRouter);
app.use('/api/rc', webhookRouter);
app.use('/api/devauth', devAuthRouter);

// Error handling
app.use(errorHandler);

// 404 handler
app.use((req, res) => {
  res.status(404).json({ error: 'Not found' });
});

// Start server
app.listen(PORT, () => {
  console.log(`🚀 Cognify Backend Server running on port ${PORT}`);
  console.log(`📍 Environment: ${process.env.NODE_ENV || 'development'}`);
  console.log(`🔗 Health check: http://localhost:${PORT}/health`);
});

export default app;

