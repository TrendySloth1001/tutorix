import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../services/payment_service.dart';

/// Admin screen for configuring coaching payment settings:
/// bank account, GSTIN, PAN — required for Razorpay Route transfers.
class PaymentSettingsScreen extends StatefulWidget {
  final String coachingId;
  const PaymentSettingsScreen({super.key, required this.coachingId});

  @override
  State<PaymentSettingsScreen> createState() => _PaymentSettingsScreenState();
}

class _PaymentSettingsScreenState extends State<PaymentSettingsScreen> {
  final _svc = PaymentService();
  final _formKey = GlobalKey<FormState>();

  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _bankNameCtrl = TextEditingController();
  final _accNameCtrl = TextEditingController();
  final _accNumCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  String? _razorpayAccountId;
  bool _razorpayActivated = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _bankNameCtrl.dispose();
    _accNameCtrl.dispose();
    _accNumCtrl.dispose();
    _ifscCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _svc.getPaymentSettings(widget.coachingId);
      setState(() {
        _gstCtrl.text = data['gstNumber'] as String? ?? '';
        _panCtrl.text = data['panNumber'] as String? ?? '';
        _bankNameCtrl.text = data['bankName'] as String? ?? '';
        _accNameCtrl.text = data['bankAccountName'] as String? ?? '';
        _accNumCtrl.text = data['bankAccountNumber'] as String? ?? '';
        _ifscCtrl.text = data['bankIfscCode'] as String? ?? '';
        _razorpayAccountId = data['razorpayAccountId'] as String?;
        _razorpayActivated = data['razorpayActivated'] as bool? ?? false;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _svc.updatePaymentSettings(
        widget.coachingId,
        gstNumber: _gstCtrl.text.trim().isEmpty ? null : _gstCtrl.text.trim(),
        panNumber: _panCtrl.text.trim().isEmpty ? null : _panCtrl.text.trim(),
        bankName: _bankNameCtrl.text.trim().isEmpty
            ? null
            : _bankNameCtrl.text.trim(),
        bankAccountName: _accNameCtrl.text.trim().isEmpty
            ? null
            : _accNameCtrl.text.trim(),
        bankAccountNumber: _accNumCtrl.text.trim().isEmpty
            ? null
            : _accNumCtrl.text.trim(),
        bankIfscCode: _ifscCtrl.text.trim().isEmpty
            ? null
            : _ifscCtrl.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Payment settings saved')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: const Color(0xFFC62828),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F6F2),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF7F6F2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.darkOlive,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Payment Settings',
          style: TextStyle(
            color: AppColors.darkOlive,
            fontWeight: FontWeight.w700,
            fontSize: 17,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _load, child: const Text('Retry')),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Razorpay Status ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _razorpayActivated
                            ? const Color(0xFFE8F5E9)
                            : const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _razorpayActivated
                                ? Icons.check_circle_rounded
                                : Icons.info_outline_rounded,
                            color: _razorpayActivated
                                ? const Color(0xFF2E7D32)
                                : const Color(0xFFE65100),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _razorpayActivated
                                      ? 'Razorpay Route Active'
                                      : 'Razorpay Route Not Configured',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: _razorpayActivated
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFE65100),
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  _razorpayActivated
                                      ? 'Payments will be routed to your bank account'
                                      : 'Contact Tutorix support to link your Razorpay account',
                                  style: TextStyle(
                                    color: _razorpayActivated
                                        ? const Color(0xFF2E7D32)
                                        : const Color(0xFFE65100),
                                    fontSize: 12,
                                  ),
                                ),
                                if (_razorpayAccountId != null)
                                  Text(
                                    'Account: $_razorpayAccountId',
                                    style: const TextStyle(
                                      color: AppColors.mutedOlive,
                                      fontSize: 11,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ── Tax Details ──
                    const SizedBox(height: 24),
                    const Text(
                      'Tax Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkOlive,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _gstCtrl,
                      decoration: const InputDecoration(
                        labelText: 'GSTIN',
                        hintText: 'e.g. 27AADCB2230M1ZT',
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _panCtrl,
                      decoration: const InputDecoration(
                        labelText: 'PAN Number',
                        hintText: 'e.g. AADCB2230M',
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),

                    // ── Bank Details ──
                    const SizedBox(height: 24),
                    const Text(
                      'Bank Account Details',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColors.darkOlive,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Required for receiving payments via Razorpay Route',
                      style: TextStyle(
                        color: AppColors.mutedOlive,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Account Holder Name',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _accNumCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Account Number',
                      ),
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _ifscCtrl,
                      decoration: const InputDecoration(
                        labelText: 'IFSC Code',
                        hintText: 'e.g. SBIN0001234',
                      ),
                      textCapitalization: TextCapitalization.characters,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _bankNameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Bank Name',
                        hintText: 'e.g. State Bank of India',
                      ),
                    ),

                    // ── Save Button ──
                    const SizedBox(height: 32),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: FilledButton(
                        onPressed: _saving ? null : _save,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.darkOlive,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  color: AppColors.cream,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Save Settings',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }
}
