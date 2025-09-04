const http = require('http');

// Test configuration
const BASE_URL = 'localhost';
const PORT = 3000;

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

function makeRequest(path, method, data, token = null) {
  return new Promise((resolve, reject) => {
    const postData = data ? JSON.stringify(data) : '';
    
    const options = {
      hostname: BASE_URL,
      port: PORT,
      path: path,
      method: method,
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      }
    };

    if (token) {
      options.headers['Authorization'] = `Bearer ${token}`;
    }

    const req = http.request(options, (res) => {
      let responseData = '';
      
      res.on('data', (chunk) => {
        responseData += chunk;
      });
      
      res.on('end', () => {
        try {
          const parsedData = JSON.parse(responseData);
          resolve({
            status: res.statusCode,
            data: parsedData
          });
        } catch (e) {
          resolve({
            status: res.statusCode,
            data: responseData
          });
        }
      });
    });

    req.on('error', (error) => {
      reject(error);
    });

    if (postData) {
      req.write(postData);
    }
    
    req.end();
  });
}

async function testNonSuppliesReportAPI() {
  try {
    console.log('🧪 Testing Non-Supplies Report API...');
    console.log('📤 Report data:', JSON.stringify(testNonSuppliesReport, null, 2));

    // Test without authentication first (should fail)
    console.log('\n🔒 Testing without authentication (should fail)...');
    const responseWithoutAuth = await makeRequest('/api/reports', 'POST', testNonSuppliesReport);
    console.log('Status:', responseWithoutAuth.status);
    console.log('Response:', responseWithoutAuth.data);

    // Test with invalid token (should fail)
    console.log('\n🔑 Testing with invalid token (should fail)...');
    const responseWithInvalidToken = await makeRequest('/api/reports', 'POST', testNonSuppliesReport, 'invalid-token');
    console.log('Status:', responseWithInvalidToken.status);
    console.log('Response:', responseWithInvalidToken.data);

    console.log('\n✅ Test completed!');
    console.log('📝 Note: To test with valid authentication, you need to:');
    console.log('   1. Login via POST /api/auth/login');
    console.log('   2. Use the returned JWT token');
    console.log('   3. Test the reports endpoint with the token');

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

// Run the test
testNonSuppliesReportAPI();
