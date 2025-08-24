const fetch = require('node-fetch');

async function testInitialization() {
    console.log('🧪 Testing MultiFormatStreamer Initialization');
    console.log('===========================================');
    
    try {
        // Test starting a stream with full configuration
        const fullConfig = {
            name: 'init_test_stream',
            sourceUrl: 'rtmp://localhost:1935/live/test',
            outputFormats: [{
                format: 'HLS',
                enabled: true,
                settings: {
                    segmentDuration: 2,
                    playlistLength: 6,
                    outputDir: './tmp/hls'
                },
                url: 'http://localhost:3000/hls/init_test_stream/init_test_stream.m3u8'
            }],
            videoSettings: {
                codec: 'libx264',
                bitrate: 5,
                resolution: '1920x1080',
                framerate: '30',
                gop: 12,
                bFrames: 5,
                profile: 'high',
                pixelFormat: 'yuv420p'
            },
            audioSettings: {
                codec: 'aac',
                bitrate: 128,
                sampleRate: 48000,
                channels: 2
            },
            scte35Settings: {
                enabled: true,
                pid: 500,
                nullPid: 8191,
                autoInsert: false
            },
            outputSettings: {
                hls: {
                    enabled: true,
                    segmentDuration: 2,
                    playlistLength: 6,
                    outputDir: './tmp/hls'
                },
                dash: {
                    enabled: false,
                    segmentDuration: 2,
                    playlistLength: 6,
                    outputDir: './tmp/dash'
                },
                srt: {
                    enabled: false,
                    port: 9000,
                    latency: 120,
                    overheadBandwidth: 25
                },
                rtmp: {
                    enabled: false,
                    port: 1935,
                    chunkSize: 4096
                }
            },
            transcoding: {
                enabled: false,
                profiles: []
            }
        };
        
        console.log('📤 Sending full configuration...');
        const response = await fetch('http://localhost:3000/api/stream/push/start', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(fullConfig)
        });
        
        console.log(`📊 Response status: ${response.status}`);
        const data = await response.json();
        console.log('📋 Response data:', JSON.stringify(data, null, 2));
        
        if (response.ok) {
            console.log('✅ Stream started successfully!');
            
            // Test SCTE-35 injection
            console.log('\n📡 Testing SCTE-35 injection...');
            const scteResponse = await fetch('http://localhost:3000/api/stream/push/scte35', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    streamName: 'init_test_stream',
                    type: 'CUE-OUT',
                    duration: 30,
                    preRoll: 2
                })
            });
            
            console.log(`📊 SCTE-35 Response status: ${scteResponse.status}`);
            const scteData = await scteResponse.json();
            console.log('📋 SCTE-35 Response data:', JSON.stringify(scteData, null, 2));
            
            if (scteResponse.ok) {
                console.log('✅ SCTE-35 injection successful!');
                
                // Test CUE-IN
                console.log('\n📡 Testing CUE-IN injection...');
                const cueInResponse = await fetch('http://localhost:3000/api/stream/push/scte35', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        streamName: 'init_test_stream',
                        type: 'CUE-IN',
                        duration: 0,
                        preRoll: 0
                    })
                });
                
                console.log(`📊 CUE-IN Response status: ${cueInResponse.status}`);
                const cueInData = await cueInResponse.json();
                console.log('📋 CUE-IN Response data:', JSON.stringify(cueInData, null, 2));
                
                if (cueInResponse.ok) {
                    console.log('✅ CUE-IN injection successful!');
                } else {
                    console.log('❌ CUE-IN injection failed');
                }
            } else {
                console.log('❌ SCTE-35 injection failed');
            }
            
            // Stop the stream
            console.log('\n🛑 Stopping stream...');
            const stopResponse = await fetch('http://localhost:3000/api/stream/push/stop', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    streamName: 'init_test_stream'
                })
            });
            
            console.log(`📊 Stop Response status: ${stopResponse.status}`);
            const stopData = await stopResponse.json();
            console.log('📋 Stop Response data:', JSON.stringify(stopData, null, 2));
            
            if (stopResponse.ok) {
                console.log('✅ Stream stopped successfully!');
            } else {
                console.log('❌ Stream stop failed');
            }
            
        } else {
            console.log('❌ Stream start failed');
            console.log('Error details:', data.details);
        }
        
    } catch (error) {
        console.error('❌ Test failed with error:', error.message);
        console.error('Stack trace:', error.stack);
    }
}

testInitialization();