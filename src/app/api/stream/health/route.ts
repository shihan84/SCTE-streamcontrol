import { NextRequest, NextResponse } from 'next/server'

// In-memory health data (in production, use a database or state management)
let healthData = {
  isLive: false,
  viewers: 0,
  bitrate: 0,
  fps: 0,
  audioLevel: -20,
  latency: 0,
  health: 'good',
  lastUpdated: null,
  uptime: 0,
  errors: [],
  warnings: []
}

export async function GET(request: NextRequest) {
  try {
    const { searchParams } = new URL(request.url)
    const detailed = searchParams.get('detailed') === 'true'

    // Simulate real-time health data updates
    if (healthData.isLive) {
      // Simulate some realistic variations
      healthData = {
        ...healthData,
        viewers: Math.floor(Math.random() * 1000) + 100,
        bitrate: 5 + (Math.random() - 0.5) * 0.5,
        fps: 29.97 + (Math.random() - 0.5) * 0.1,
        audioLevel: -20 + (Math.random() - 0.5) * 2,
        latency: 2000 + (Math.random() - 0.5) * 100,
        lastUpdated: new Date().toISOString()
      }

      // Calculate health status
      const bitrateDiff = Math.abs(healthData.bitrate - 5)
      const audioDiff = Math.abs(healthData.audioLevel - (-20))
      
      if (bitrateDiff > 1 || audioDiff > 5 || healthData.latency > 3000) {
        healthData.health = 'warning'
        if (bitrateDiff > 2 || audioDiff > 10 || healthData.latency > 5000) {
          healthData.health = 'error'
        }
      } else {
        healthData.health = 'good'
      }

      // Calculate uptime
      if (healthData.startTime) {
        const startTime = new Date(healthData.startTime)
        const now = new Date()
        healthData.uptime = Math.floor((now.getTime() - startTime.getTime()) / 1000)
      }
    }

    if (detailed) {
      return NextResponse.json({
        success: true,
        health: healthData,
        metrics: {
          bitrate_stability: Math.abs(healthData.bitrate - 5) < 0.5 ? 'good' : 'warning',
          audio_stability: Math.abs(healthData.audioLevel - (-20)) < 3 ? 'good' : 'warning',
          latency_status: healthData.latency < 2500 ? 'good' : 'warning',
          stream_quality: healthData.health === 'good' ? 95 : healthData.health === 'warning' ? 75 : 45
        },
        recommendations: generateRecommendations(healthData)
      })
    }

    return NextResponse.json({
      success: true,
      health: healthData
    })
  } catch (error) {
    console.error('Error fetching stream health:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to fetch stream health data' },
      { status: 500 }
    )
  }
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json()
    const { isLive, startTime, viewers, bitrate, fps, audioLevel, latency } = body

    // Update health data with provided values
    healthData = {
      ...healthData,
      isLive: isLive !== undefined ? isLive : healthData.isLive,
      startTime: startTime || healthData.startTime,
      viewers: viewers !== undefined ? viewers : healthData.viewers,
      bitrate: bitrate !== undefined ? bitrate : healthData.bitrate,
      fps: fps !== undefined ? fps : healthData.fps,
      audioLevel: audioLevel !== undefined ? audioLevel : healthData.audioLevel,
      latency: latency !== undefined ? latency : healthData.latency,
      lastUpdated: new Date().toISOString()
    }

    // Calculate health status
    const bitrateDiff = Math.abs(healthData.bitrate - 5)
    const audioDiff = Math.abs(healthData.audioLevel - (-20))
    
    if (bitrateDiff > 1 || audioDiff > 5 || healthData.latency > 3000) {
      healthData.health = 'warning'
      if (bitrateDiff > 2 || audioDiff > 10 || healthData.latency > 5000) {
        healthData.health = 'error'
      }
    } else {
      healthData.health = 'good'
    }

    // Calculate uptime
    if (healthData.startTime && healthData.isLive) {
      const startTime = new Date(healthData.startTime)
      const now = new Date()
      healthData.uptime = Math.floor((now.getTime() - startTime.getTime()) / 1000)
    }

    console.log('Stream health updated:', healthData)

    return NextResponse.json({
      success: true,
      health: healthData,
      message: 'Stream health data updated successfully'
    })
  } catch (error) {
    console.error('Error updating stream health:', error)
    return NextResponse.json(
      { success: false, error: 'Failed to update stream health data' },
      { status: 500 }
    )
  }
}

function generateRecommendations(healthData) {
  const recommendations = []

  if (healthData.bitrate < 4.5) {
    recommendations.push({
      type: 'warning',
      message: 'Bitrate is below target. Consider increasing video bitrate settings.'
    })
  }

  if (healthData.bitrate > 5.5) {
    recommendations.push({
      type: 'warning',
      message: 'Bitrate is above target. Consider reducing video bitrate settings.'
    })
  }

  if (Math.abs(healthData.audioLevel - (-20)) > 3) {
    recommendations.push({
      type: 'warning',
      message: 'Audio level is not at target LKFS. Adjust audio levels in OBS.'
    })
  }

  if (healthData.latency > 2500) {
    recommendations.push({
      type: 'warning',
      message: 'Stream latency is high. Check network conditions and server settings.'
    })
  }

  if (healthData.latency > 5000) {
    recommendations.push({
      type: 'error',
      message: 'Critical latency detected. Consider restarting the stream.'
    })
  }

  if (healthData.health === 'good') {
    recommendations.push({
      type: 'success',
      message: 'Stream health is optimal. All parameters are within acceptable ranges.'
    })
  }

  return recommendations
}