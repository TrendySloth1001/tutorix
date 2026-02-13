import { OAuth2Client } from 'google-auth-library';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';

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

            return {
                email: payload.email,
                name: payload.name,
                picture: payload.picture,
                sub: payload.sub, // Google user ID
            };
        } catch (error: any) {
            console.error('Error verifying Google token:', error);
            throw new Error(`Authentication failed: ${error.message}`);
        }
    }

    generateToken(user: any) {
        return jwt.sign(
            { id: user.sub, email: user.email, name: user.name },
            process.env.JWT_SECRET || 'secret',
            { expiresIn: '7d' }
        );
    }
}
