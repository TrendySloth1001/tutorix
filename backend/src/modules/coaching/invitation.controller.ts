import type { Request, Response } from 'express';
import { InvitationService } from './invitation.service.js';

const invitationService = new InvitationService();

export class InvitationController {
    /**
     * POST /coaching/:id/invite/lookup
     * Search for a user by phone or email before sending an invitation.
     */
    async lookup(req: Request, res: Response) {
        try {
            const { contact } = req.body;
            if (!contact) {
                return res.status(400).json({ error: 'Contact (phone or email) is required' });
            }

            const user = await invitationService.lookupByContact(contact);

            if (user) {
                return res.json({ found: true, user });
            } else {
                return res.json({ found: false, message: 'User not found on platform. A pending invitation will be created.' });
            }
        } catch (error: any) {
            return res.status(500).json({ error: error.message });
        }
    }

    /**
     * POST /coaching/:id/invite
     * Send an invitation to a user, ward, or unresolved contact.
     */
    async createInvitation(req: Request, res: Response) {
        try {
            const coachingId = req.params.id as string;
            const invitedById = (req as any).user.id;
            const { role, userId, wardId, invitePhone, inviteEmail, inviteName, message } = req.body;

            if (!role) {
                return res.status(400).json({ error: 'Role is required' });
            }

            // Must have at least one target identifier
            if (!userId && !wardId && !invitePhone && !inviteEmail) {
                return res.status(400).json({ error: 'At least one target (userId, wardId, phone, or email) is required' });
            }

            const invitation = await invitationService.createInvitation({
                coachingId,
                role,
                userId,
                wardId,
                invitePhone,
                inviteEmail,
                inviteName,
                message,
                invitedById,
            });

            return res.status(201).json(invitation);
        } catch (error: any) {
            return res.status(400).json({ error: error.message });
        }
    }

    /**
     * GET /coaching/:id/invitations
     * List all invitations for a coaching (admin view).
     */
    async getCoachingInvitations(req: Request, res: Response) {
        try {
            const coachingId = req.params.id as string;
            const invitations = await invitationService.getInvitationsForCoaching(coachingId);
            return res.json(invitations);
        } catch (error: any) {
            return res.status(500).json({ error: error.message });
        }
    }

    /**
     * GET /user/invitations
     * List pending invitations for the current user (and their wards).
     */
    async getMyInvitations(req: Request, res: Response) {
        try {
            const userId = (req as any).user.id;
            const invitations = await invitationService.getMyInvitations(userId);
            return res.json(invitations);
        } catch (error: any) {
            return res.status(500).json({ error: error.message });
        }
    }

    /**
     * POST /user/invitations/:invitationId/respond
     * Accept or decline an invitation.
     */
    async respondToInvitation(req: Request, res: Response) {
        try {
            const invitationId = req.params.invitationId as string;
            const userId = (req as any).user.id;
            const { accept } = req.body;

            if (typeof accept !== 'boolean') {
                return res.status(400).json({ error: '"accept" field (boolean) is required' });
            }

            const result = await invitationService.respondToInvitation(invitationId, userId, accept);
            return res.json(result);
        } catch (error: any) {
            return res.status(400).json({ error: error.message });
        }
    }

    /**
     * DELETE /coaching/:id/invitations/:invitationId
     * Cancel/revoke a pending invitation (admin action).
     */
    async cancelInvitation(req: Request, res: Response) {
        try {
            const coachingId = req.params.id as string;
            const invitationId = req.params.invitationId as string;

            const result = await invitationService.cancelInvitation(invitationId, coachingId);
            return res.json(result);
        } catch (error: any) {
            return res.status(400).json({ error: error.message });
        }
    }
}
