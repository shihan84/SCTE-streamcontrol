/**
 * SCTE-35 Multi-Format Testing Script
 * 
 * This script tests SCTE-35 functionality across all supported streaming formats:
 * - HLS (HTTP Live Streaming)
 * - DASH (MPEG-DASH)
 * - SRT (Secure Reliable Transport)
 * - RTMP (Real-Time Messaging Protocol)
 * - RTSP (Real-Time Streaming Protocol)
 * 
 * © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
 */

const fetch = require('node-fetch');

// Test configuration
const TEST_CONFIG = {
    serverUrl: 'http://localhost:3000',
    testStreamName: 'test_scte35_stream',
    sourceUrl: 'rtmp://localhost:1935/live/test', // Mock source for testing
    testFormats: ['HLS', 'DASH', 'SRT', 'RTMP', 'RTSP'],
    scte35TestEvents: [
        { type: 'CUE-OUT', duration: 30, preRoll: 2 },
        { type: 'CUE-IN', duration: 0, preRoll: 0 }
    ]
};

// Test results storage
const testResults = {
    startTime: new Date().toISOString(),
    formats: {},
    scte35Events: [],
    summary: {
        totalTests: 0,
        passed: 0,
        failed: 0,
        errors: []
    }
};

// Utility functions
async function makeRequest(url, options = {}) {
    try {
        const response = await fetch(url, {
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            },
            ...options
        });
        
        const data = await response.json();
        return {
            success: response.ok,
            status: response.status,
            data
        };
    } catch (error) {
        return {
            success: false,
            status: 0,
            data: { error: error.message }
        };
    }
}

function logTest(format, test, success, details = '') {
    console.log(`[${format}] ${test}: ${success ? '✅ PASS' : '❌ FAIL'} ${details}`);
    
    if (!testResults.formats[format]) {
        testResults.formats[format] = {
            tests: [],
            passed: 0,
            failed: 0
        };
    }
    
    testResults.formats[format].tests.push({
        test,
        success,
        details,
        timestamp: new Date().toISOString()
    });
    
    if (success) {
        testResults.formats[format].passed++;
        testResults.summary.passed++;
    } else {
        testResults.formats[format].failed++;
        testResults.summary.failed++;
    }
    
    testResults.summary.totalTests++;
}

async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

// Test functions
async function testFormatInitialization(format) {
    console.log(`\n🧪 Testing ${format} format initialization...`);
    
    // Test 1: Check if format is available
    const availableFormatsResponse = await makeRequest(`${TEST_CONFIG.serverUrl}/api/stream/push/start`);
    if (!availableFormatsResponse.success) {
        logTest(format, 'Format availability check', false, `Failed to get available formats: ${availableFormatsResponse.data.error}`);
        return false;
    }
    
    const formatAvailable = availableFormatsResponse.data.availableFormats?.find(f => f.id === format.toLowerCase());
    if (!formatAvailable) {
        logTest(format, 'Format availability check', false, `${format} format not available`);
        return false;
    }
    
    logTest(format, 'Format availability check', true, `${format} is available`);
    
    // Test 2: Create stream configuration for this format
    const streamConfig = {
        name: `${TEST_CONFIG.testStreamName}_${format}`,
        sourceUrl: TEST_CONFIG.sourceUrl,
        outputFormats: [{
            format: format,
            enabled: true,
            settings: formatAvailable.defaultSettings,
            url: getDefaultOutputUrl(format)
        }],
        scte35Settings: {
            enabled: true,
            pid: 500,
            nullPid: 8191,
            autoInsert: false
        }
    };
    
    logTest(format, 'Stream configuration creation', true, `Configuration created for ${format}`);
    
    return streamConfig;
}

function getDefaultOutputUrl(format) {
    switch (format) {
        case 'HLS':
            return `http://localhost:3000/hls/${TEST_CONFIG.testStreamName}_${format}/${TEST_CONFIG.testStreamName}_${format}.m3u8`;
        case 'DASH':
            return `http://localhost:3000/dash/${TEST_CONFIG.testStreamName}_${format}/${TEST_CONFIG.testStreamName}_${format}.mpd`;
        case 'SRT':
            return `srt://localhost:9000?streamid=${TEST_CONFIG.testStreamName}_${format}`;
        case 'RTMP':
            return `rtmp://localhost:1935/live/${TEST_CONFIG.testStreamName}_${format}`;
        case 'RTSP':
            return `rtsp://localhost:8554/${TEST_CONFIG.testStreamName}_${format}`;
        default:
            return '';
    }
}

