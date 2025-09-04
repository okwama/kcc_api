const http = require('http');

// Test configuration
const BASE_URL = 'localhost';
const PORT = 3000;

// Test user credentials (adjust these to match a valid user in your database)
const testUser = {
  phoneNumber: '0706166875', // Adjust to a valid user
  password: 'password'       // Adjust to correct password
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

async function testWithLogin() {
  try {
    console.log('🔐 Step 1: Testing Login...');
    console.log('📤 Login data:', JSON.stringify(testUser, null, 2));

    // Step 1: Login to get JWT token
    const loginResponse = await makeRequest('/api/auth/login', 'POST', testUser);
    
    console.log('Login Response Status:', loginResponse.status);
    console.log('Login Response Data:', loginResponse.data);

    if (loginResponse.status === 200 && loginResponse.data.accessToken) {
      const token = loginResponse.data.accessToken;
      console.log('✅ Login successful!');
      console.log('🎫 JWT Token received');
      console.log('👤 User ID:', loginResponse.data.user?.id);
      
      // Step 2: Test Non-Supplies Report with the token
      console.log('\n🧪 Step 2: Testing Non-Supplies Report Submission...');
      console.log('📤 Report data:', JSON.stringify(testNonSuppliesReport, null, 2));

      const reportResponse = await makeRequest('/api/reports', 'POST', testNonSuppliesReport, token);

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
      console.log('❌ Login failed');
      console.log('Status:', loginResponse.status);
      console.log('Response:', loginResponse.data);
      
      if (loginResponse.status === 401) {
        console.log('💡 Tip: Check if the user credentials are correct in your database');
      }
    }

  } catch (error) {
    console.error('❌ Test failed:', error.message);
  }
}

// Run the test
testWithLogin();
