import { z } from 'zod';

// ─── Shared Enums & Validators ──────────────────────────────────────

const VALID_CYCLES = ['ONCE', 'MONTHLY', 'QUARTERLY', 'HALF_YEARLY', 'YEARLY', 'CUSTOM', 'INSTALLMENT'] as const;
const VALID_TAX_TYPES = ['NONE', 'GST_INCLUSIVE', 'GST_EXCLUSIVE'] as const;
const VALID_SUPPLY_TYPES = ['INTRA_STATE', 'INTER_STATE'] as const;
const VALID_GST_RATES = [0, 5, 12, 18, 28] as const;
const VALID_PAYMENT_MODES = ['CASH', 'ONLINE', 'UPI', 'BANK_TRANSFER', 'CHEQUE', 'OTHER', 'RAZORPAY'] as const;
const VALID_REFUND_MODES = ['CASH', 'BANK_TRANSFER', 'ONLINE', 'RAZORPAY'] as const;
const VALID_FEE_STATUSES = ['PENDING', 'PAID', 'PARTIALLY_PAID', 'WAIVED', 'OVERDUE'] as const;

const positiveNumber = z.number().positive('Must be a positive number');
const nonNegativeNumber = z.number().min(0, 'Must be non-negative');
const uuidString = z.string().uuid('Must be a valid UUID');
const isoDateString = z.string().refine(
    (val) => !isNaN(Date.parse(val)),
    { message: 'Must be a valid ISO date string' },
);
const futureDateGuard = z.string().refine(
    (val) => {
        const d = new Date(val);
        // Allow up to 1 hour in the future to handle timezone differences
        return !isNaN(d.getTime()) && d.getTime() <= Date.now() + 3600_000;
    },
    { message: 'Date cannot be in the future' },
);

// ─── Fee Structure Schemas ──────────────────────────────────────────

const lineItemSchema = z.object({
    label: z.string().min(1).max(200),
    amount: nonNegativeNumber,
});

const installmentPlanItemSchema = z.object({
    label: z.string().min(1).max(200),
    dueDay: z.number().int().min(1).max(31),
    amount: positiveNumber,
});

const installmentAmountItemSchema = z.object({
    label: z.string().min(1).max(200),
    amount: z.number().positive(),
});

export const createFeeStructureSchema = z.object({
    name: z.string().min(1, 'Name is required').max(200),
    description: z.string().max(1000).optional(),
    amount: positiveNumber,
    cycle: z.enum(VALID_CYCLES).default('MONTHLY'),
    lateFinePerDay: nonNegativeNumber.default(0),
    discounts: z.any().optional(),
    installmentPlan: z.array(installmentPlanItemSchema).optional(),
    taxType: z.enum(VALID_TAX_TYPES).default('NONE'),
    gstRate: z.number().refine((v) => (VALID_GST_RATES as readonly number[]).includes(v), {
        message: `GST rate must be one of: ${VALID_GST_RATES.join(', ')}`,
    }).default(0),
    sacCode: z.string().max(20).optional(),
    hsnCode: z.string().max(20).optional(),
    gstSupplyType: z.enum(VALID_SUPPLY_TYPES).default('INTRA_STATE'),
    cessRate: nonNegativeNumber.max(50).default(0),
    lineItems: z.array(lineItemSchema).optional(),
    // installment control
    allowInstallments: z.boolean().default(false),
    installmentCount: z.number().int().min(0).default(0),
    installmentAmounts: z.array(installmentAmountItemSchema).optional(),
}).refine((data) => {
    // If cycle is INSTALLMENT, installmentPlan must be provided
    if (data.cycle === 'INSTALLMENT') {
        if (!data.installmentPlan || data.installmentPlan.length === 0) {
            return false;
        }
    }
    return true;
}, { message: 'Installment plan is required when cycle is INSTALLMENT' })
    .refine((data) => {
        // Installment plan amounts should sum to total amount (with 1% tolerance)
        if (data.cycle === 'INSTALLMENT' && data.installmentPlan) {
            const planTotal = data.installmentPlan.reduce((s, item) => s + item.amount, 0);
            const tolerance = data.amount * 0.01;
            return Math.abs(planTotal - data.amount) <= tolerance;
        }
        return true;
    }, { message: 'Installment plan amounts must sum to the total fee amount' });

