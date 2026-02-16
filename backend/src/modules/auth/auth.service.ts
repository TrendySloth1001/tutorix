import { OAuth2Client } from 'google-auth-library';
import jwt from 'jsonwebtoken';
import dotenv from 'dotenv';
import prisma from '../../infra/prisma.js';
import { InvitationService } from '../coaching/invitation.service.js';

dotenv.config();

const client = new OAuth2Client(process.env.GOOGLE_WEB_CLIENT_ID);
const invitationService = new InvitationService();

export class AuthService {
    async verifyGoogleToken(idToken: string, sessionInfo?: { ip?: string | undefined, userAgent?: string | undefined }) {
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
                    // Only update email on login (don't overwrite user's custom name/picture)
                    email: payload.email!,
                },
                create: {
                    // On first signup, use Google data as defaults
                    googleId: payload.sub,
                    email: payload.email!,
                    name: payload.name ?? null,
                    picture: payload.picture ?? null,
                },
            });

            // Log session if sessionInfo is provided
            if (sessionInfo) {
                await prisma.loginSession.create({
                    data: {
                        userId: user.id,
                        ip: sessionInfo.ip ?? null,
                        userAgent: sessionInfo.userAgent ?? null,
                    },
                });
            }

            // Auto-claim any pending invitations for this user's email/phone
            try {
                await invitationService.claimPendingInvitations(
                    user.id,
                    user.email,
                    user.phone ?? undefined
                );
            } catch (claimError) {
                console.warn('Failed to claim pending invitations:', claimError);
                // Non-critical: don't fail auth over invitation claim issues
            }

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

