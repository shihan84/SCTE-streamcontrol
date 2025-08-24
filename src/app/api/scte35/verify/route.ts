import { NextRequest, NextResponse } from 'next/server'

interface SCTE35VerificationRequest {
  serverUrl: string
  username: string
  password: string
  streamName: string
  checkMethod?: 'hls' | 'mpegts' | 'api' | 'all'
  timeout?: number
}

interface SCTE35VerificationResponse {
  success: boolean
  message: string
  streamName: string
  verificationResults: {
    serverAPI?: {
      available: boolean
      scte35Enabled: boolean
      lastEvents?: any[]
      eventCount: number
      details?: string
    }
    hlsManifest?: {
      available: boolean
      hasSCTE35: boolean
      manifestUrl?: string
      cues?: any[]
      details?: string
    }
    streamHealth?: {
      alive: boolean
      bitrate?: number
      viewers?: number
      uptime?: number
      details?: string
    }
  }
  summary: {
    scte35Detected: boolean
    detectionMethods: string[]
    confidence: 'low' | 'medium' | 'high'
    recommendations: string[]
  }
  error?: string
}

export async function POST(request: NextRequest) {
  try {
    const body = await request.json() as SCTE35VerificationRequest
    const { 
      serverUrl, 
      username, 
      password, 
      streamName,
      checkMethod = 'all',
      timeout = 10000
    } = body

    // Validate required parameters
    if (!serverUrl || !username || !password || !streamName) {
      return NextResponse.json<SCTE35VerificationResponse>({
        success: false,
        message: 'Missing required parameters',
        streamName: streamName || 'unknown',
        verificationResults: {},
        summary: {
          scte35Detected: false,
          detectionMethods: [],
          confidence: 'low',
          recommendations: ['Provide all required parameters: serverUrl, username, password, streamName']
        },
        error: 'serverUrl, username, password, and streamName are required'
      }, { status: 400 })
    }

    // Normalize server URL
    let normalizedUrl = serverUrl.endsWith('/') ? serverUrl.slice(0, -1) : serverUrl
    if (!normalizedUrl.startsWith('http://') && !normalizedUrl.startsWith('https://')) {
      normalizedUrl = `https://${normalizedUrl}`
    }

    console.log('🔍 Verifying SCTE-35 insertion for stream:', {
      serverUrl: normalizedUrl,
      streamName,
      checkMethod,
      timestamp: new Date().toISOString()
    })

    const authHeader = `Basic ${Buffer.from(`${username}:${password}`).toString('base64')}`
    const verificationResults: any = {}
    const detectionMethods: string[] = []
    let scte35Detected = false

    // Method 1: Check Self-Hosted Server API for SCTE-35
    if (checkMethod === 'api' || checkMethod === 'all') {
      try {
        const serverResult = await checkServerSCTE35(normalizedUrl, authHeader, streamName, timeout)
        verificationResults.serverAPI = serverResult
        
        if (serverResult.available && serverResult.scte35Enabled) {
          detectionMethods.push('Server API')
          if (serverResult.eventCount > 0) {
            scte35Detected = true
          }
        }
      } catch (error) {
        verificationResults.serverAPI = {
          available: false,
          scte35Enabled: false,
          eventCount: 0,
          details: `Server API check failed: ${error.message}`
        }
      }
    }

    // Method 2: Check HLS manifest for SCTE-35 cues
    if (checkMethod === 'hls' || checkMethod === 'all') {
      try {
        const hlsResult = await checkHLSForSCTE35(normalizedUrl, streamName, timeout)
        verificationResults.hlsManifest = hlsResult
        
        if (hlsResult.available && hlsResult.hasSCTE35) {
          detectionMethods.push('HLS Manifest')
          scte35Detected = true
        }
      } catch (error) {
        verificationResults.hlsManifest = {
          available: false,
          hasSCTE35: false,
          details: `HLS manifest check failed: ${error.message}`
        }
      }
    }

    // Method 3: Check stream health and basic info
    try {
      const healthResult = await checkStreamHealth(normalizedUrl, authHeader, streamName, timeout)
      verificationResults.streamHealth = healthResult
    } catch (error) {
      verificationResults.streamHealth = {
        alive: false,
        details: `Stream health check failed: ${error.message}`
      }
    }

    // Calculate confidence and generate recommendations
    const confidence = calculateConfidence(detectionMethods, verificationResults)
    const recommendations = generateRecommendations(verificationResults, scte35Detected)

    return NextResponse.json<SCTE35VerificationResponse>({
      success: true,
      message: scte35Detected 
        ? 'SCTE-35 insertion detected in stream' 
        : 'SCTE-35 insertion not detected',
      streamName,
      verificationResults,
      summary: {
        scte35Detected,
        detectionMethods,
        confidence,
        recommendations
      }
    })

  } catch (error) {
    console.error('Error verifying SCTE-35 insertion:', error)
    return NextResponse.json<SCTE35VerificationResponse>({
      success: false,
      message: 'Failed to verify SCTE-35 insertion',
      streamName: 'unknown',
      verificationResults: {},
      summary: {
        scte35Detected: false,
        detectionMethods: [],
        confidence: 'low',
        recommendations: ['Verification failed due to server error']
      },
      error: error.message
    }, { status: 500 })
  }
}

