import type { Request, Response } from 'express';
import { AuthService } from './auth.service.js';

const authService = new AuthService();

export class AuthController {
    async googleLogin(req: Request, res: Response) {
        try {
            const { idToken, deviceInfo } = req.body;

            if (!idToken) {
                return res.status(400).json({ message: 'ID Token is required' });
            }

            const forwarded = req.headers['x-forwarded-for'];
            const ip = typeof forwarded === 'string'
                ? forwarded.split(',')[0]
                : req.ip;

            const sessionInfo = {
                ip,
                userAgent: deviceInfo || (req.headers['x-device-info'] as string) || req.headers['user-agent'],
            };

            console.log('Login attempt data:', {
                'ip': ip,
                'deviceInfoFromBody': deviceInfo,
                'x-device-info': req.headers['x-device-info'],
                'user-agent': req.headers['user-agent']
            });

            const userData = await authService.verifyGoogleToken(idToken, sessionInfo);

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
