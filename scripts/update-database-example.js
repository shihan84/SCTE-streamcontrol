/**
 * SCTE-35 Database Update Example Script
 * 
 * This script demonstrates common database operations for the SCTE-35 streaming project.
 * Use this as a template for your own database updates.
 */

const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient({
  log: ['query', 'info', 'warn', 'error'],
});

async function updateDatabase() {
  try {
    console.log('🚀 Starting SCTE-35 database update...');
    
    // ========================================
    // Example 1: Add default SCTE-35 templates
    // ========================================
    console.log('\n📝 Adding default SCTE-35 templates...');
    
    const templates = await prisma.sCTE35Template.upsertMany([
      {
        where: { name: 'Standard Ad Break' },
        update: {},
        create: {
          name: 'Standard Ad Break',
          description: 'Standard 10-minute commercial break with 2-second pre-roll',
          adDuration: 600,
          eventId: 100023,
          cueOutCommand: 'CUE-OUT',
          cueInCommand: 'CUE-IN',
          crashOutCommand: 'CUE-IN',
          preRollDuration: 2,
          scteDataPid: 500,
          isDefault: true,
        },
      },
      {
        where: { name: 'Short Break' },
        update: {},
        create: {
          name: 'Short Break',
          description: '30-second commercial break with no pre-roll',
          adDuration: 30,
          eventId: 100024,
          cueOutCommand: 'CUE-OUT',
          cueInCommand: 'CUE-IN',
          crashOutCommand: 'CUE-IN',
          preRollDuration: 0,
          scteDataPid: 500,
          isDefault: false,
        },
      },
      {
        where: { name: 'Extended Break' },
        update: {},
        create: {
          name: 'Extended Break',
          description: '15-minute extended commercial break with 5-second pre-roll',
          adDuration: 900,
          eventId: 100025,
          cueOutCommand: 'CUE-OUT',
          cueInCommand: 'CUE-IN',
          crashOutCommand: 'CUE-IN',
          preRollDuration: 5,
          scteDataPid: 500,
          isDefault: false,
        },
      },
    ]);

    console.log(`✅ Created/updated ${templates.length} SCTE-35 templates`);

    // ========================================
    // Example 2: Add sample distributor configurations
    // ========================================
    console.log('\n🏢 Adding sample distributor configurations...');
    
    const distributors = await prisma.distributor.upsertMany([
      {
        where: { name: 'Major Cable Network' },
        update: {},
        create: {
          name: 'Major Cable Network',
          status: 'active',
          contact_info: {
            email: 'tech@majorcable.com',
            phone: '+1-555-0123',
            technical_contact: 'John Doe',
          },
          streams_count: 5,
          compliance_score: 98.5,
          delivery_success_rate: 99.2,
          issues_count: 0,
        },
      },
      {
        where: { name: 'Regional Broadcaster' },
        update: {},
        create: {
          name: 'Regional Broadcaster',
          status: 'warning',
          contact_info: {
            email: 'support@regional.tv',
            phone: '+1-555-0456',
            technical_contact: 'Jane Smith',
          },
          streams_count: 3,
          compliance_score: 92.1,
          delivery_success_rate: 95.8,
          issues_count: 2,
        },
      },
      {
        where: { name: 'Streaming Platform' },
        update: {},
        create: {
          name: 'Streaming Platform',
          status: 'active',
          contact_info: {
            email: 'api@streamingplatform.com',
            phone: '+1-555-0789',
            technical_contact: 'Mike Johnson',
          },
          streams_count: 10,
          compliance_score: 96.8,
          delivery_success_rate: 97.5,
          issues_count: 1,
        },
      },
    ]);

    console.log(`✅ Created/updated ${distributors.length} distributor configurations`);

    // ========================================
    // Example 3: Add sample SCTE-35 events
    // ========================================
    console.log('\n📡 Adding sample SCTE-35 events...');
    
    const events = await prisma.sCTE35Event.createMany({
      data: [
        {
          eventId: 100026,
          type: 'CUE-OUT',
          adDuration: 300,
          preRollDuration: 2,
          status: 'completed',
          streamId: 'stream_1',
        },
        {
          eventId: 100027,
          type: 'CUE-IN',
          adDuration: 0,
          preRollDuration: 0,
          status: 'completed',
          streamId: 'stream_1',
        },
        {
          eventId: 100028,
          type: 'CUE-OUT',
          adDuration: 180,
          preRollDuration: 0,
          status: 'pending',
          streamId: 'stream_2',
        },
      ],
      skipDuplicates: true,
    });

    console.log(`✅ Created ${events.count} SCTE-35 events`);

    // ========================================
    // Example 4: Update existing records
    // ========================================
    console.log('\n🔄 Updating existing records...');
    
    // Update users with default roles
    const updatedUsers = await prisma.user.updateMany({
      where: { 
        OR: [
          { role: null },
          { role: '' }
        ]
      },
      data: { role: 'user' },
    });

    console.log(`✅ Updated ${updatedUsers.count} users with default roles`);

    // Update posts to published if they have content
    const updatedPosts = await prisma.post.updateMany({
      where: { 
        content: { not: null },
        published: false 
      },
      data: { published: true },
    });

    console.log(`✅ Published ${updatedPosts.count} posts with content`);

    // ========================================
    // Example 5: Add sample stream configurations
    // ========================================
    console.log('\n🎬 Adding sample stream configurations...');
    
    const streamConfigs = await prisma.streamConfig.createMany({
      data: [
        {
          serviceName: 'Live TV Channel 1',
          videoResolution: '1920x1080',
          videoCodec: 'H.264',
          pcr: 'Video Embedded',
          profileLevel: 'High@Auto',
          gop: 12,
          bFrames: 5,
          videoBitrate: 5,
          chroma: '4:2:0',
          aspectRatio: '16:9',
          audioCodec: 'AAC-LC',
          audioBitrate: 128,
          audioLKFS: -20,
          audioSamplingRate: 48,
          scteDataPID: 500,
          nullPID: 8191,
          latency: 2000,
        },
        {
          serviceName: 'Live TV Channel 2',
          videoResolution: '1280x720',
          videoCodec: 'H.264',
          pcr: 'Video Embedded',
          profileLevel: 'High@Auto',
          gop: 12,
          bFrames: 3,
          videoBitrate: 3,
          chroma: '4:2:0',
          aspectRatio: '16:9',
          audioCodec: 'AAC-LC',
          audioBitrate: 96,
          audioLKFS: -20,
          audioSamplingRate: 48,
          scteDataPID: 500,
          nullPID: 8191,
          latency: 1500,
        },
      ],
      skipDuplicates: true,
    });

    console.log(`✅ Created ${streamConfigs.count} stream configurations`);

    // ========================================
    // Example 6: Database statistics
    // ========================================
    console.log('\n📊 Database statistics after update:');
    
    const userCount = await prisma.user.count();
    const postCount = await prisma.post.count();
    const templateCount = await prisma.sCTE35Template.count();
    const distributorCount = await prisma.distributor.count();
    const eventCount = await prisma.sCTE35Event.count();
    const streamConfigCount = await prisma.streamConfig.count();

    console.log(`👥 Users: ${userCount}`);
    console.log(`📝 Posts: ${postCount}`);
    console.log(`🎯 SCTE-35 Templates: ${templateCount}`);
    console.log(`🏢 Distributors: ${distributorCount}`);
    console.log(`📡 SCTE-35 Events: ${eventCount}`);
    console.log(`🎬 Stream Configurations: ${streamConfigCount}`);

    // ========================================
    // Example 7: Verification queries
    // ========================================
    console.log('\n✅ Verifying data integrity...');

    // Check for active distributors
    const activeDistributors = await prisma.distributor.findMany({
      where: { status: 'active' },
      select: { name: true, compliance_score: true }
    });

    console.log(`🟢 Active distributors: ${activeDistributors.length}`);
    activeDistributors.forEach(dist => {
      console.log(`   - ${dist.name} (${dist.compliance_score}% compliance)`);
    });

    // Check recent SCTE-35 events
    const recentEvents = await prisma.sCTE35Event.findMany({
      where: { 
        timestamp: { 
          gte: new Date(Date.now() - 24 * 60 * 60 * 1000) // Last 24 hours
        }
      },
      orderBy: { timestamp: 'desc' },
      take: 5
    });

    console.log(`📡 Recent SCTE-35 events: ${recentEvents.length}`);
    recentEvents.forEach(event => {
      console.log(`   - ${event.type} (Event ID: ${event.eventId})`);
    });

    console.log('\n🎉 Database update completed successfully!');
    
  } catch (error) {
    console.error('❌ Database update failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

// Helper function for upsertMany (since Prisma doesn't have it built-in)
async function upsertMany(model, records) {
  const results = [];
  for (const record of records) {
    const result = await prisma[model].upsert(record);
    results.push(result);
  }
  return results;
}

// Add the helper to Prisma client
prisma.sCTE35Template.upsertMany = async (records) => upsertMany('sCTE35Template', records);
prisma.distributor.upsertMany = async (records) => upsertMany('distributor', records);

// Run the update
updateDatabase();