// Helper function to check Self-Hosted Server API for SCTE-35
async function checkServerSCTE35(serverUrl: string, authHeader: string, streamName: string, timeout: number) {
  const endpoints = [
    `/api/media-server/status`,
    `/api/scte/events`,
    `/api/stream/health`
  ]

  for (const endpoint of endpoints) {
    try {
      const response = await fetch(`${serverUrl}${endpoint}`, {
        method: 'GET',
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': authHeader,
          'User-Agent': 'SCTE35-Verifier/1.0'
        },
        signal: AbortSignal.timeout(timeout)
      })

      if (response.ok) {
        const data = await response.json()
        
        // Check for SCTE-35 configuration
        const scte35Enabled = data.scte35Enabled === true || 
                              data.config?.scte35Enabled === true ||
                              data.streams?.some((s: any) => s.scte35Enabled)

        // Get recent SCTE-35 events if available
        let lastEvents = []
        let eventCount = 0

        try {
          // Try to get SCTE-35 events from the events endpoint
          const scte35Endpoint = `${serverUrl}/api/scte/events`
          const scte35Response = await fetch(scte35Endpoint, {
            method: 'GET',
            headers: {
              'Authorization': authHeader,
              'User-Agent': 'SCTE35-Verifier/1.0'
            },
            signal: AbortSignal.timeout(timeout)
          })

          if (scte35Response.ok) {
            const scte35Data = await scte35Response.json()
            lastEvents = Array.isArray(scte35Data) ? scte35Data.slice(0, 10) : 
                         (scte35Data.events || []).slice(0, 10)
            eventCount = lastEvents.length
          }
        } catch (error) {
          // SCTE-35 events endpoint might not be available, continue
        }

        return {
          available: true,
          scte35Enabled,
          lastEvents,
          eventCount,
          details: scte35Enabled ? 'SCTE-35 is enabled in server configuration' : 'SCTE-35 is not enabled in server configuration'
        }
      }
    } catch (error) {
      continue
    }
  }

  return {
    available: false,
    scte35Enabled: false,
    eventCount: 0,
    details: 'Could not connect to server API'
  }
}