export const updateFeeStructureSchema = z.object({
    name: z.string().min(1).max(200).optional(),
    description: z.string().max(1000).nullable().optional(),
    amount: positiveNumber.optional(),
    cycle: z.enum(VALID_CYCLES).optional(),
    lateFinePerDay: nonNegativeNumber.optional(),
    isActive: z.boolean().optional(),
    discounts: z.any().optional(),
    installmentPlan: z.any().optional(),
    taxType: z.enum(VALID_TAX_TYPES).optional(),
    gstRate: z.number().refine((v) => (VALID_GST_RATES as readonly number[]).includes(v), {
        message: `GST rate must be one of: ${VALID_GST_RATES.join(', ')}`,
    }).optional(),
    sacCode: z.string().max(20).nullable().optional(),
    hsnCode: z.string().max(20).nullable().optional(),
    gstSupplyType: z.enum(VALID_SUPPLY_TYPES).optional(),
    cessRate: nonNegativeNumber.max(50).optional(),
    lineItems: z.array(lineItemSchema).nullable().optional(),
    // installment control
    allowInstallments: z.boolean().optional(),
    installmentCount: z.number().int().min(0).optional(),
    installmentAmounts: z.array(installmentAmountItemSchema).nullable().optional(),
});

// ─── Fee Assignment Schema ──────────────────────────────────────────

export const assignFeeSchema = z.object({
    memberId: uuidString,
    feeStructureId: uuidString,
    customAmount: positiveNumber.optional(),
    discountAmount: nonNegativeNumber.optional(),
    discountReason: z.string().max(500).optional(),
    scholarshipTag: z.string().max(100).optional(),
    scholarshipAmount: nonNegativeNumber.optional(),
    startDate: isoDateString.optional(),
    endDate: isoDateString.optional(),
}).refine((data) => {
    // Discount cannot exceed amount (we check in service against structure amount too)
    if (data.customAmount !== undefined && data.discountAmount !== undefined) {
        const total = (data.discountAmount ?? 0) + (data.scholarshipAmount ?? 0);
        if (total > data.customAmount) return false;
    }
    return true;
}, { message: 'Total discount + scholarship cannot exceed the fee amount' });

// ─── Payment Schema ─────────────────────────────────────────────────

export const recordPaymentSchema = z.object({
    amount: positiveNumber,
    mode: z.enum(VALID_PAYMENT_MODES),
    transactionRef: z.string().max(200).optional(),
    notes: z.string().max(1000).optional(),
    paidAt: futureDateGuard.optional(),
});

// ─── Waive Schema ───────────────────────────────────────────────────

export const waiveFeeSchema = z.object({
    notes: z.string().max(1000).optional(),
});

// ─── Refund Schema ──────────────────────────────────────────────────

export const recordRefundSchema = z.object({
    amount: positiveNumber,
    reason: z.string().max(1000).optional(),
    mode: z.enum(VALID_REFUND_MODES).default('CASH'),
    refundedAt: futureDateGuard.optional(),
});

// ─── Bulk Remind Schema ─────────────────────────────────────────────

export const bulkRemindSchema = z.object({
    statusFilter: z.enum(VALID_FEE_STATUSES).default('OVERDUE'),
    memberIds: z.array(uuidString).optional(),
});

// ─── Online Payment Schemas ─────────────────────────────────────────

export const createOrderSchema = z.object({
    recordId: uuidString.optional(),
    amount: positiveNumber.optional(),
});

