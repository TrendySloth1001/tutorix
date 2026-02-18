import prisma from './dist/infra/prisma.js';

const ADMIN_EMAIL = process.env.ADMIN_EMAIL || 'nkumawat8956@gmail.com';

async function setAdmin() {
    try {
        const user = await prisma.user.findUnique({
            where: { email: ADMIN_EMAIL },
        });

        if (!user) {
            console.log(`❌ User with email ${ADMIN_EMAIL} not found`);
            return;
        }

        await prisma.user.update({
            where: { email: ADMIN_EMAIL },
            data: { isAdmin: true },
        });

        console.log(`✅ Successfully set isAdmin = true for ${ADMIN_EMAIL}`);
    } catch (error) {
        console.error('❌ Error:', error);
    } finally {
        await prisma.$disconnect();
    }
}

setAdmin();
