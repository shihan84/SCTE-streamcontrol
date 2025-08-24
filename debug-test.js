const fetch = require('node-fetch');

async function debugTest() {
    console.log('🔍 Debug Test - Testing MultiFormatStreamer Initialization');
    console.log('========================================================');
    
    try {
        // Test 1: Check if we can get available formats
        console.log('1. Testing available formats...');
        const formatsResponse = await fetch('http://localhost:3000/api/stream/push/start');
        console.log(`Status: ${formatsResponse.status}`);
        const formatsData = await formatsResponse.json();
        console.log('Formats data:', JSON.stringify(formatsData, null, 2));
        
        if (formatsResponse.ok) {
            console.log('✅ Available formats test passed');
        } else {
            console.log('❌ Available formats test failed');
            return;
        }
        
        // Test 2: Try to start a minimal stream
        console.log('\n2. Testing minimal stream start...');
        const minimalConfig = {
            name: 'debug_test_stream',
            sourceUrl: 'rtmp://localhost:1935/live/test',
            outputFormats: [{
                format: 'HLS',
                enabled: true,
                settings: {
                    segmentDuration: 2,
                    playlistLength: 6,
                    outputDir: './tmp/hls'
                },
                url: 'http://localhost:3000/hls/debug_test_stream/debug_test_stream.m3u8'
            }],
            scte35Settings: {
                enabled: true,
                pid: 500,
                nullPid: 8191,
                autoInsert: false
            }
        };
        
        console.log('Sending minimal config:', JSON.stringify(minimalConfig, null, 2));
        
        const startResponse = await fetch('http://localhost:3000/api/stream/push/start', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(minimalConfig)
        });
        
        console.log(`Status: ${startResponse.status}`);
        const startData = await startResponse.json();
        console.log('Start response:', JSON.stringify(startData, null, 2));
        
        if (startResponse.ok) {
            console.log('✅ Stream start test passed');
            
            // Test 3: Try SCTE-35 injection
            console.log('\n3. Testing SCTE-35 injection...');
            const scteResponse = await fetch('http://localhost:3000/api/stream/push/scte35', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    streamName: 'debug_test_stream',
                    type: 'CUE-OUT',
                    duration: 30,
                    preRoll: 2
                })
            });
            
            console.log(`SCTE-35 Status: ${scteResponse.status}`);
            const scteData = await scteResponse.json();
            console.log('SCTE-35 response:', JSON.stringify(scteData, null, 2));
            
            if (scteResponse.ok) {
                console.log('✅ SCTE-35 injection test passed');
            } else {
                console.log('❌ SCTE-35 injection test failed');
            }
            
            // Test 4: Stop the stream
            console.log('\n4. Testing stream stop...');
            const stopResponse = await fetch('http://localhost:3000/api/stream/push/stop', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    streamName: 'debug_test_stream'
                })
            });
            
            console.log(`Stop Status: ${stopResponse.status}`);
            const stopData = await stopResponse.json();
            console.log('Stop response:', JSON.stringify(stopData, null, 2));
            
            if (stopResponse.ok) {
                console.log('✅ Stream stop test passed');
            } else {
                console.log('❌ Stream stop test failed');
            }
            
        } else {
            console.log('❌ Stream start test failed');
            console.log('Error details:', startData.details);
        }
        
    } catch (error) {
        console.error('❌ Debug test failed with error:', error.message);
        console.error('Stack trace:', error.stack);
    }
}

debugTest();