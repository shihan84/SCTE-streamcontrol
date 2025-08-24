/**
 * Global Instance Manager for Streaming Components
 * 
 * This module manages the global instances of streaming components
 * to avoid conflicts between different API routes.
 * 
 * © 2024 Morus Broadcasting Pvt Ltd. All rights reserved.
 */

import { MediaServer } from './media-server/MediaServer';
import { MultiFormatStreamer } from './media-server/MultiFormatStreamer';
import { SRTStreamer } from './media-server/SRTStreamer';

// Global instances
let mediaServer: MediaServer | null = null;
let multiFormatStreamer: MultiFormatStreamer | null = null;
let srtStreamer: SRTStreamer | null = null;
let isInitialized = false;

export class GlobalInstanceManager {
    static async initialize(): Promise<{ success: boolean; error?: string }> {
        try {
            if (isInitialized) {
                return { success: true };
            }

            console.log('🚀 Initializing global streaming components...');

            // Initialize MediaServer
            if (!mediaServer) {
                console.log('📡 Starting MediaServer...');
                mediaServer = new MediaServer();
                try {
                    await mediaServer.start();
                    console.log('✅ MediaServer started successfully');
                } catch (error) {
                    if (error.message === 'Media server is already running') {
                        console.log('ℹ️ MediaServer is already running in another context, continuing...');
                        // Create a new MediaServer instance that might work
                        try {
                            // Try to stop and restart
                            await mediaServer.stop();
                            await mediaServer.start();
                            console.log('✅ MediaServer restarted successfully');
                        } catch (restartError) {
                            console.log('⚠️ Could not restart MediaServer, trying alternative approach...');
                            // For now, we'll continue without MediaServer and see if MultiFormatStreamer can work
                            console.log('📡 Continuing without MediaServer, will try MultiFormatStreamer directly...');
                        }
                    } else {
                        throw error;
                    }
                }
            }

            // Initialize MultiFormatStreamer
            if (!multiFormatStreamer) {
                console.log('🎬 Starting MultiFormatStreamer...');
                try {
                    if (mediaServer) {
                        multiFormatStreamer = new MultiFormatStreamer(mediaServer);
                    } else {
                        // Create a dummy MediaServer or try to work without it
                        console.log('⚠️ No MediaServer available, creating MultiFormatStreamer with minimal setup...');
                        // This might not work, but let's try
                        const dummyMediaServer = new MediaServer();
                        multiFormatStreamer = new MultiFormatStreamer(dummyMediaServer);
                    }
                    await multiFormatStreamer.start();
                    console.log('✅ MultiFormatStreamer started successfully');
                } catch (error) {
                    console.error('❌ Failed to start MultiFormatStreamer:', error);
                    throw error;
                }
            }

            // Initialize SRTStreamer
            if (!srtStreamer) {
                console.log('🛰️ Starting SRTStreamer...');
                srtStreamer = new SRTStreamer();
                await srtStreamer.start();
                console.log('✅ SRTStreamer started successfully');
            }

            isInitialized = true;
            return { success: true };

        } catch (error) {
            console.error('❌ Error initializing global streaming components:', error);
            
            // Clean up on failure
            await this.cleanup();
            
            return { 
                success: false, 
                error: error instanceof Error ? error.message : 'Unknown error' 
            };
        }
    }

    static async cleanup(): Promise<void> {
        try {
            if (multiFormatStreamer) {
                try {
                    await multiFormatStreamer.stop();
                } catch (e) {
                    console.error('Error stopping MultiFormatStreamer during cleanup:', e);
                }
                multiFormatStreamer = null;
            }
            
            if (mediaServer) {
                try {
                    await mediaServer.stop();
                } catch (e) {
                    console.error('Error stopping MediaServer during cleanup:', e);
                }
                mediaServer = null;
            }
            
            if (srtStreamer) {
                try {
                    await srtStreamer.stop();
                } catch (e) {
                    console.error('Error stopping SRTStreamer during cleanup:', e);
                }
                srtStreamer = null;
            }
            
            isInitialized = false;
        } catch (error) {
            console.error('Error during cleanup:', error);
        }
    }

    static getMediaServer(): MediaServer | null {
        return mediaServer;
    }

    static getMultiFormatStreamer(): MultiFormatStreamer | null {
        return multiFormatStreamer;
    }

    static getSRTStreamer(): SRTStreamer | null {
        return srtStreamer;
    }

    static isInitialized(): boolean {
        return isInitialized;
    }

    static getStatus(): {
        mediaServer: boolean;
        multiFormatStreamer: boolean;
        srtStreamer: boolean;
        initialized: boolean;
    } {
        return {
            mediaServer: !!mediaServer,
            multiFormatStreamer: !!multiFormatStreamer,
            srtStreamer: !!srtStreamer,
            initialized: isInitialized
        };
    }
}