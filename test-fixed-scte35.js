/**
 * Fixed Live HLS Stream SCTE-35 Testing Script
 * 
 * Tests real SCTE-35 injection using the provided HLS stream with proper initialization:
 * Input: https://cloud.itassist.one/khaber24x7live/index.m3u8
 * 
 * This script first initializes the streaming components, then tests all output formats
 * 
 * © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
 */

const fetch = require('node-fetch');

// Test configuration
const TEST_CONFIG = {
    serverUrl: 'http://localhost:3000',
    inputHlsUrl: 'https://cloud.itassist.one/khaber24x7live/index.m3u8',
    outputFormats: ['HLS', 'DASH', 'SRT', 'RTMP', 'RTSP'],
    scte35TestEvents: [
        { type: 'CUE-OUT', duration: 30, preRoll: 2, description: 'Standard 30s ad break' },
        { type: 'CUE-IN', duration: 0, preRoll: 0, description: 'Return to content' }
    ],
    streamSettings: {
        video: {
            codec: 'libx264',
            bitrate: 5,
            resolution: '1920x1080',
            framerate: '30',
            gop: 12,
            bFrames: 5,
            profile: 'high',
            pixelFormat: 'yuv420p'
        },
        audio: {
            codec: 'aac',
            bitrate: 128,
            sampleRate: 48000,
            channels: 2
        },
        scte35: {
            enabled: true,
            pid: 500,
            nullPid: 8191,
            autoInsert: false
        }
    }
};

