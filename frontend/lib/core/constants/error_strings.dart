/// Single source of truth for every user-facing error and success message.
///
/// **Rules:**
///  1. No hardcoded error/success strings anywhere outside this file.
///  2. Use the domain-specific sub-class that matches your feature.
///  3. To change any message, edit it here — every screen updates instantly.
library;

// ═══════════════════════════════════════════════════════════════════════
// Generic / Network
// ═══════════════════════════════════════════════════════════════════════

abstract final class Errors {
  // ── Catchall ──
  static const fallback = 'Something went wrong. Please try again.';
  static const timeout = 'Request timed out. Check your connection.';
  static const offline = 'You appear to be offline. Check your internet.';
  static const serverDown =
      'Server is unreachable. Please try again in a moment.';
  static const unauthorized = 'Session expired. Please sign in again.';
  static const forbidden = 'You don\'t have permission to do that.';
  static const notFound = 'The resource you requested was not found.';
  static const tooManyRequests = 'Too many requests. Please wait a moment.';
  static const serverError = 'Server error. We\'re looking into it.';
  static const loadFailed = 'Failed to load data. Pull down to retry.';
  static const saveFailed = 'Failed to save. Please try again.';
  static const deleteFailed = 'Failed to delete. Please try again.';
  static const uploadFailed = 'Upload failed. Please try again.';
  static const locationFailed = 'Could not determine your location.';
  static const openMapFailed = 'Could not open maps.';
  static const openFileFailed = 'Could not open the file.';
  static const noAppForFile = 'No app found to open this file type.';
  static const clipboardCopied = 'Copied to clipboard';
}

// ═══════════════════════════════════════════════════════════════════════
// Auth
// ═══════════════════════════════════════════════════════════════════════

abstract final class AuthErrors {
  static const signInFailed = 'Sign-in failed. Please try again.';
  static const signOutFailed = 'Sign-out failed. Please try again.';
  static const sessionExpired = 'Session expired. Please sign in again.';
}

// ═══════════════════════════════════════════════════════════════════════
// Coaching
// ═══════════════════════════════════════════════════════════════════════

abstract final class CoachingErrors {
  static const loadFailed = 'Failed to load coachings.';
  static const createFailed = 'Failed to create coaching.';
  static const updateFailed = 'Failed to update coaching.';
  static const saveDetailsFailed = 'Failed to save details.';
  static const saveAddressFailed = 'Failed to save address.';
  static const setupFailed = 'Failed to complete setup.';
  static const addBranchFailed = 'Failed to add branch.';
  static const uploadFailed = 'Failed to upload image.';
}

abstract final class CoachingSuccess {
  static const created = 'Coaching created successfully';
  static const updated = 'Updated successfully';
  static const avatarUpdated = 'Avatar updated successfully';
  static const coverUpdated = 'Cover updated successfully';
}

// ═══════════════════════════════════════════════════════════════════════
// Members / Invitations
// ═══════════════════════════════════════════════════════════════════════

abstract final class MemberErrors {
  static const loadFailed = 'Failed to load members.';
  static const removeFailed = 'Failed to remove member.';
  static const inviteFailed = 'Failed to send invitation.';
  static const cancelFailed = 'Failed to cancel invitation.';
  static const acceptFailed = 'Failed to accept invitation.';
  static const declineFailed = 'Failed to decline invitation.';
}

abstract final class MemberSuccess {
  static const removed = 'Member removed';
  static const invited = 'Invitation sent successfully';
  static const inviteCancelled = 'Invitation cancelled';
  static const accepted = 'Accepted!';
  static const declined = 'Declined.';
}

// ═══════════════════════════════════════════════════════════════════════
// Batch
// ═══════════════════════════════════════════════════════════════════════

abstract final class BatchErrors {
  static const loadFailed = 'Failed to load batches.';
  static const detailLoadFailed = 'Failed to load batch details.';
  static const saveFailed = 'Failed to save batch.';
  static const deleteFailed = 'Failed to delete batch.';
  static const statusFailed = 'Failed to update status.';
  static const removeMemberFailed = 'Failed to remove member.';
  static const addMemberFailed = 'Failed to add members.';
  static const deleteNoteFailed = 'Failed to delete note.';
  static const deleteNoticeFailed = 'Failed to delete notice.';
  static const loadMembersFailed = 'Failed to load members.';
}

abstract final class BatchSuccess {
  static const saved = 'Batch saved successfully';
  static const deleted = 'Batch deleted';
  static const membersAdded = 'Members added successfully';
  static const statusUpdated = 'Status updated';
}

// ═══════════════════════════════════════════════════════════════════════
// Notes / Notices
// ═══════════════════════════════════════════════════════════════════════

abstract final class NoteErrors {
  static const loadStorageFailed = 'Failed to load storage usage.';
  static const saveFailed = 'Failed to save note.';
  static const createNoticeFailed = 'Failed to create notice.';
}

abstract final class NoteSuccess {
  static const saved = 'Note shared successfully';
  static const noticeCreated = 'Notice created successfully';
}

// ═══════════════════════════════════════════════════════════════════════
// Fee
// ═══════════════════════════════════════════════════════════════════════