// Helper function to check HLS manifest for SCTE-35
async function checkHLSForSCTE35(serverUrl: string, streamName: string, timeout: number) {
  try {
    // Try different HLS manifest URLs
    const manifestUrls = [
      `${serverUrl}/${encodeURIComponent(streamName)}/index.m3u8`,
      `${serverUrl}/${encodeURIComponent(streamName)}/playlist.m3u8`,
      `${serverUrl}/hls/${encodeURIComponent(streamName)}/index.m3u8`,
      `${serverUrl}/hls/${encodeURIComponent(streamName)}/playlist.m3u8`
    ]

    for (const manifestUrl of manifestUrls) {
      try {
        const response = await fetch(manifestUrl, {
          method: 'GET',
          headers: {
            'User-Agent': 'SCTE35-Verifier/1.0'
          },
          signal: AbortSignal.timeout(timeout)
        })

        if (response.ok) {
          const manifestContent = await response.text()
          
          // Check for SCTE-35 cues in the manifest
          const hasSCTE35 = manifestContent.includes('#EXT-X-CUE-OUT') ||
                           manifestContent.includes('#EXT-X-CUE-IN') ||
                           manifestContent.includes('#EXT-OATCLS-SCTE35') ||
                           manifestContent.includes('scte35')

          // Extract cues if present
          const cues: any[] = []
          const lines = manifestContent.split('\n')
          
          for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (line.startsWith('#EXT-X-CUE-OUT')) {
              const durationMatch = line.match(/:([\d.]+)/)
              cues.push({
                type: 'CUE-OUT',
                duration: durationMatch ? parseFloat(durationMatch[1]) : null,
                line: i + 1
              })
            } else if (line.startsWith('#EXT-X-CUE-IN')) {
              cues.push({
                type: 'CUE-IN',
                line: i + 1
              })
            }
          }

          return {
            available: true,
            hasSCTE35,
            manifestUrl,
            cues,
            details: hasSCTE35 ? `Found ${cues.length} SCTE-35 cues in HLS manifest` : 'No SCTE-35 cues found in HLS manifest'
          }
        }
      } catch (error) {
        continue
      }
    }

    return {
      available: false,
      hasSCTE35: false,
      details: 'Could not access HLS manifest'
    }
  } catch (error) {
    return {
      available: false,
      hasSCTE35: false,
      details: `HLS manifest check failed: ${error.message}`
    }
  }
}

// Helper function to check stream health
async function checkStreamHealth(serverUrl: string, authHeader: string, streamName: string, timeout: number) {
  try {
    const endpoints = [
      `/api/stream/health`,
      `/api/media-server/status`
    ]

    for (const endpoint of endpoints) {
      try {
        const response = await fetch(`${serverUrl}${endpoint}`, {
          method: 'GET',
          headers: {
            'Authorization': authHeader,
            'User-Agent': 'SCTE35-Verifier/1.0'
          },
          signal: AbortSignal.timeout(timeout)
        })

        if (response.ok) {
          const data = await response.json()
          
          return {
            alive: data.status === 'active' || data.alive || false,
            bitrate: data.bitrate || data.metrics?.bitrate,
            viewers: data.viewers || data.metrics?.viewers || 0,
            uptime: data.uptime || data.metrics?.uptime,
            details: data.status === 'active' ? 'Stream is active and healthy' : 'Stream is not active'
          }
        }
      } catch (error) {
        continue
      }
    }

    return {
      alive: false,
      details: 'Could not determine stream health'
    }
  } catch (error) {
    return {
      alive: false,
      details: `Stream health check failed: ${error.message}`
    }
  }
}

// Helper function to calculate confidence level
function calculateConfidence(detectionMethods: string[], results: any): 'low' | 'medium' | 'high' {
  if (detectionMethods.length === 0) {
    return 'low'
  }
  
  if (detectionMethods.length >= 2 || 
      (results.serverAPI?.eventCount > 0) ||
      (results.hlsManifest?.cues?.length > 0)) {
    return 'high'
  }
  
  return 'medium'
}

// Helper function to generate recommendations
function generateRecommendations(results: any, scte35Detected: boolean): string[] {
  const recommendations: string[] = []

  if (!scte35Detected) {
    recommendations.push('SCTE-35 insertion is not currently detected in the stream')
    
    if (!results.serverAPI?.available) {
      recommendations.push('Check server connectivity and API access')
    }
    
    if (!results.serverAPI?.scte35Enabled) {
      recommendations.push('Enable SCTE-35 in server configuration')
    }
    
    if (!results.hlsManifest?.available) {
      recommendations.push('Check if HLS streaming is enabled for the stream')
    }
    
    if (!results.streamHealth?.alive) {
      recommendations.push('Start the stream or check stream configuration')
    }
    
    recommendations.push('Use the SCTE-35 injection API to insert events')
    recommendations.push('Check server logs for SCTE-35 related errors')
  } else {
    recommendations.push('SCTE-35 insertion is working correctly')
    recommendations.push('Monitor the stream for proper ad break timing')
    recommendations.push('Verify that players are responding to SCTE-35 cues')
    
    if (results.serverAPI?.eventCount > 0) {
      recommendations.push(`Found ${results.serverAPI.eventCount} recent SCTE-35 events`)
    }
    
    if (results.hlsManifest?.cues?.length > 0) {
      recommendations.push(`Found ${results.hlsManifest.cues.length} SCTE-35 cues in HLS manifest`)
    }
  }

  return recommendations
}