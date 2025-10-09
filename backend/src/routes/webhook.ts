import express from 'express';

export const webhookRouter = express.Router();

// POST /api/rc/webhook - RevenueCat webhook handler
webhookRouter.post('/webhook', async (req, res) => {
  try {
    const authHeader = req.headers.authorization;
    const expectedSecret = process.env.RC_WEBHOOK_SECRET;
    
    if (!authHeader || !expectedSecret) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }
    
    const parts = authHeader.split(' ');
    if (parts.length !== 2 || parts[0] !== 'Bearer' || parts[1] !== expectedSecret) {
      res.status(401).json({ error: 'Invalid authorization' });
      return;
    }
    
    const { event } = req.body;
    
    if (!event) {
      res.status(400).json({ error: 'Missing event data' });
      return;
    }
    
    // Process webhook event
    console.log('RevenueCat webhook received:', event.type);
    
    // TODO: Implement webhook processing logic
    // - Update user subscription status
    // - Grant/revoke premium features
    // - Update credits balance
    
    res.json({ received: true });
  } catch (error: any) {
    console.error('Webhook error:', error);
    res.status(500).json({ error: 'Webhook processing failed' });
  }
});

