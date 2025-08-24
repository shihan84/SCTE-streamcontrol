import { NextRequest, NextResponse } from 'next/server';

export async function POST(request: NextRequest) {
  try {
    const body = await request.json();
    const { app, name, addr, flashver, swfurl, tcurl, pageurl } = body;

    console.log('RTMP Publish Event:', {
      app,
      name,
      addr,
      flashver,
      swfurl,
      tcurl,
      pageurl,
      timestamp: new Date().toISOString()
    });

    // Here you can add logic to handle stream publish events
    // For example: notify the media server, log to database, etc.

    return NextResponse.json({ 
      success: true, 
      message: 'Publish event received',
      stream: name,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Error handling publish event:', error);
    return NextResponse.json(
      { success: false, error: 'Internal server error' },
      { status: 500 }
    );
  }
}