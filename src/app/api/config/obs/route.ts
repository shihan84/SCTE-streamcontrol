import { NextRequest, NextResponse } from 'next/server'

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const {
      serviceName,
      videoResolution,
      videoCodec,
      profileLevel,
      gop,
      bFrames,
      videoBitrate,
      chroma,
      aspectRatio,
      audioCodec,
      audioBitrate,
      audioLKFS,
      audioSamplingRate,
      scteDataPID,
      nullPID,
      latency,
      serverUrl
    } = body

    // Validate required parameters
    if (!serviceName || !serverUrl) {
      return NextResponse.json(
        { success: false, error: 'Service name and server URL are required' },
        { status: 400 }
      )
    }

    // Parse server URL to extract base URL and stream key
    let baseUrl = serverUrl
    let streamKey = ''
    
    // Check if the URL already contains the stream key
    if (serverUrl.includes('/')) {
      const urlParts = serverUrl.split('/')
      if (urlParts.length > 1) {
        // Extract the last part as stream key
        streamKey = urlParts[urlParts.length - 1]
        // Keep the base URL without the stream key
        baseUrl = urlParts.slice(0, -1).join('/')
      }
    }
    
    // If no stream key found in URL, use service name as stream key
    if (!streamKey) {
      streamKey = serviceName.toLowerCase().replace(/\s+/g, '_')
    }

    // Parse resolution
    const [width, height] = videoResolution.split('x').map(Number)
    
    // Parse profile level
    const profile = profileLevel.split('@')[0]

    // Generate OBS Studio configuration based on official documentation
    // This follows the actual INI format used by OBS Studio
    const obsBasicConfig = `[General]
Name=${serviceName}

[Output]
Mode=Advanced
RecType=None
RecFilePath=
RecFormat=flv
RecUseRescale=False
RecRescaleRes=${width}x${height}
RecTracks=1
RecEncoder=x264
RecPreset=veryfast
RecRateControl=CRF
RecCRF=23
RecUseCBR=False
RecBitrate=${videoBitrate * 1000}
RecUseBufsize=False
RecBufsize=${videoBitrate * 1000}
RecUseKeyframes=False
RecKeyframeSec=0
RecUseProfile=False
RecProfile=${profile}
RecUseTune=False
RecTune=none
RecUseAdvanced=False

[AdvOut]
RecType=None
RecEncoder=x264
RecFilePath=
RecFormat=flv
RecUseRescale=False
RecRescaleRes=${width}x${height}
RecTracks=1
RecEncoderId=x264
RecPreset=veryfast
RecRateControl=CRF
RecCRF=23
RecUseCBR=False
RecBitrate=${videoBitrate * 1000}
RecUseBufsize=False
RecBufsize=${videoBitrate * 1000}
RecUseKeyframes=False
RecKeyframeSec=0
RecUseProfile=False
RecProfile=${profile}
RecUseTune=False
RecTune=none
RecUseAdvanced=False

[Video]
BaseCX=${width}
BaseCY=${height}
OutputCX=${width}
OutputCY=${height}
FPSType=2
FPSNum=30000
FPSDen=1001
ScaleType=bicubic
ColorFormat=NV12
ColorSpace=709
ColorRange=Limited

[Audio]
SampleRate=${audioSamplingRate * 1000}
Channels=2
Bitrate=${audioBitrate}
Track1Bitrate=${audioBitrate}
Track1Name=Audio
Track1Codec=${audioCodec}
Track1LoudnessTarget=${audioLKFS}

[SimpleOutput]
RecFilePath=
RecFormat=flv
RecEncoder=x264
RecPreset=veryfast
RecRateControl=CRF
RecCRF=23
RecUseCBR=False
RecBitrate=${videoBitrate * 1000}
RecUseBufsize=False
RecBufsize=${videoBitrate * 1000}
RecUseKeyframes=False
RecKeyframeSec=0
RecUseProfile=False
RecProfile=${profile}
RecUseTune=False
RecTune=none
RecUseAdvanced=False

[AdvOutEncoder]
x264_useCBR=1
x264_bitrate=${videoBitrate * 1000}
x264_keyint_sec=${gop}
x264_bframes=${bFrames}
x264_profile=${profile}
x264_tune=none
x264_preset=veryfast
x264opts=scenecut=0:force_key_frames="expr:gte(t,n_forced*${gop})"

[Streaming]
Service=Custom
Server=${serverUrl}
Key=
UseAuth=false
BandwidthTest=false

[Publish]
Service=Custom
Server=${serverUrl}
Key=
UseAuth=false`

    // Note: SCTE-35 is not configured in OBS Studio itself
    // SCTE-35 insertion is handled externally through the media server
    // The SCTE-35 requirements are stored for reference and external configuration

    // Generate OBS Studio JSON configuration for scene collection/profile format
    const obsJsonConfig = {
      name: serviceName,
      type: "rtmp_custom",
      settings: {
        server: serverUrl,
        key: "",
        use_auth: false,
        bandwidth_test: false
      },
      encoder: {
        id: "x264",
        name: "x264",
        settings: {
          rate_control: "CBR",
          bitrate: videoBitrate * 1000,
          keyint_sec: gop,
          bframes: bFrames,
          profile: profile,
          tune: "none",
          preset: "veryfast",
          width: width,
          height: height,
          fps_num: 30000,
          fps_den: 1001,
          color_space: "709",
          color_range: "limited",
          x264opts: `scenecut=0:force_key_frames="expr:gte(t,n_forced*${gop})"`
        }
      },
      audio_settings: {
        sample_rate: audioSamplingRate * 1000,
        channels: 2,
        bitrate: audioBitrate,
        track_index: 1,
        mixer_id: 0,
        format: audioCodec,
        loudness_target: audioLKFS
      }
      // Note: SCTE-35 is not configured in OBS Studio itself
      // SCTE-35 insertion is handled externally
    }

    // Generate command line example for OBS
    const obsCommandLine = `obs --startstreaming --profile "${serviceName}" --scene "Live Scene" --collection "${serviceName} Collection"`

    // Generate OBS Studio profile configuration (separate from scene collection)
    const obsProfileConfig = {
      name: serviceName,
      output: {
        mode: "Advanced",
        rec_type: "None",
        streaming: {
          type: "rtmp_custom",
          service: "Custom",
          server: serverUrl,
          key: "",
          use_auth: false,
          encoder: "x264",
          profile: profileLevel,
          tune: "none",
          preset: "veryfast",
          bitrate: videoBitrate * 1000,
          keyint_sec: gop,
          bframes: bFrames,
          x264opts: `scenecut=0:force_key_frames="expr:gte(t,n_forced*${gop})"`
        }
      },
      video: {
        base_width: width,
        base_height: height,
        output_width: width,
        output_height: height,
        fps_type: 2,
        fps_num: 30000,
        fps_den: 1001,
        scale_type: "bicubic",
        color_format: "NV12",
        color_space: "709",
        color_range: "Limited"
      },
      audio: {
        sample_rate: audioSamplingRate * 1000,
        channels: 2,
        bitrate: audioBitrate,
        track1_bitrate: audioBitrate,
        track1_name: "Audio",
        track1_codec: audioCodec,
        track1_loudness_target: audioLKFS
      },
      advanced: {
        x264_use_cbr: true,
        x264_bitrate: videoBitrate * 1000,
        x264_keyint_sec: gop,
        x264_bframes: bFrames,
        x264_profile: profile,
        x264_tune: "none",
        x264_preset: "veryfast",
        x264opts: `scenecut=0:force_key_frames="expr:gte(t,n_forced*${gop})"`
      }
      // Note: SCTE-35 is not configured in OBS Studio itself
      // SCTE-35 insertion is handled externally through the media server
    }

    console.log('OBS configuration generated for:', serviceName)

    return NextResponse.json({
      success: true,
      config: {
        obsBasicConfig,
        obsJsonConfig,
        obsProfileConfig,
        obsCommandLine,
        streamConfig: obsJsonConfig
      },
      message: 'OBS Studio configuration generated successfully using official format'
    })
  } catch (error) {
    console.error('Error generating OBS configuration:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to generate OBS configuration' },
      { status: 500 }
    )
  }
}