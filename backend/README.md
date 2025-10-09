# Cognify Backend Server

A clean, production-ready Express backend for the Cognify AI app.

## 🎯 Features

- ✅ Express.js with TypeScript
- ✅ Firebase Authentication & Firestore
- ✅ Credit management system
- ✅ RESTful API endpoints
- ✅ CORS & Security headers (Helmet)
- ✅ Request logging (Morgan)
- ✅ Docker support
- ✅ Easy deployment

## 📁 Project Structure

```
backend/
├── src/
│   ├── server.ts              # Main server file
│   ├── routes/                # API route handlers
│   │   ├── chat.ts           # Chat endpoint
│   │   ├── config.ts         # Configuration endpoints
│   │   ├── credits.ts        # Credit management
│   │   ├── mermaid.ts        # Mermaid diagram generation
│   │   ├── oauth.ts          # OAuth callback
│   │   └── webhook.ts        # RevenueCat webhooks
│   ├── middleware/           # Express middleware
│   │   ├── auth.ts          # Firebase auth middleware
│   │   └── errorHandler.ts # Global error handler
│   ├── services/            # Business logic
│   │   └── firebase.ts     # Firebase Admin SDK
│   └── config/             # Configuration
│       └── config-data.ts  # App configuration data
├── tests/
│   └── api-security.test.js # API security tests
├── Dockerfile              # Docker configuration
├── docker-compose.yml     # Docker Compose setup
└── package.json          # Dependencies

```

## 🚀 Getting Started

### Prerequisites

- Node.js 18+
- npm or yarn
- Firebase project with Admin SDK credentials

### Installation

1. Install dependencies:
```bash
cd backend
npm install
```

2. Configure environment variables:
```bash
cp .env.example .env
```

Edit `.env` and add your credentials:
```env
# Firebase Admin SDK
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=your-client-email
FIREBASE_PRIVATE_KEY=your-private-key

# Firebase API Key (for testing)
FIREBASE_API_KEY=your-api-key

# OpenAI / AI Provider
OPENAI_API_KEY=your-openai-key
OPENROUTER_API_KEY=your-openrouter-key

# RevenueCat
RC_WEBHOOK_SECRET=your-revenuecat-webhook-secret

# Server Configuration
PORT=3000
NODE_ENV=development
```

### Development

Run in development mode with hot reload:
```bash
npm run dev
```

The server will start on http://localhost:3000

### Testing

Run API security tests:
```bash
# Make sure the server is running first
npm run dev

# In another terminal:
cd /path/to/cognify-flutter
./test-backend.sh
```

Or run tests manually:
```bash
export API_BASE="http://localhost:3000"
export FIREBASE_API_KEY="your-api-key"
export TEST_EMAIL="test@cognify.com"
export TEST_PASSWORD="testpass123"
node tests/api-security.test.js
```

### Production Build

Build TypeScript:
```bash
npm run build
```

Run production server:
```bash
npm start
```

## 🐳 Docker Deployment

### Build and run with Docker:

```bash
# Build the image
docker build -t cognify-backend .

# Run the container
docker run -p 3000:3000 --env-file .env cognify-backend
```

### Or use Docker Compose:

```bash
docker-compose up -d
```

Stop the container:
```bash
docker-compose down
```

## 📡 API Endpoints

### Public Endpoints
- `GET /health` - Health check
- `GET /api/oauth/callback` - OAuth callback handler

### Protected Endpoints (Require Firebase Auth Token)

#### Configuration
- `GET /api/config` - Get all configuration
- `GET /api/config/app` - App configuration
- `GET /api/config/models` - Available models
- `GET /api/config/modes` - Available modes
- `GET /api/config/pricing` - Pricing information

#### Credits
- `GET /api/credits/balance` - Get user's credit balance
- `POST /api/credits/consume` - Consume credits
- `POST /api/credits/refund` - Refund credits

#### Chat
- `POST /api/chat` - Main chat endpoint (supports multiple modes)

#### Mermaid
- `POST /api/mermaid/generate` - Generate Mermaid diagrams

### Webhook Endpoints
- `POST /api/rc/webhook` - RevenueCat webhook handler (requires secret)

## 🔒 Authentication

All protected endpoints require a Firebase ID token in the Authorization header:

```bash
Authorization: Bearer <firebase-id-token>
```

Example with curl:
```bash
curl -H "Authorization: Bearer <token>" http://localhost:3000/api/credits/balance
```

## 🧪 Test Results

All security tests passing:
- ✅ Health check working
- ✅ Unauthenticated requests properly blocked (401)
- ✅ OAuth callback working
- ✅ Webhook authorization working
- ✅ Authenticated requests working with valid tokens
- ✅ All config endpoints returning correct data
- ✅ Credits system working
- ✅ Chat endpoint responding

## 🌐 Deployment Options

### 1. **Railway**
```bash
# Install Railway CLI
npm install -g @railway/cli

# Login and deploy
railway login
railway init
railway up
```

### 2. **Render**
- Connect your GitHub repo
- Set environment variables
- Deploy with one click

### 3. **Heroku**
```bash
heroku create cognify-backend
heroku config:set FIREBASE_PROJECT_ID=...
git push heroku main
```

### 4. **DigitalOcean App Platform**
- Import from GitHub
- Configure environment variables
- Deploy

### 5. **Self-hosted (PM2)**
```bash
# Install PM2
npm install -g pm2

# Build and start
npm run build
pm2 start dist/server.js --name cognify-backend

# Setup auto-restart on reboot
pm2 startup
pm2 save
```

## 📝 Environment Variables

| Variable | Required | Description |
|----------|----------|-------------|
| `FIREBASE_PROJECT_ID` | Yes | Firebase project ID |
| `FIREBASE_CLIENT_EMAIL` | Yes | Firebase service account email |
| `FIREBASE_PRIVATE_KEY` | Yes | Firebase service account private key |
| `FIREBASE_API_KEY` | For tests | Firebase web API key |
| `OPENAI_API_KEY` | Optional | OpenAI API key |
| `OPENROUTER_API_KEY` | Optional | OpenRouter API key |
| `RC_WEBHOOK_SECRET` | Optional | RevenueCat webhook secret |
| `PORT` | No | Server port (default: 3000) |
| `NODE_ENV` | No | Environment (development/production) |

## 🛠️ Tech Stack

- **Express.js** - Web framework
- **TypeScript** - Type safety
- **Firebase Admin SDK** - Authentication & Database
- **Helmet** - Security headers
- **Morgan** - Request logging
- **CORS** - Cross-origin resource sharing
- **Zod** - Schema validation
- **AI SDK** - AI integrations

## 📊 Monitoring

The server includes:
- Health check endpoint at `/health`
- Request logging with Morgan
- Error handling middleware
- Docker health checks

## 🤝 Contributing

1. Make changes in `src/`
2. Test with `npm run dev`
3. Run tests with `./test-backend.sh`
4. Build with `npm run build`
5. Commit and push

## 📄 License

Private - Cognify App

---

**Made with ❤️ for Cognify**

