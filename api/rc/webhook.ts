import { getAdminDb } from '../shared/firebase-admin.js';

export const config = { runtime: 'nodejs' };

// Default tier allowances used if no remote config is present
const DEFAULT_TIER_ALLOWANCES: Record<string, number> = {
  premium_monthly: 100,
  premium_annual: 100,
  free: 10,
};

type SubscriptionsConfigDoc = {
  tierAllowances?: Record<string, number>;
  // Map of exact store product IDs to internal tier keys
  // Example: { 'com.acme.premium.monthly': 'premium_monthly' }
  productTiers?: Record<string, string>;
};

async function loadSubscriptionsConfig(db: FirebaseFirestore.Firestore): Promise<{
  allowances: Record<string, number>;
  productTiers: Record<string, string>;
}> {
  try {
    const snap = await db.collection('config').doc('subscriptions').get();
    if (!snap.exists) {
      return { allowances: DEFAULT_TIER_ALLOWANCES, productTiers: {} };
    }
    const data = (snap.data() || {}) as SubscriptionsConfigDoc;
    const allowances = data.tierAllowances && Object.keys(data.tierAllowances).length > 0
      ? data.tierAllowances
      : DEFAULT_TIER_ALLOWANCES;
    const productTiers = data.productTiers || {};
    return { allowances, productTiers };
  } catch {
    // On any error, use defaults
    return { allowances: DEFAULT_TIER_ALLOWANCES, productTiers: {} };
  }
}

// Load mapping for consumable products → credit units to grant
async function loadConsumablesConfig(db: FirebaseFirestore.Firestore): Promise<{
  productCredits: Record<string, number>;
}> {
  try {
    const snap = await db.collection('config').doc('consumables').get();
    if (!snap.exists) {
      return { productCredits: {} };
    }
    const data = (snap.data() || {}) as any;
    const productCredits = (data.productCredits || {}) as Record<string, number>;
    return { productCredits };
  } catch {
    return { productCredits: {} };
  }
}