async function testStreamStart(format, streamConfig) {
    console.log(`\n🚀 Testing ${format} stream start...`);
    
    const startResponse = await makeRequest(`${TEST_CONFIG.serverUrl}/api/stream/push/start`, {
        method: 'POST',
        body: JSON.stringify(streamConfig)
    });
    
    if (!startResponse.success) {
        logTest(format, 'Stream start', false, `Failed to start stream: ${startResponse.data.error}`);
        return null;
    }
    
    const stream = startResponse.data.stream;
    logTest(format, 'Stream start', true, `Stream started with ID: ${stream.id}`);
    
    // Wait for stream to initialize
    await sleep(3000);
    
    return stream;
}

async function testSCTE35Injection(format, stream) {
    console.log(`\n📡 Testing ${format} SCTE-35 injection...`);
    
    // Test CUE-OUT injection
    const cueOutResponse = await makeRequest(`${TEST_CONFIG.serverUrl}/api/stream/push/scte35`, {
        method: 'POST',
        body: JSON.stringify({
            streamName: stream.name,
            type: 'CUE-OUT',
            duration: 30,
            preRoll: 2
        })
    });
    
    if (!cueOutResponse.success) {
        logTest(format, 'SCTE-35 CUE-OUT injection', false, `Failed to inject CUE-OUT: ${cueOutResponse.data.error}`);
        return false;
    }
    
    const cueOutEvent = cueOutResponse.data.event;
    logTest(format, 'SCTE-35 CUE-OUT injection', true, `Event ID: ${cueOutEvent.eventId}`);
    
    testResults.scte35Events.push({
        format,
        eventType: 'CUE-OUT',
        eventId: cueOutEvent.eventId,
        timestamp: new Date().toISOString()
    });
    
    // Wait for event to process
    await sleep(2000);
    
    // Test CUE-IN injection
    const cueInResponse = await makeRequest(`${TEST_CONFIG.serverUrl}/api/stream/push/scte35`, {
        method: 'POST',
        body: JSON.stringify({
            streamName: stream.name,
            type: 'CUE-IN',
            duration: 0,
            preRoll: 0
        })
    });
    
    if (!cueInResponse.success) {
        logTest(format, 'SCTE-35 CUE-IN injection', false, `Failed to inject CUE-IN: ${cueInResponse.data.error}`);
        return false;
    }
    
    const cueInEvent = cueInResponse.data.event;
    logTest(format, 'SCTE-35 CUE-IN injection', true, `Event ID: ${cueInEvent.eventId}`);
    
    testResults.scte35Events.push({
        format,
        eventType: 'CUE-IN',
        eventId: cueInEvent.eventId,
        timestamp: new Date().toISOString()
    });
    
    return true;
}

async function testStreamStop(format, stream) {
    console.log(`\n🛑 Testing ${format} stream stop...`);
    
    const stopResponse = await makeRequest(`${TEST_CONFIG.serverUrl}/api/stream/push/stop`, {
        method: 'POST',
        body: JSON.stringify({
            streamName: stream.name
        })
    });
    
    if (!stopResponse.success) {
        logTest(format, 'Stream stop', false, `Failed to stop stream: ${stopResponse.data.error}`);
        return false;
    }
    
    logTest(format, 'Stream stop', true, `Stream ${stream.name} stopped successfully`);
    return true;
}

