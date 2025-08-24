const fetch = require('node-fetch');

async function testSimpleInit() {
    console.log('🧪 Testing Simple Initialization');
    console.log('=================================');
    
    try {
        // Test 1: Check if we can get available formats
        console.log('1. Testing available formats...');
        const formatsResponse = await fetch('http://localhost:3000/api/stream/push/start');
        console.log(`Status: ${formatsResponse.status}`);
        const formatsData = await formatsResponse.json();
        console.log('Formats available:', formatsData.success ? 'Yes' : 'No');
        
        // Test 2: Try to initialize components
        console.log('\n2. Testing initialization...');
        const initResponse = await fetch('http://localhost:3000/api/stream/push/init', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify({})
        });
        
        console.log(`Init Status: ${initResponse.status}`);
        const initData = await initResponse.json();
        console.log('Init response:', JSON.stringify(initData, null, 2));
        
        if (initResponse.success) {
            console.log('✅ Initialization successful');
            
            // Test 3: Try to start a simple stream
            console.log('\n3. Testing simple stream start...');
            const streamConfig = {
                name: 'simple_test_stream',
                sourceUrl: 'https://cloud.itassist.one/khaber24x7live/index.m3u8',
                outputFormats: [{
                    format: 'HLS',
                    enabled: true,
                    settings: {
                        segmentDuration: 2,
                        playlistLength: 6,
                        outputDir: './tmp/hls'
                    },
                    url: 'http://localhost:3000/hls/simple_test_stream/simple_test_stream.m3u8'
                }],
                scte35Settings: {
                    enabled: true,
                    pid: 500,
                    nullPid: 8191,
                    autoInsert: false
                }
            };
            
            const startResponse = await fetch('http://localhost:3000/api/stream/push/start', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(streamConfig)
            });
            
            console.log(`Start Status: ${startResponse.status}`);
            const startData = await startResponse.json();
            console.log('Start response:', JSON.stringify(startData, null, 2));
            
            if (startResponse.success) {
                console.log('✅ Stream started successfully');
                
                // Test 4: Try SCTE-35 injection
                console.log('\n4. Testing SCTE-35 injection...');
                const scteResponse = await fetch('http://localhost:3000/api/stream/push/scte35', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        streamName: 'simple_test_stream',
                        type: 'CUE-OUT',
                        duration: 30,
                        preRoll: 2
                    })
                });
                
                console.log(`SCTE-35 Status: ${scteResponse.status}`);
                const scteData = await scteResponse.json();
                console.log('SCTE-35 response:', JSON.stringify(scteData, null, 2));
                
                if (scteResponse.success) {
                    console.log('✅ SCTE-35 injection successful');
                } else {
                    console.log('❌ SCTE-35 injection failed');
                }
                
                // Test 5: Stop the stream
                console.log('\n5. Testing stream stop...');
                const stopResponse = await fetch('http://localhost:3000/api/stream/push/stop', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        streamName: 'simple_test_stream'
                    })
                });
                
                console.log(`Stop Status: ${stopResponse.status}`);
                const stopData = await stopResponse.json();
                console.log('Stop response:', JSON.stringify(stopData, null, 2));
                
                if (stopResponse.success) {
                    console.log('✅ Stream stopped successfully');
                } else {
                    console.log('❌ Stream stop failed');
                }
                
            } else {
                console.log('❌ Stream start failed');
            }
            
        } else {
            console.log('❌ Initialization failed');
        }
        
    } catch (error) {
        console.error('❌ Test failed with error:', error.message);
    }
}

testSimpleInit();