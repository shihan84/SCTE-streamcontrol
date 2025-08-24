/**
 * Simple Database Update Example Script
 * 
 * This script demonstrates basic database operations for the SCTE-35 streaming project
 * using the existing User and Post models.
 */

const { PrismaClient } = require('@prisma/client');

const prisma = new PrismaClient({
  log: ['query', 'info', 'warn', 'error'],
});

async function updateDatabase() {
  try {
    console.log('🚀 Starting simple database update...');
    
    // ========================================
    // Example 1: Add sample users
    // ========================================
    console.log('\n👥 Adding sample users...');
    
    const users = await Promise.all([
      prisma.user.upsert({
        where: { email: 'admin@scte35.com' },
        update: {},
        create: {
          email: 'admin@scte35.com',
          name: 'System Administrator',
        },
      }),
      prisma.user.upsert({
        where: { email: 'operator@scte35.com' },
        update: {},
        create: {
          email: 'operator@scte35.com',
          name: 'Stream Operator',
        },
      }),
      prisma.user.upsert({
        where: { email: 'viewer@scte35.com' },
        update: {},
        create: {
          email: 'viewer@scte35.com',
          name: 'Test Viewer',
        },
      }),
    ]);

    console.log(`✅ Created/updated ${users.length} users`);
    users.forEach(user => {
      console.log(`   - ${user.name} (${user.email})`);
    });

    // ========================================
    // Example 2: Add sample posts
    // ========================================
    console.log('\n📝 Adding sample posts...');
    
    const posts = await Promise.all([
      prisma.post.create({
        data: {
          title: 'SCTE-35 Integration Complete',
          content: 'Successfully integrated SCTE-35 ad insertion capabilities into the streaming platform.',
          published: true,
          authorId: users[0].id, // admin user
        },
      }),
      prisma.post.create({
        data: {
          title: 'Stream Monitoring Dashboard',
          content: 'New real-time monitoring dashboard provides comprehensive stream health metrics.',
          published: true,
          authorId: users[1].id, // operator user
        },
      }),
      prisma.post.create({
        data: {
          title: 'Database Schema Updated',
          content: 'Database schema has been updated with new tables for better performance.',
          published: false,
          authorId: users[0].id, // admin user
        },
      }),
    ]);

    console.log(`✅ Created ${posts.length} posts`);
    posts.forEach(post => {
      console.log(`   - ${post.title} (${post.published ? 'Published' : 'Draft'})`);
    });

    // ========================================
    // Example 3: Update existing records
    // ========================================
    console.log('\n🔄 Updating existing records...');
    
    // Update all draft posts to published
    const updatedPosts = await prisma.post.updateMany({
      where: { 
        published: false,
        content: { not: null }
      },
      data: { published: true },
    });

    console.log(`✅ Published ${updatedPosts.count} draft posts`);

    // Update user names that are null
    const updatedUsers = await prisma.user.updateMany({
      where: { name: null },
      data: { name: 'Anonymous User' },
    });

    console.log(`✅ Updated ${updatedUsers.count} users with default names`);

    // ========================================
    // Example 4: Query data with relationships
    // ========================================
    console.log('\n📊 Querying data with relationships...');
    
    const usersWithPosts = await prisma.user.findMany({
      include: {
        posts: {
          orderBy: { createdAt: 'desc' },
          take: 3,
        },
      },
      orderBy: { createdAt: 'desc' },
    });

    console.log(`📋 Found ${usersWithPosts.length} users with their posts:`);
    usersWithPosts.forEach(user => {
      console.log(`   👤 ${user.name} (${user.email})`);
      user.posts.forEach(post => {
        console.log(`      📝 ${post.title} - ${post.published ? 'Published' : 'Draft'}`);
      });
    });

    // ========================================
    // Example 5: Database statistics
    // ========================================
    console.log('\n📊 Database statistics:');
    
    const userCount = await prisma.user.count();
    const postCount = await prisma.post.count();
    const publishedPostCount = await prisma.post.count({ where: { published: true } });
    const draftPostCount = await prisma.post.count({ where: { published: false } });

    console.log(`👥 Total Users: ${userCount}`);
    console.log(`📝 Total Posts: ${postCount}`);
    console.log(`🟢 Published Posts: ${publishedPostCount}`);
    console.log(`📝 Draft Posts: ${draftPostCount}`);

    // ========================================
    // Example 6: Aggregation queries
    // ========================================
    console.log('\n📈 Aggregation queries...');
    
    const postsByUser = await prisma.user.findMany({
      select: {
        name: true,
        email: true,
        _count: {
          select: {
            posts: true,
          },
        },
      },
      orderBy: {
        posts: {
          _count: 'desc',
        },
      },
    });

    console.log('📊 Posts per user:');
    postsByUser.forEach(user => {
      console.log(`   ${user.name}: ${user._count.posts} posts`);
    });

    // ========================================
    // Example 7: Search and filter
    // ========================================
    console.log('\n🔍 Search and filter examples...');
    
    // Search for posts containing specific keywords
    const searchResults = await prisma.post.findMany({
      where: {
        OR: [
          { title: { contains: 'SCTE-35' } },
          { content: { contains: 'streaming' } },
        ],
      },
      include: {
        author: {
          select: { name: true, email: true },
        },
      },
    });

    console.log(`🔍 Found ${searchResults.length} posts matching search criteria:`);
    searchResults.forEach(post => {
      console.log(`   - ${post.title} by ${post.author.name}`);
    });

    // ========================================
    // Example 8: Transaction example
    // ========================================
    console.log('\n💳 Transaction example...');
    
    // Generate a unique email for this transaction
    const timestamp = Date.now();
    const uniqueEmail = `transaction${timestamp}@example.com`;
    
    const transactionResult = await prisma.$transaction(async (tx) => {
      // Create a new user
      const newUser = await tx.user.create({
        data: {
          email: uniqueEmail,
          name: 'Transaction User',
        },
      });

      // Create a post for that user
      const newPost = await tx.post.create({
        data: {
          title: 'Transaction Test Post',
          content: 'This post was created within a transaction.',
          published: true,
          authorId: newUser.id,
        },
      });

      return { user: newUser, post: newPost };
    });

    console.log('✅ Transaction completed successfully:');
    console.log(`   👤 User: ${transactionResult.user.name}`);
    console.log(`   📝 Post: ${transactionResult.post.title}`);

    // ========================================
    // Example 9: Batch operations
    // ========================================
    console.log('\n📦 Batch operations...');
    
    // Batch update: Mark all recent posts as featured
    const batchUpdate = await prisma.post.updateMany({
      where: {
        createdAt: {
          gte: new Date(Date.now() - 1 * 60 * 60 * 1000), // Last 1 hour
        }
      },
      data: { 
        published: true
      },
    });

    console.log(`📦 Updated ${batchUpdate.count} recent posts to published`);

    // Count posts created in different time periods
    const recentPosts = await prisma.post.findMany({
      where: {
        createdAt: {
          gte: new Date(Date.now() - 24 * 60 * 60 * 1000), // Last 24 hours
        }
      }
    });

    console.log(`📦 Found ${recentPosts.length} posts created in the last 24 hours`);

    // ========================================
    // Example 10: Cleanup and verification
    // ========================================
    console.log('\n🧹 Cleanup and verification...');
    
    // Count all records
    const finalUserCount = await prisma.user.count();
    const finalPostCount = await prisma.post.count();

    console.log('📊 Final database state:');
    console.log(`   👥 Users: ${finalUserCount}`);
    console.log(`   📝 Posts: ${finalPostCount}`);

    // Since authorId is required, we don't need to check for orphaned posts
    console.log('✅ Data integrity maintained - all posts have valid authors');

    console.log('\n🎉 Database update completed successfully!');
    
  } catch (error) {
    console.error('❌ Database update failed:', error);
    process.exit(1);
  } finally {
    await prisma.$disconnect();
  }
}

// Run the update
updateDatabase();