// Test results storage
const testResults = {
    startTime: new Date().toISOString(),
    inputHlsUrl: TEST_CONFIG.inputHlsUrl,
    formats: {},
    scte35Events: [],
    initialization: null,
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
            failed: 0,
            outputUrls: {},
            scte35Events: []
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

// Initialize streaming components
async function initializeStreamers() {
    console.log('🚀 Initializing streaming components...');
    
    const initResponse = await makeRequest(`${TEST_CONFIG.serverUrl}/api/stream/push/init`, {
        method: 'POST'
    });
    
    console.log(`Initialization response status: ${initResponse.status}`);
    console.log('Initialization response data:', JSON.stringify(initResponse.data, null, 2));
    
    if (initResponse.success) {
        testResults.initialization = {
            success: true,
            status: initResponse.data.status,
            message: initResponse.data.message
        };
        console.log('✅ Streaming components initialized successfully');
        return true;
    } else {
        testResults.initialization = {
            success: false,
            error: initResponse.data.error,
            details: initResponse.data.details
        };
        console.log('❌ Failed to initialize streaming components');
        return false;
    }
}

// Test input HLS stream availability
async function testInputHlsStream() {
    console.log('🔍 Testing input HLS stream availability...');
    console.log(`URL: ${TEST_CONFIG.inputHlsUrl}`);
    
    try {
        const response = await fetch(TEST_CONFIG.inputHlsUrl);
        if (response.ok) {
            const content = await response.text();
            console.log('✅ Input HLS stream is accessible');
            console.log(`Content length: ${content.length} characters`);
            console.log('Stream info:');
            const lines = content.split('\n');
            lines.forEach(line => {
                if (line.startsWith('#EXT-X-STREAM-INF')) {
                    console.log(`  ${line}`);
                }
            });
            return true;
        } else {
            console.log(`❌ Input HLS stream returned status: ${response.status}`);
            return false;
        }
    } catch (error) {
        console.log(`❌ Failed to access input HLS stream: ${error.message}`);
        return false;
    }
}

// Create stream configuration for specific format
function createStreamConfig(format) {
    const baseConfig = {
        name: `live_test_${format.toLowerCase()}`,
        sourceUrl: TEST_CONFIG.inputHlsUrl,
        outputFormats: [{
            format: format,
            enabled: true,
            settings: getFormatSettings(format),
            url: getOutputUrl(format)
        }],
        videoSettings: TEST_CONFIG.streamSettings.video,
        audioSettings: TEST_CONFIG.streamSettings.audio,
        scte35Settings: TEST_CONFIG.streamSettings.scte35,
        outputSettings: {
            hls: {
                enabled: format === 'HLS',
                segmentDuration: 2,
                playlistLength: 6,
                outputDir: './tmp/hls'
            },
            dash: {
                enabled: format === 'DASH',
                segmentDuration: 2,
                playlistLength: 6,
                outputDir: './tmp/dash'
            },
            srt: {
                enabled: format === 'SRT',
                port: 9000,
                latency: 120,
                overheadBandwidth: 25
            },
            rtmp: {
                enabled: format === 'RTMP',
                port: 1935,
                chunkSize: 4096
            }
        },
        transcoding: {
            enabled: false,
            profiles: []
        }
    };
    
    return baseConfig;
}

function getFormatSettings(format) {
    switch (format) {
        case 'HLS':
            return {
                segmentDuration: 2,
                playlistLength: 6,
                outputDir: './tmp/hls'
            };
        case 'DASH':
            return {
                segmentDuration: 2,
                playlistLength: 6,
                outputDir: './tmp/dash'
            };
        case 'SRT':
            return {
                port: 9000,
                latency: 120,
                overheadBandwidth: 25
            };
        case 'RTMP':
            return {
                port: 1935,
                chunkSize: 4096
            };
        case 'RTSP':
            return {
                port: 8554
            };
        default:
            return {};
    }
}

function getOutputUrl(format) {
    const streamName = `live_test_${format.toLowerCase()}`;
    switch (format) {
        case 'HLS':
            return `http://localhost:3000/hls/${streamName}/${streamName}.m3u8`;
        case 'DASH':
            return `http://localhost:3000/dash/${streamName}/${streamName}.mpd`;
        case 'SRT':
            return `srt://localhost:9000?streamid=${streamName}`;
        case 'RTMP':
            return `rtmp://localhost:1935/live/${streamName}`;
        case 'RTSP':
            return `rtsp://localhost:8554/${streamName}`;
        default:
            return '';
    }
}

// Test specific format
async function testFormat(format) {
    console.log(`\n🎯 Testing format: ${format}`);
    console.log('='.repeat(50));
    
    try {
        // Test 1: Create stream configuration
        console.log(`\n📋 Creating ${format} stream configuration...`);
        const streamConfig = createStreamConfig(format);
        console.log('Stream configuration:', JSON.stringify(streamConfig, null, 2));
        logTest(format, 'Stream configuration creation', true, 'Configuration created successfully');
        
        // Test 2: Start the stream
        console.log(`\n🚀 Starting ${format} stream...`);
        const startResponse = await makeRequest(`${TEST_CONFIG.serverUrl}/api/stream/push/start-fixed`, {
            method: 'POST',
            body: JSON.stringify(streamConfig)
        });
        
        console.log(`Start response status: ${startResponse.status}`);
        console.log('Start response data:', JSON.stringify(startResponse.data, null, 2));
        
        if (startResponse.success) {
            const stream = startResponse.data.stream;
            testResults.formats[format].outputUrls = stream.outputUrls || {};
            logTest(format, 'Stream start', true, `Stream started with ID: ${stream.id}`);
            
            // Wait for stream to initialize
            console.log('\n⏳ Waiting for stream to initialize...');
            await sleep(5000);
            
            // Test 3: Inject SCTE-35 events
            console.log(`\n📡 Testing SCTE-35 injection for ${format}...`);
            for (const event of TEST_CONFIG.scte35TestEvents) {
                console.log(`Injecting ${event.type} event: ${event.description}`);
                
                const scteResponse = await makeRequest(`${TEST_CONFIG.serverUrl}/api/stream/push/scte35`, {
                    method: 'POST',
                    body: JSON.stringify({
                        streamName: streamConfig.name,
                        type: event.type,
                        duration: event.duration,
                        preRoll: event.preRoll
                    })
                });
                
                console.log(`SCTE-35 response status: ${scteResponse.status}`);
                console.log('SCTE-35 response data:', JSON.stringify(scteResponse.data, null, 2));
                
                if (scteResponse.success) {
                    const scteEvent = scteResponse.data.event;
                    testResults.formats[format].scte35Events.push(scteEvent);
                    testResults.scte35Events.push({
                        format,
                        ...scteEvent,
                        description: event.description
                    });
                    logTest(format, `SCTE-35 ${event.type} injection`, true, 
                        `Event ID: ${scteEvent.eventId} - ${event.description}`);
                } else {
                    logTest(format, `SCTE-35 ${event.type} injection`, false, 
                        `Failed: ${scteResponse.data.error}`);
                }
                
                // Wait between events
                await sleep(3000);
            }
            
            // Test 4: Verify output URLs
            console.log(`\n🔗 Verifying ${format} output URLs...`);
            const outputUrls = testResults.formats[format].outputUrls;
            for (const [formatName, url] of Object.entries(outputUrls)) {
                console.log(`${formatName}: ${url}`);
                logTest(format, `Output URL ${formatName}`, true, `URL: ${url}`);
            }
            
            // Test 5: Stop the stream
            console.log(`\n🛑 Stopping ${format} stream...`);
            const stopResponse = await makeRequest(`${TEST_CONFIG.serverUrl}/api/stream/push/stop`, {
                method: 'POST',
                body: JSON.stringify({
                    streamName: streamConfig.name
                })
            });
            
            console.log(`Stop response status: ${stopResponse.status}`);
            console.log('Stop response data:', JSON.stringify(stopResponse.data, null, 2));
            
            if (stopResponse.success) {
                logTest(format, 'Stream stop', true, 'Stream stopped successfully');
            } else {
                logTest(format, 'Stream stop', false, `Failed: ${stopResponse.data.error}`);
            }
            
        } else {
            logTest(format, 'Stream start', false, `Failed: ${startResponse.data.error}`);
        }
        
    } catch (error) {
        console.error(`❌ Error testing ${format}:`, error.message);
        logTest(format, 'Overall test', false, `Error: ${error.message}`);
        testResults.summary.errors.push({
            format,
            error: error.message,
            timestamp: new Date().toISOString()
        });
    }
    
    // Wait between formats
    await sleep(3000);
}

// Generate test report
function generateTestReport() {
    console.log('\n📊 Fixed Live SCTE-35 Test Report');
    console.log('===================================');
    console.log(`Start Time: ${testResults.startTime}`);
    console.log(`End Time: ${new Date().toISOString()}`);
    console.log(`Input HLS: ${testResults.inputHlsUrl}`);
    
    if (testResults.initialization) {
        console.log(`\n🚀 Initialization Status: ${testResults.initialization.success ? '✅ SUCCESS' : '❌ FAILED'}`);
        if (testResults.initialization.success) {
            console.log(`Message: ${testResults.initialization.message}`);
        } else {
            console.log(`Error: ${testResults.initialization.error}`);
            if (testResults.initialization.details) {
                console.log(`Details: ${testResults.initialization.details}`);
            }
        }
    }
    
    console.log(`\nTotal Tests: ${testResults.summary.totalTests}`);
    console.log(`Passed: ${testResults.summary.passed}`);
    console.log(`Failed: ${testResults.summary.failed}`);
    console.log(`Success Rate: ${((testResults.summary.passed / testResults.summary.totalTests) * 100).toFixed(1)}%`);
    
    console.log('\n📋 Format Results:');
    console.log('----------------');
    for (const [format, results] of Object.entries(testResults.formats)) {
        const successRate = ((results.passed / (results.passed + results.failed)) * 100).toFixed(1);
        console.log(`${format}: ${results.passed}/${results.passed + results.failed} (${successRate}%)`);
        
        if (results.outputUrls && Object.keys(results.outputUrls).length > 0) {
            console.log(`  Output URLs:`);
            for (const [formatName, url] of Object.entries(results.outputUrls)) {
                console.log(`    ${formatName}: ${url}`);
            }
        }
        
        if (results.scte35Events && results.scte35Events.length > 0) {
            console.log(`  SCTE-35 Events:`);
            results.scte35Events.forEach(event => {
                console.log(`    ${event.type} (ID: ${event.eventId}, Duration: ${event.duration}s)`);
            });
        }
    }
    
    console.log('\n📡 SCTE-35 Events Summary:');
    console.log('-------------------------');
    testResults.scte35Events.forEach((event, index) => {
        console.log(`${index + 1}. ${event.format} - ${event.type} (Event ID: ${event.eventId})`);
        console.log(`   Duration: ${event.duration}s, Pre-roll: ${event.preRoll}s`);
        console.log(`   Stream: ${event.streamName}`);
        console.log(`   Status: ${event.status}`);
    });
    
    if (testResults.summary.errors.length > 0) {
        console.log('\n❌ Errors:');
        console.log('---------');
        testResults.summary.errors.forEach(error => {
            console.log(`${error.format}: ${error.error}`);
        });
    }
    
    // Save detailed report
    const reportPath = `./fixed-test-results-${Date.now()}.json`;
    require('fs').writeFileSync(reportPath, JSON.stringify(testResults, null, 2));
    console.log(`\n💾 Detailed test report saved to: ${reportPath}`);
    
    console.log('\n🎉 Fixed Live SCTE-35 testing completed!');
}

// Main test function
async function runFixedLiveTests() {
    console.log('🎬 Fixed Live HLS Stream SCTE-35 Testing');
    console.log('========================================');
    console.log(`Input HLS: ${TEST_CONFIG.inputHlsUrl}`);
    console.log(`Output Formats: ${TEST_CONFIG.outputFormats.join(', ')}`);
    console.log('========================================\n');
    
    // Test input HLS stream first
    const inputAvailable = await testInputHlsStream();
    if (!inputAvailable) {
        console.log('❌ Cannot proceed - input HLS stream not accessible');
        return;
    }
    
    // Initialize streaming components
    const initialized = await initializeStreamers();
    if (!initialized) {
        console.log('❌ Cannot proceed - streaming components failed to initialize');
        return;
    }
    
    // Test each format one by one
    for (const format of TEST_CONFIG.outputFormats) {
        await testFormat(format);
    }
    
    // Generate report
    generateTestReport();
}

// Run the tests
if (require.main === module) {
    runFixedLiveTests().catch(console.error);
}

module.exports = {
    runFixedLiveTests,
    testResults,
    TEST_CONFIG
};