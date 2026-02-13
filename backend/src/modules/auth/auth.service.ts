import { OAuth2Client } from 'google-auth-library';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import prisma from '../../infra/prisma.js';

dotenv.config();

const client = new OAuth2Client(process.env.GOOGLE_WEB_CLIENT_ID);

export class AuthService {
    async verifyGoogleToken(idToken: string) {
        try {
            const ticket = await client.verifyIdToken({
                idToken,
                audience: process.env.GOOGLE_WEB_CLIENT_ID as string,
            });
            const payload = ticket.getPayload();

            if (!payload) {
                throw new Error('Invalid token payload');
            }

            // Upsert user in the database
            const user = await prisma.user.upsert({
                where: { googleId: payload.sub },
                update: {
                    email: payload.email!,
                    name: payload.name ?? null,
                    picture: payload.picture ?? null,
                },
                create: {
                    googleId: payload.sub,
                    email: payload.email!,
                    name: payload.name ?? null,
                    picture: payload.picture ?? null,
                },
            });

            return user;
        } catch (error: any) {
            console.error('Error verifying Google token:', error);
            throw new Error(`Authentication failed: ${error.message}`);
        }
    }

    generateToken(user: any) {
        return jwt.sign(
            { id: user.id, email: user.email },
            process.env.JWT_SECRET as string,
            { expiresIn: '7d' }
        );
    }
}
