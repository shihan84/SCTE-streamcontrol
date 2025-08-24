import { NextRequest, NextResponse } from 'next/server'
import { execSync } from 'child_process'

interface FFmpegStatus {
  installed: boolean
  version: string
  path: string
  buildConfig: string[]
  processes: FFmpegProcess[]
}

interface FFmpegProcess {
  pid: number
  command: string
  cpu: number
  memory: number
  status: 'running' | 'stopped' | 'error'
  startTime: Date
  uptime: number
}

function execSyncCommand(command: string): { stdout: string; stderr: string; status: number } {
  try {
    const stdout = execSync(command, { encoding: 'utf8' })
    return { stdout, stderr: '', status: 0 }
  } catch (error: any) {
    return { stdout: '', stderr: error.message, status: 1 }
  }
}

export async function GET(request: NextRequest) {
  try {
    // Check if FFmpeg is installed
    const ffmpegCheck = execSyncCommand('which ffmpeg')
    const isInstalled = ffmpegCheck.status === 0 && ffmpegCheck.stdout.trim() !== ''
    
    let version = ''
    let path = ''
    let buildConfig: string[] = []
    
    if (isInstalled) {
      path = ffmpegCheck.stdout.trim()
      
      // Get FFmpeg version
      const versionCheck = execSyncCommand('ffmpeg -version')
      if (versionCheck.status === 0) {
        const versionLine = versionCheck.stdout.split('\n')[0]
        version = versionLine.replace('ffmpeg version', '').trim()
        
        // Extract build configuration
        buildConfig = versionCheck.stdout
          .split('\n')
          .slice(1)
          .filter(line => line.trim() !== '')
          .map(line => line.trim())
      }
    }
    
    // Get running FFmpeg processes
    const processes: FFmpegProcess[] = []
    try {
      const psCommand = "ps aux | grep ffmpeg | grep -v grep || true"
      const psResult = execSyncCommand(psCommand)
      
      if (psResult.status === 0 && psResult.stdout.trim()) {
        const lines = psResult.stdout.trim().split('\n')
        
        for (const line of lines) {
          if (line.trim()) {
            const parts = line.trim().split(/\s+/)
            if (parts.length >= 11) {
              const pid = parseInt(parts[1])
              const cpu = parseFloat(parts[2]) || 0
              const memory = parseFloat(parts[3]) || 0
              const command = parts.slice(10).join(' ')
              
              // Get process start time and uptime
              let uptime = 0
              let startTime = new Date()
              try {
                const etimeResult = execSyncCommand(`ps -p ${pid} -o etime= --no-headers`)
                if (etimeResult.status === 0) {
                  const etime = etimeResult.stdout.trim()
                  uptime = parseUptime(etime)
                }
                
                const lstartResult = execSyncCommand(`ps -p ${pid} -o lstart= --no-headers`)
                if (lstartResult.status === 0) {
                  startTime = new Date(lstartResult.stdout.trim())
                }
              } catch (error) {
                // If we can't get detailed info, use current time
              }
              
              processes.push({
                pid,
                command,
                cpu,
                memory,
                status: 'running',
                startTime,
                uptime
              })
            }
          }
        }
      }
    } catch (error) {
      console.error('Error getting FFmpeg processes:', error)
    }
    
    const status: FFmpegStatus = {
      installed: isInstalled,
      version,
      path,
      buildConfig,
      processes
    }
    
    return NextResponse.json(status)
  } catch (error) {
    console.error('Error checking FFmpeg status:', error)
    return NextResponse.json(
      { error: 'Failed to check FFmpeg status' },
      { status: 500 }
    )
  }
}

function parseUptime(etime: string): number {
  // Parse etime format: [[DD-]HH:]MM:SS
  const parts = etime.split('-')
  let days = 0
  let timePart = etime
  
  if (parts.length === 2) {
    days = parseInt(parts[0])
    timePart = parts[1]
  }
  
  const timeComponents = timePart.split(':').map(Number)
  let hours = 0
  let minutes = 0
  let seconds = 0
  
  if (timeComponents.length === 3) {
    hours = timeComponents[0]
    minutes = timeComponents[1]
    seconds = timeComponents[2]
  } else if (timeComponents.length === 2) {
    minutes = timeComponents[0]
    seconds = timeComponents[1]
  }
  
  return days * 86400 + hours * 3600 + minutes * 60 + seconds
}