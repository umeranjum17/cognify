import { getAdminDb } from '../shared/firebase-admin';

export const config = { runtime: 'nodejs18.x' };

// Tier configurations for monthly allowances
const TIER_ALLOWANCES: Record<string, number> = {
  'premium_monthly': 100,
  'premium_annual': 100,
  'free': 10, // Free tier fallback
};

// Extract subscription tier from product ID
function getTierFromProductId(productId: string): string {
  if (productId.includes('annual')) return 'premium_annual';
  if (productId.includes('monthly')) return 'premium_monthly';
  return 'free';
}

// Extract period dates from RevenueCat payload
function extractPeriodDates(payload: any): { periodStart: string | null; periodEnd: string | null } {
  // Try multiple paths where RevenueCat might put period data
  const periodEnd = 
    payload?.expiration_at_ms || 
    payload?.event?.expiration_at_ms ||
    payload?.product_data?.expiration_date ||
    payload?.event?.product_data?.expiration_date;
  
  const periodStart = 
    payload?.purchased_at_ms ||
    payload?.event?.purchased_at_ms ||
    payload?.original_purchase_date ||
    payload?.event?.original_purchase_date;

  return {
    periodStart: periodStart ? new Date(periodStart).toISOString() : null,
    periodEnd: periodEnd ? new Date(periodEnd).toISOString() : null,
  };
}

export default async function handler(req: Request) {
  const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'POST, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  } as const;

  if (req.method === 'OPTIONS') {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return new Response('Method Not Allowed', { status: 405, headers: corsHeaders });
  }

  const secret = (process as any).env.RC_WEBHOOK_SECRET;
  if (!secret) {
    return new Response('Server misconfigured', { status: 500, headers: corsHeaders });
  }

  const auth = req.headers.get('authorization') || '';
  if (auth !== `Bearer ${secret}`) {
    return new Response('Unauthorized', { status: 401, headers: corsHeaders });
  }

  const db = getAdminDb();

  try {
    const payload = await req.json();
    const eventId: string = payload?.event_id || payload?.id || '';
    if (!eventId) {
      return new Response('Bad Request', { status: 400, headers: corsHeaders });
    }

    const appUserId: string = payload?.app_user_id || payload?.event?.app_user_id || '';
    if (!appUserId) {
      return new Response('Bad Request', { status: 400, headers: corsHeaders });
    }

    const type: string = payload?.type || payload?.event?.type || '';
    const productId: string = payload?.product_id || payload?.event?.product_id || '';

    const idempotencyRef = db.collection('revenuecat_events').doc(eventId);
    const subscriptionRef = db.collection('users').doc(appUserId).collection('subscription').doc('current');

    const result = await db.runTransaction(async (tx: any) => {
      const seen = await tx.get(idempotencyRef);
      if (seen.exists) {
        return { duplicated: true };
      }

      const { periodStart, periodEnd } = extractPeriodDates(payload);
      const tier = getTierFromProductId(productId);
      const monthlyAllowance = TIER_ALLOWANCES[tier] || TIER_ALLOWANCES['free'];
      const now = new Date().toISOString();

      // Handle subscription events
      if (type.includes('INITIAL_PURCHASE') || type.includes('RENEWAL')) {
        // Active subscription - sync metadata and reset credits for new period
        tx.set(subscriptionRef, {
          status: 'active',
          tier: tier,
          productId: productId,
          currentPeriodStart: periodStart || now,
          currentPeriodEnd: periodEnd || new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toISOString(),
          monthlyAllowance: monthlyAllowance,
          consumed: 0, // Reset on new period
          lastSyncedFromRC: now,
          updatedAt: now,
        }, { merge: true });

        // Log event
        tx.set(idempotencyRef, { 
          handledAt: now, 
          appUserId, 
          type, 
          action: 'subscription_activated',
          tier,
          monthlyAllowance,
        });

        return { duplicated: false, action: 'subscription_activated', tier, allowance: monthlyAllowance };
      } 
      else if (type.includes('CANCELLATION')) {
        // Subscription cancelled - mark as cancelled but keep access until period ends
        const currentSub = await tx.get(subscriptionRef);
        const currentData = currentSub.exists ? currentSub.data() : {};
        
        tx.set(subscriptionRef, {
          ...currentData,
          status: 'cancelled',
          cancelledAt: now,
          lastSyncedFromRC: now,
          updatedAt: now,
        }, { merge: true });

        tx.set(idempotencyRef, { 
          handledAt: now, 
          appUserId, 
          type, 
          action: 'subscription_cancelled',
        });

        return { duplicated: false, action: 'subscription_cancelled' };
      }
      else if (type.includes('EXPIRATION')) {
        // Subscription expired - downgrade to free tier
        tx.set(subscriptionRef, {
          status: 'expired',
          tier: 'free',
          productId: null,
          monthlyAllowance: TIER_ALLOWANCES['free'],
          consumed: 0, // Reset to free tier allowance
          expiredAt: now,
          lastSyncedFromRC: now,
          updatedAt: now,
        }, { merge: true });

        tx.set(idempotencyRef, { 
          handledAt: now, 
          appUserId, 
          type, 
          action: 'subscription_expired',
        });

        return { duplicated: false, action: 'subscription_expired' };
      }
      else if (type.includes('PRODUCT_REFUND')) {
        // Refund - immediately expire subscription
        tx.set(subscriptionRef, {
          status: 'refunded',
          tier: 'free',
          productId: null,
          monthlyAllowance: TIER_ALLOWANCES['free'],
          consumed: 0,
          refundedAt: now,
          lastSyncedFromRC: now,
          updatedAt: now,
        }, { merge: true });

        tx.set(idempotencyRef, { 
          handledAt: now, 
          appUserId, 
          type, 
          action: 'subscription_refunded',
        });

        return { duplicated: false, action: 'subscription_refunded' };
      }
      else {
        // Unknown event - just log it
        tx.set(idempotencyRef, { 
          handledAt: now, 
          appUserId, 
          type, 
          action: 'logged_only',
        });
        return { duplicated: false, action: 'logged_only', type };
      }
    });

    return new Response(JSON.stringify({ success: true, ...result }), {
      status: 200,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  } catch (e: any) {
    console.error('RevenueCat webhook error:', e);
    return new Response(JSON.stringify({ success: false, error: e?.message || 'Unhandled' }), {
      status: 500,
      headers: { 'Content-Type': 'application/json', ...corsHeaders },
    });
  }
}