export const verifyPaymentSchema = z.object({
    razorpay_order_id: z.string().regex(/^order_[A-Za-z0-9]{14,}$/, 'Invalid Razorpay order ID format'),
    razorpay_payment_id: z.string().regex(/^pay_[A-Za-z0-9]{14,}$/, 'Invalid Razorpay payment ID format'),
    razorpay_signature: z.string().regex(/^[a-f0-9]{64}$/, 'Invalid signature format'),
});

export const initiateRefundSchema = z.object({
    paymentId: uuidString,
    amount: positiveNumber.optional(),
    reason: z.string().max(1000).optional(),
});

export const multiPayCreateOrderSchema = z.object({
    recordIds: z.array(uuidString).min(1, 'At least one record required').max(20, 'Cannot pay for more than 20 records at once'),
});

export const failOrderSchema = z.object({
    reason: z.string().max(1000).default('User cancelled'),
});

// ─── Pagination Schema ─────────────────────────────────────────────

export const paginationSchema = z.object({
    page: z.coerce.number().int().positive().default(1),
    limit: z.coerce.number().int().positive().max(100).default(30),
});

// ─── Financial Year Schema ──────────────────────────────────────────

export const financialYearSchema = z.string().regex(
    /^\d{4}-\d{2}$/,
    'Financial year must be in format YYYY-YY (e.g., 2025-26)',
);

// ─── Payment Settings Schema ────────────────────────────────────────

export const paymentSettingsSchema = z.object({
    gstNumber: z.string().regex(/^\d{2}[A-Z]{5}\d{4}[A-Z]\d[A-Z\d][A-Z]\d$/, 'Invalid GSTIN format').or(z.literal('')).optional(),
    panNumber: z.string().regex(/^[A-Z]{5}\d{4}[A-Z]$/, 'Invalid PAN format').or(z.literal('')).optional(),
    contactPhone: z.string().regex(/^[6-9]\d{9}$/, 'Invalid Indian phone number').or(z.literal('')).optional(),
    bankAccountName: z.string().max(200).optional(),
    bankAccountNumber: z.string().min(8).max(20).regex(/^\d+$/, 'Account number must contain only digits').optional().or(z.literal('')),
    bankIfscCode: z.string().regex(/^[A-Z]{4}0[A-Z0-9]{6}$/, 'Invalid IFSC format').or(z.literal('')).optional(),
    bankName: z.string().max(200).optional(),
});

export const createLinkedAccountSchema = z.object({
    ownerName: z.string().min(2).max(200),
    ownerEmail: z.string().email(),
    ownerPhone: z.string().regex(/^[6-9]\d{9}$/, 'Invalid Indian phone number (10 digits starting with 6-9)'),
    businessType: z.enum(['individual', 'partnership', 'proprietorship', 'private_limited', 'public_limited', 'trust', 'society', 'ngo']).optional(),
});

// ─── Audit Log Schema ───────────────────────────────────────────────

export const listAuditLogSchema = z.object({
    entityType: z.string().optional(),
    entityId: z.string().optional(),
    event: z.string().optional(),
    from: isoDateString.optional(),
    to: isoDateString.optional(),
    page: z.coerce.number().int().positive().default(1),
    limit: z.coerce.number().int().positive().max(100).default(50),
});

// ─── Validate Helper ────────────────────────────────────────────────

/**
 * Validate a request body against a Zod schema.
 * Throws a proper HTTP error with field-level details on failure.
 */
export function validateBody<T>(schema: z.ZodSchema<T>, body: unknown): T {
    const result = schema.safeParse(body);
    if (!result.success) {
        const fieldErrors = result.error.issues.map((e: z.ZodIssue) => ({
            path: e.path.join('.'),
            message: e.message,
        }));
        const error = Object.assign(
            new Error(`Validation failed: ${fieldErrors.map((e: { path: string; message: string }) => `${e.path}: ${e.message}`).join('; ')}`),
            { status: 400, fieldErrors },
        );
        throw error;
    }
    return result.data;
}