abstract final class FeeErrors {
  static const loadFailed = 'Failed to load fee data.';
  static const recordsLoadFailed = 'Failed to load fee records.';
  static const calendarLoadFailed = 'Failed to load fee calendar.';
  static const structureLoadFailed = 'Failed to load fee structures.';
  static const assignFailed = 'Failed to assign fee.';
  static const saveFailed = 'Failed to save fee.';
  static const deleteFailed = 'Failed to delete fee.';
  static const paymentFailed = 'Payment failed. Please try again.';
  static const refundFailed = 'Refund failed. Please try again.';
  static const recordPaymentFailed = 'Failed to record payment.';
  static const invalidAmount = 'Enter a valid amount.';
  static const selectStudent = 'Select at least one student.';
  static const nameAmountRequired = 'Name and a valid amount are required.';
  static const structureSaveFailed = 'Failed to save fee structure.';
  static const structureDeleteFailed = 'Failed to delete fee structure.';
  static const reminderFailed = 'Failed to send reminders.';
  static const auditLogFailed = 'Failed to load audit logs.';
  static const ledgerFailed = 'Failed to load ledger.';
  static const reportFailed = 'Failed to load report.';
  static const profileFailed = 'Failed to load profile.';
  static const cancelOrderFailed = 'Failed to cancel order.';
  static const disputeFailed = 'Failed to load dispute details.';
}

abstract final class FeeSuccess {
  static const assigned = 'Fee assigned successfully';
  static const assignedPartial = 'Fee assigned to some students. Some failed.';
  static const paid = 'Payment successful!';
  static const allPaid = 'Payment successful! All fees have been paid.';
  static const refunded = 'Refund processed successfully';
  static const recorded = 'Payment recorded successfully';
  static const deleted = 'Fee deleted';
  static const structureSaved = 'Fee structure saved';
  static const structureDeleted = 'Fee structure deleted';
  static const reminderSent = 'Reminders sent successfully';
  static const receiptCopied = 'Receipt copied to clipboard';
  static const orderCancelled = 'Order cancelled';
  static const waived = 'Fee waived successfully';
  static const amountUpdated = 'Amount updated successfully';
}

// ═══════════════════════════════════════════════════════════════════════
// Payment Settings
// ═══════════════════════════════════════════════════════════════════════

abstract final class PaymentErrors {
  static const loadFailed = 'Failed to load payment settings.';
  static const saveFailed = 'Failed to save settings.';
  static const verifyBankFailed = 'Bank verification failed.';
  static const linkAccountFailed = 'Failed to link Razorpay account.';
  static const removeAccountFailed = 'Failed to remove linked account.';
  static const refreshFailed = 'Failed to refresh account status.';
}

abstract final class PaymentSuccess {
  static const saved = 'Payment settings saved';
  static const bankVerified = 'Bank account verified';
  static const accountLinked = 'Razorpay account linked';
  static const accountRemoved = 'Linked account removed';
  static const accountRefreshed = 'Account status refreshed';
}

// ═══════════════════════════════════════════════════════════════════════
// Assessment
// ═══════════════════════════════════════════════════════════════════════

abstract final class AssessmentErrors {
  static const loadFailed = 'Failed to load assessment.';
  static const loadResultFailed = 'Failed to load results.';
  static const loadResponseFailed = 'Failed to load response.';
  static const createFailed = 'Failed to create assessment.';
  static const submitFailed = 'Failed to submit assessment.';
  static const gradeFailed = 'Grading failed. Please try again.';
  static const selectFile = 'Select at least one file.';
  static const emptyQuestion = 'Question text cannot be empty.';
  static const addQuestion = 'Add at least one question.';
  static const invalidMarks = 'Enter valid marks.';
  static const assignmentSubmitFailed = 'Failed to submit assignment.';
  static const submissionsLoadFailed = 'Failed to load submissions.';
}

abstract final class AssessmentSuccess {
  static const created = 'Assessment created successfully';
  static const submitted = 'Submitted successfully!';
  static const assignmentSubmitted = 'Assignment submitted successfully!';
  static const graded = 'Graded successfully';
}

// ═══════════════════════════════════════════════════════════════════════
// Profile / Settings
// ═══════════════════════════════════════════════════════════════════════

abstract final class ProfileErrors {
  static const updateFailed = 'Failed to update profile.';
  static const avatarUpdateFailed = 'Failed to update avatar.';
  static const avatarRemoveFailed = 'Failed to remove avatar.';
  static const privacyFailed = 'Failed to update privacy settings.';
  static const loadSessionsFailed = 'Failed to load sessions.';
  static const saveFailed = 'Failed to save profile.';
}

abstract final class ProfileSuccess {
  static const updated = 'Profile updated successfully';
  static const avatarUpdated = 'Profile picture updated';
  static const avatarRemoved = 'Profile picture removed';
  static const cacheCleared = 'Cache cleared';
  static const dataDeleted = 'All local data deleted';
}

// ═══════════════════════════════════════════════════════════════════════
// Notifications
// ═══════════════════════════════════════════════════════════════════════

abstract final class NotifyErrors {
  static const loadFailed = 'Failed to load notifications.';
  static const archiveFailed = 'Failed to archive notification.';
  static const removeMemberFailed = 'Failed to remove member.';
}

abstract final class NotifySuccess {
  static const dismissed = 'Notification dismissed';
}

// ═══════════════════════════════════════════════════════════════════════
// Explore
// ═══════════════════════════════════════════════════════════════════════

abstract final class ExploreErrors {
  static const loadFailed = 'Failed to load nearby coachings.';
  static const searchFailed = 'Search failed. Please try again.';
  static const detailsFailed = 'Could not load coaching details.';
}

// ═══════════════════════════════════════════════════════════════════════
// Academic
// ═══════════════════════════════════════════════════════════════════════

abstract final class AcademicErrors {
  static const loadFailed = 'Failed to load academic data.';
  static const saveFailed = 'Failed to save academic profile.';
}

abstract final class AcademicSuccess {
  static const saved = 'Academic profile saved';
}
