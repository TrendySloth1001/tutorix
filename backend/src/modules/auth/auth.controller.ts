import type { Request, Response } from 'express';
import { AuthService } from './auth.service.js';

const authService = new AuthService();

export class AuthController {
    async googleLogin(req: Request, res: Response) {
        try {
            const { idToken } = req.body;

            if (!idToken) {
                return res.status(400).json({ message: 'ID Token is required' });
            }

            const userData = await authService.verifyGoogleToken(idToken);

            // Here you would typically find or create the user in your database
            // For now, we'll just return a success message and a mock user

            const token = authService.generateToken(userData);

            res.status(200).json({
                message: 'Login successful',
                token,
                user: userData,
            });
        } catch (error: any) {
            res.status(401).json({ message: error.message });
        }
    }
}
