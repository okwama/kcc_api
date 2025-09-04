const axios = require('axios');

// Test configuration
const BASE_URL = 'http://localhost:3000';

// Test user credentials (you may need to adjust these)
const testUser = {
  phoneNumber: '0706166875', // Adjust to a valid user in your database
  password: 'password'       // Adjust to the correct password
};

// Test data for non-supplies report
const testNonSuppliesReport = {
  type: 'NON_SUPPLIES',
  journeyPlanId: 1,
  clientId: 1,
  userId: 94,
  details: {
    productName: 'Test Product',
    comment: 'Product not available in store',
    productId: 1
  }
};

async function testLoginAndNonSuppliesReport() {
  try {
    console.log('🔐 Step 1: Testing Login...');
    console.log('📤 Login data:', JSON.stringify(testUser, null, 2));

    // Step 1: Login to get JWT token
    const loginResponse = await axios.post(`${BASE_URL}/auth/login`, testUser);
    
    if (loginResponse.data.access_token) {
      const token = loginResponse.data.access_token;
      console.log('✅ Login successful!');
      console.log('🎫 JWT Token received');
      console.log('👤 User ID:', loginResponse.data.user?.id);
      
      // Step 2: Test Non-Supplies Report with the token
      console.log('\n🧪 Step 2: Testing Non-Supplies Report Submission...');
      console.log('📤 Report data:', JSON.stringify(testNonSuppliesReport, null, 2));

      const reportResponse = await axios.post(`${BASE_URL}/reports`, testNonSuppliesReport, {
        headers: {
          'Authorization': `Bearer ${token}`,
          'Content-Type': 'application/json'
        }
      });

      console.log('✅ Report Response received:');
      console.log('Status:', reportResponse.status);
      console.log('Data:', JSON.stringify(reportResponse.data, null, 2));

      if (reportResponse.data.success) {
        console.log('🎉 Non-supplies report submitted successfully!');
        console.log('📋 Report ID:', reportResponse.data.report.id);
        console.log('📅 Created at:', reportResponse.data.report.createdAt);
        console.log('📝 Report type:', reportResponse.data.report.type);
      } else {
        console.log('❌ Report submission failed:', reportResponse.data.error);
      }

    } else {
      console.log('❌ Login failed - no access token received');
      console.log('Response:', loginResponse.data);
    }

  } catch (error) {
    console.error('❌ Test failed:');
    if (error.response) {
      console.error('Status:', error.response.status);
      console.error('Data:', error.response.data);
    } else {
      console.error('Error:', error.message);
    }
  }
}

// Run the test
testLoginAndNonSuppliesReport();
