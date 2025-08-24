const fetch = require('node-fetch');

async function testStreamStart() {
    console.log('🧪 Manual Stream Start Test');
    console.log('==========================');
    
    const streamConfig = {
        name: 'manual_test_stream',
        sourceUrl: 'rtmp://localhost:1935/live/test',
        outputFormats: [{
            format: 'HLS',
            enabled: true,
            settings: {
                segmentDuration: 2,
                playlistLength: 6,
                outputDir: './tmp/hls'
            },
            url: 'http://localhost:3000/hls/manual_test_stream/manual_test_stream.m3u8'
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
    
    try {
        console.log('📤 Sending stream start request...');
        const response = await fetch('http://localhost:3000/api/stream/push/start', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json'
            },
            body: JSON.stringify(streamConfig)
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
                    streamName: 'manual_test_stream',
                    type: 'CUE-OUT',
                    duration: 30,
                    preRoll: 2
                })
            });
            
            console.log(`📊 SCTE-35 Response status: ${scteResponse.status}`);
            const scteData = await scteResponse.json();
            console.log('📋 SCTE-35 Response data:', JSON.stringify(scteData, null, 2));
            
            // Stop the stream
            console.log('\n🛑 Stopping stream...');
            const stopResponse = await fetch('http://localhost:3000/api/stream/push/stop', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    streamName: 'manual_test_stream'
                })
            });
            
            console.log(`📊 Stop Response status: ${stopResponse.status}`);
            const stopData = await stopResponse.json();
            console.log('📋 Stop Response data:', JSON.stringify(stopData, null, 2));
            
        } else {
            console.log('❌ Stream start failed!');
        }
        
    } catch (error) {
        console.error('❌ Error:', error.message);
    }
}

testStreamStart();