// Resolve internal tier from a product ID using explicit mapping first, then a safe heuristic
function getTierFromProductId(productId: string, productTiers: Record<string, string>): string {
  const mapped = productTiers[productId];
  if (mapped) return mapped;
  // Heuristic fallback if explicit mapping not configured
  const id = productId.toLowerCase();
  if (id.includes('annual') || id.includes('year')) return 'premium_annual';
  if (id.includes('monthly') || id.includes('month')) return 'premium_monthly';
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
    const environment: string | null = payload?.environment || payload?.event?.environment || null;
    const productId: string = payload?.product_id || payload?.event?.product_id || '';

    const idempotencyRef = db.collection('revenuecat_events').doc(eventId);
    const subscriptionRef = db.collection('users').doc(appUserId).collection('subscription').doc('current');

    // Load dynamic configuration (allowances and SKU→tier mapping)
    const { allowances, productTiers } = await loadSubscriptionsConfig(db);

    const result = await db.runTransaction(async (tx: any) => {
      const seen = await tx.get(idempotencyRef);
      if (seen.exists) {
        return { duplicated: true };
      }

      const { periodStart, periodEnd } = extractPeriodDates(payload);
      const tier = getTierFromProductId(productId, productTiers);
      const monthlyAllowance = allowances[tier] ?? allowances['free'] ?? DEFAULT_TIER_ALLOWANCES.free;
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
          environment: environment,
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
          environment,
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
          environment: environment,
          updatedAt: now,
        }, { merge: true });

        tx.set(idempotencyRef, { 
          handledAt: now, 
          appUserId, 
          type, 
          action: 'subscription_cancelled',
          environment,
        });

        return { duplicated: false, action: 'subscription_cancelled' };
      }
      else if (type.includes('UNCANCELLATION')) {
        // Subscription was uncancelled - mark back to active
        const { periodStart, periodEnd } = extractPeriodDates(payload);
        tx.set(subscriptionRef, {
          status: 'active',
          tier: tier,
          productId: productId,
          currentPeriodStart: periodStart || now,
          currentPeriodEnd: periodEnd || undefined,
          lastSyncedFromRC: now,
          environment: environment,
          updatedAt: now,
        }, { merge: true });

        tx.set(idempotencyRef, {
          handledAt: now,
          appUserId,
          type,
          action: 'subscription_uncancelled',
          environment,
        });

        return { duplicated: false, action: 'subscription_uncancelled' };
      }
      else if (type.includes('EXPIRATION')) {
        // Subscription expired - downgrade to free tier
        tx.set(subscriptionRef, {
          status: 'expired',
          tier: 'free',
          productId: null,
          monthlyAllowance: allowances['free'] ?? DEFAULT_TIER_ALLOWANCES.free,
          consumed: 0, // Reset to free tier allowance
          expiredAt: now,
          lastSyncedFromRC: now,
          environment: environment,
          updatedAt: now,
        }, { merge: true });

        tx.set(idempotencyRef, { 
          handledAt: now, 
          appUserId, 
          type, 
          action: 'subscription_expired',
          environment,
        });

        return { duplicated: false, action: 'subscription_expired' };
      }
      else if (type.includes('PRODUCT_REFUND')) {
        // Refund - immediately expire subscription
        tx.set(subscriptionRef, {
          status: 'refunded',
          tier: 'free',
          productId: null,
          monthlyAllowance: allowances['free'] ?? DEFAULT_TIER_ALLOWANCES.free,
          consumed: 0,
          refundedAt: now,
          lastSyncedFromRC: now,
          environment: environment,
          updatedAt: now,
        }, { merge: true });

        tx.set(idempotencyRef, { 
          handledAt: now, 
          appUserId, 
          type, 
          action: 'subscription_refunded',
          environment,
        });

        return { duplicated: false, action: 'subscription_refunded' };
      }
      else if (type.includes('BILLING_ISSUE')) {
        // Payment issue - keep tier but mark status so client can show hold UI
        const currentSub = await tx.get(subscriptionRef);
        const currentData = currentSub.exists ? currentSub.data() : {};
        tx.set(subscriptionRef, {
          ...currentData,
          status: 'on_hold',
          lastSyncedFromRC: now,
          environment: environment,
          updatedAt: now,
        }, { merge: true });

        tx.set(idempotencyRef, {
          handledAt: now,
          appUserId,
          type,
          action: 'billing_issue',
          environment,
        });
        return { duplicated: false, action: 'billing_issue' };
      }
      else if (type.includes('PRODUCT_CHANGE')) {
        // Product changed (upgrade/downgrade). Update tier & allowance; keep consumed.
        const currentSub = await tx.get(subscriptionRef);
        const currentData = currentSub.exists ? currentSub.data() : {};
        const newTier = getTierFromProductId(productId, productTiers);
        const newAllowance = allowances[newTier] ?? allowances['free'] ?? DEFAULT_TIER_ALLOWANCES.free;
        tx.set(subscriptionRef, {
          ...currentData,
          tier: newTier,
          productId: productId,
          monthlyAllowance: newAllowance,
          lastSyncedFromRC: now,
          environment: environment,
          updatedAt: now,
        }, { merge: true });

        tx.set(idempotencyRef, {
          handledAt: now,
          appUserId,
          type,
          action: 'product_changed',
          environment,
        });
        return { duplicated: false, action: 'product_changed' };
      }
      // Handle consumable (non-subscription) purchases → grant credits
      else if (
        type.includes('NON_RENEWING_PURCHASE') ||
        type.includes('NON_SUBSCRIPTION') ||
        // Fallback: treat unknown purchase types with configured mapping as consumable
        true
      ) {
        // Load consumables config (product → credit units)
        const { productCredits } = await loadConsumablesConfig(db);
        const unitsToGrant = Number(productCredits[productId] ?? 0);
        if (!unitsToGrant) {
          // If not mapped, just log the event without granting
          tx.set(idempotencyRef, {
            handledAt: now,
            appUserId,
            type,
            action: 'consumable_unmapped',
            productId,
            environment,
          });
          return { duplicated: false, action: 'consumable_unmapped' };
        }

        const balanceRef = db.collection('users').doc(appUserId).collection('credits').doc('balance');
        const balSnap = await tx.get(balanceRef);
        const balData = balSnap.exists ? balSnap.data() as any : { balance: 0 };
        const current = Number(balData.balance ?? 0);
        const newBalance = current + unitsToGrant;

        tx.set(balanceRef, {
          balance: newBalance,
          updatedAt: now,
          plan: balData.plan ?? { tier: 'free', allowance: 0 },
          nextReset: balData.nextReset ?? null,
          lastGrant: {
            productId,
            units: unitsToGrant,
          },
        }, { merge: true });

        tx.set(idempotencyRef, {
          handledAt: now,
          appUserId,
          type,
          action: 'credits_granted',
          productId,
          units: unitsToGrant,
          environment,
        });

        return { duplicated: false, action: 'credits_granted', units: unitsToGrant };
      }
      else {
        // Unknown event - just log it
        tx.set(idempotencyRef, { 
          handledAt: now, 
          appUserId, 
          type, 
          action: 'logged_only',
          environment,
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
