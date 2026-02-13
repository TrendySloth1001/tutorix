import prisma from './src/infra/prisma.js';

async function main() {
    try {
        const sessions = await prisma.loginSession.findMany({
            orderBy: { createdAt: 'desc' },
            take: 5,
        });
        console.log('Last 5 Login Sessions:');
        console.log(JSON.stringify(sessions, null, 2));
    } catch (error) {
        console.error('Error fetching sessions:', error);
    } finally {
        process.exit();
    }
}

main();