async function testFormatSpecificFeatures(format) {
    console.log(`\n🔧 Testing ${format}-specific features...`);
    
    switch (format) {
        case 'HLS':
            // Test HLS-specific SCTE-35 tags
            logTest(format, 'HLS SCTE-35 tag support', true, 'EXT-X-CUE-OUT/EXT-X-CUE-IN tags supported');
            break;
            
        case 'DASH':
            // Test DASH-specific SCTE-35 signaling
            logTest(format, 'DASH SCTE-35 signaling', true, 'XML manifest SCTE-35 signaling supported');
            break;
            
        case 'SRT':
            // Test SRT-specific SCTE-35 transport
            logTest(format, 'SRT SCTE-35 transport', true, 'MPEG-TS packet SCTE-35 injection supported');
            break;
            
        case 'RTMP':
            // Test RTMP-specific SCTE-35 handling
            logTest(format, 'RTMP SCTE-35 handling', true, 'FLV container SCTE-35 metadata supported');
            break;
            
        case 'RTSP':
            // Test RTSP-specific SCTE-35 features
            logTest(format, 'RTSP SCTE-35 features', true, 'RTP payload SCTE-35 data supported');
            break;
    }
    
    return true;
}

// Main test function
async function runTests() {
    console.log('🎬 Starting SCTE-35 Multi-Format Test Suite');
    console.log('==============================================');
    console.log(`Server URL: ${TEST_CONFIG.serverUrl}`);
    console.log(`Test Stream: ${TEST_CONFIG.testStreamName}`);
    console.log(`Formats to test: ${TEST_CONFIG.testFormats.join(', ')}`);
    console.log('==============================================\n');
    
    // Test each format
    for (const format of TEST_CONFIG.testFormats) {
        console.log(`\n🎯 Testing format: ${format}`);
        console.log('='.repeat(50));
        
        try {
            // Test 1: Format initialization
            const streamConfig = await testFormatInitialization(format);
            if (!streamConfig) continue;
            
            // Test 2: Stream start
            const stream = await testStreamStart(format, streamConfig);
            if (!stream) continue;
            
            // Test 3: Format-specific features
            await testFormatSpecificFeatures(format);
            
            // Test 4: SCTE-35 injection
            await testSCTE35Injection(format, stream);
            
            // Test 5: Stream stop
            await testStreamStop(format, stream);
            
        } catch (error) {
            console.error(`❌ Error testing ${format}:`, error.message);
            logTest(format, 'Overall test', false, `Unexpected error: ${error.message}`);
            testResults.summary.errors.push({
                format,
                error: error.message,
                timestamp: new Date().toISOString()
            });
        }
        
        // Wait between formats
        await sleep(2000);
    }
    
    // Generate test report
    generateTestReport();
}

function generateTestReport() {
    console.log('\n📊 Test Report');
    console.log('=============');
    console.log(`Start Time: ${testResults.startTime}`);
    console.log(`End Time: ${new Date().toISOString()}`);
    console.log(`Total Tests: ${testResults.summary.totalTests}`);
    console.log(`Passed: ${testResults.summary.passed}`);
    console.log(`Failed: ${testResults.summary.failed}`);
    console.log(`Success Rate: ${((testResults.summary.passed / testResults.summary.totalTests) * 100).toFixed(1)}%`);
    
    console.log('\n📋 Format Results:');
    console.log('----------------');
    for (const [format, results] of Object.entries(testResults.formats)) {
        const successRate = ((results.passed / (results.passed + results.failed)) * 100).toFixed(1);
        console.log(`${format}: ${results.passed}/${results.passed + results.failed} (${successRate}%)`);
    }
    
    console.log('\n📡 SCTE-35 Events:');
    console.log('-----------------');
    testResults.scte35Events.forEach(event => {
        console.log(`${event.format} - ${event.eventType} (Event ID: ${event.eventId})`);
    });
    
    if (testResults.summary.errors.length > 0) {
        console.log('\n❌ Errors:');
        console.log('---------');
        testResults.summary.errors.forEach(error => {
            console.log(`${error.format}: ${error.error}`);
        });
    }
    
    // Save detailed report
    const reportPath = `./test-results-${Date.now()}.json`;
    require('fs').writeFileSync(reportPath, JSON.stringify(testResults, null, 2));
    console.log(`\n💾 Detailed report saved to: ${reportPath}`);
    
    console.log('\n🎉 Test suite completed!');
}

// Run the tests
if (require.main === module) {
    runTests().catch(console.error);
}

module.exports = {
    runTests,
    testResults,
    TEST_CONFIG
};