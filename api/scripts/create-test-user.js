/* Create a test user for API testing
 * Requires Firebase Admin credentials to be set in environment
 */

import { getAdminAuth } from '../shared/firebase-admin.js';

const TEST_EMAIL = 'test@cognify.com';
const TEST_PASSWORD = 'testpass123';

async function createTestUser() {
  try {
    const auth = getAdminAuth();
    
    // Check if user already exists
    try {
      const existing = await auth.getUserByEmail(TEST_EMAIL);
      console.log(`✓ Test user already exists: ${TEST_EMAIL}`);
      console.log(`  UID: ${existing.uid}`);
      return;
    } catch (e) {
      // User doesn't exist, create it
    }
    
    // Create the user
    const userRecord = await auth.createUser({
      email: TEST_EMAIL,
      password: TEST_PASSWORD,
      emailVerified: true,
      disabled: false,
    });
    
    console.log('✓ Test user created successfully!');
    console.log(`  Email: ${TEST_EMAIL}`);
    console.log(`  Password: ${TEST_PASSWORD}`);
    console.log(`  UID: ${userRecord.uid}`);
    
  } catch (error) {
    console.error('Error creating test user:', error.message);
    process.exit(1);
  }
}

createTestUser();

