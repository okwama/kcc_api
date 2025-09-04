const axios = require('axios');

// Test configuration
const BASE_URL = 'http://localhost:3000'; // Adjust if your API runs on different port
const TEST_TOKEN = 'your-test-jwt-token-here'; // Replace with actual token

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

async function testNonSuppliesReport() {
  try {
    console.log('🧪 Testing Non-Supplies Report Submission...');
    console.log('📤 Sending data:', JSON.stringify(testNonSuppliesReport, null, 2));

    const response = await axios.post(`${BASE_URL}/reports`, testNonSuppliesReport, {
      headers: {
        'Authorization': `Bearer ${TEST_TOKEN}`,
        'Content-Type': 'application/json'
      }
    });

    console.log('✅ Response received:');
    console.log('Status:', response.status);
    console.log('Data:', JSON.stringify(response.data, null, 2));

    if (response.data.success) {
      console.log('🎉 Non-supplies report submitted successfully!');
      console.log('📋 Report ID:', response.data.report.id);
      console.log('📅 Created at:', response.data.report.createdAt);
    } else {
      console.log('❌ Report submission failed:', response.data.error);
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
testNonSuppliesReport();
