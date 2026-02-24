import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Product ID for premium upgrade - must match Play Console
const String kPremiumProductId = 'premium_upgrade';

/// Purchase error types for better error handling
enum PurchaseErrorType {
  storeUnavailable,
  productNotFound,
  paymentDeclined,
  paymentCancelled,
  networkError,
  alreadyOwned,
  unknown,
}

/// Purchase result with detailed info
class PurchaseResult {
  final bool success;
  final PurchaseErrorType? errorType;
  final String? errorMessage;

  const PurchaseResult({
    required this.success,
    this.errorType,
    this.errorMessage,
  });

  factory PurchaseResult.success() => const PurchaseResult(success: true);

  factory PurchaseResult.error(PurchaseErrorType type, [String? message]) =>
      PurchaseResult(
        success: false,
        errorType: type,
        errorMessage: message ?? _defaultErrorMessage(type),
      );

  static String _defaultErrorMessage(PurchaseErrorType type) {
    switch (type) {
      case PurchaseErrorType.storeUnavailable:
        return 'Store is not available. Please try again later.';
      case PurchaseErrorType.productNotFound:
        return 'Product not found. Please try again later.';
      case PurchaseErrorType.paymentDeclined:
        return 'Payment was declined. Please check your payment method.';
      case PurchaseErrorType.paymentCancelled:
        return 'Purchase was cancelled.';
      case PurchaseErrorType.networkError:
        return 'No internet connection. Please check your connection and try again.';
      case PurchaseErrorType.alreadyOwned:
        return 'You already own this product. Try restoring purchases.';
      case PurchaseErrorType.unknown:
        return 'Something went wrong. Please try again.';
    }
  }
}

/// Service for handling in-app purchases
class PurchaseService {
  static final PurchaseService _instance = PurchaseService._internal();
  factory PurchaseService() => _instance;
  PurchaseService._internal();

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;

  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _purchasePending = false;
  bool _isInitialized = false;

  // Callbacks
  Function(bool success)? onPurchaseComplete;
  Function()? onPurchaseRefunded;

  // Completer for awaiting purchase result
  Completer<PurchaseResult>? _purchaseCompleter;

  // Prefs keys
  static const String _keyPurchaseDate = 'premium_purchase_date';
  static const String _keyPurchaseToken = 'premium_purchase_token';

  /// Initialize the purchase service
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    _isAvailable = await _iap.isAvailable();

    if (!_isAvailable) {
      if (kDebugMode) print('In-app purchases not available');
      return;
    }

    // Listen for purchase updates
    _subscription = _iap.purchaseStream.listen(
      _handlePurchaseUpdate,
      onDone: () => _subscription?.cancel(),
      onError: (error) {
        if (kDebugMode) print('Purchase stream error: $error');
      },
    );

    // Load products
    await _loadProducts();

    // Check for refunds on existing purchases
    await _checkForRefunds();
  }

  /// Load available products from store
  Future<void> _loadProducts() async {
    final response = await _iap.queryProductDetails({kPremiumProductId});

    if (response.error != null) {
      if (kDebugMode) print('Error loading products: ${response.error}');
      return;
    }

    if (response.notFoundIDs.isNotEmpty) {
      if (kDebugMode) print('Products not found: ${response.notFoundIDs}');
    }

    _products = response.productDetails;
    if (kDebugMode) print('Loaded ${_products.length} products');
  }

  /// Check for refunds by verifying past purchases
  Future<void> _checkForRefunds() async {
    final prefs = await SharedPreferences.getInstance();
    final purchaseToken = prefs.getString(_keyPurchaseToken);
    final isPremium = prefs.getBool('is_premium') ?? false;

    // If user has premium but we have a stored token, verify it's still valid
    if (isPremium && purchaseToken != null) {
      // Restore purchases to check if still valid
      try {
        await _iap.restorePurchases();
        // The restore will trigger _handlePurchaseUpdate
        // If the purchase is no longer valid (refunded), it won't appear in restored purchases
      } catch (e) {
        if (kDebugMode) print('Error checking for refunds: $e');
      }
    }
  }

  /// Handle purchase updates
  void _handlePurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) async {
    final prefs = await SharedPreferences.getInstance();
    bool foundValidPurchase = false;

    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else if (purchase.status == PurchaseStatus.canceled) {
        // User cancelled the purchase
        if (kDebugMode) print('Purchase cancelled by user');
        _purchaseCompleter?.complete(
            PurchaseResult.error(PurchaseErrorType.paymentCancelled));
        _purchaseCompleter = null;
        onPurchaseComplete?.call(false);
        _purchasePending = false;
      } else {
        if (purchase.status == PurchaseStatus.error) {
          if (kDebugMode) print('Purchase error: ${purchase.error}');
          _purchaseCompleter?.complete(
              PurchaseResult.error(PurchaseErrorType.unknown, purchase.error?.message));
          _purchaseCompleter = null;
          onPurchaseComplete?.call(false);
        } else if (purchase.status == PurchaseStatus.purchased ||
            purchase.status == PurchaseStatus.restored) {
          if (purchase.productID == kPremiumProductId) {
            foundValidPurchase = true;
            await _verifyAndDeliverProduct(purchase);
            _purchaseCompleter?.complete(PurchaseResult.success());
            _purchaseCompleter = null;
          }
        }

        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
        _purchasePending = false;
      }
    }

    // Check for refund: if user had premium, we did a restore, and no valid purchase found
    final isPremium = prefs.getBool('is_premium') ?? false;
    final purchaseToken = prefs.getString(_keyPurchaseToken);

    if (isPremium && purchaseToken != null && !foundValidPurchase && purchaseDetailsList.isNotEmpty) {
      // Purchase was refunded
      await _handleRefund();
    }
  }

  /// Handle refund - revoke premium
  Future<void> _handleRefund() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_premium', false);
    await prefs.remove(_keyPurchaseDate);
    await prefs.remove(_keyPurchaseToken);

    if (kDebugMode) print('Purchase refunded - premium revoked');
    onPurchaseRefunded?.call();
  }

  /// Verify purchase and deliver premium
  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchase) async {
    if (purchase.productID == kPremiumProductId) {
      final prefs = await SharedPreferences.getInstance();

      // Store purchase info
      await prefs.setBool('is_premium', true);
      await prefs.setString(_keyPurchaseDate, DateTime.now().toIso8601String());

      // Store purchase token for refund detection
      if (purchase.verificationData.serverVerificationData.isNotEmpty) {
        await prefs.setString(
            _keyPurchaseToken, purchase.verificationData.serverVerificationData);
      }

      if (kDebugMode) print('Premium unlocked via purchase!');
      onPurchaseComplete?.call(true);
    }
  }

  /// Get the premium product details
  ProductDetails? get premiumProduct {
    try {
      return _products.firstWhere((p) => p.id == kPremiumProductId);
    } catch (e) {
      return null;
    }
  }

  /// Get the price string for display
  String get premiumPrice {
    return premiumProduct?.price ?? '\$4.99';
  }

  /// Get raw price in micros (for comparison with original price)
  int get premiumPriceMicros {
    return premiumProduct?.rawPrice.toInt() ?? 499;
  }

  /// Check if product is on sale (has promotional pricing)
  bool get isOnSale {
    // Google Play promotional pricing would show a different price
    // You can compare against a known original price
    // For now, we'll use a simple check - override this with your logic
    return false;
  }

  /// Get original price if on sale (for strikethrough display)
  String? get originalPrice {
    if (!isOnSale) return null;
    // Return the original price string
    // This would need to be set based on your promotional pricing
    return null;
  }

  /// Check if store is available
  bool get isAvailable => _isAvailable;

  /// Check if purchase is pending
  bool get isPurchasePending => _purchasePending;

  /// Debug info for troubleshooting
  String get debugInfo {
    final buffer = StringBuffer();
    buffer.writeln('Store Available: $_isAvailable');
    buffer.writeln('Initialized: $_isInitialized');
    buffer.writeln('Products loaded: ${_products.length}');
    if (_products.isNotEmpty) {
      for (final p in _products) {
        buffer.writeln('  - ${p.id}: ${p.price}');
      }
    }
    buffer.writeln('Premium product found: ${premiumProduct != null}');
    buffer.writeln('Queried ID: $kPremiumProductId');
    return buffer.toString();
  }

  /// Get purchase date if available
  Future<DateTime?> getPurchaseDate() async {
    final prefs = await SharedPreferences.getInstance();
    final dateStr = prefs.getString(_keyPurchaseDate);
    if (dateStr == null) return null;
    try {
      return DateTime.parse(dateStr);
    } catch (e) {
      return null;
    }
  }

  /// Check if device is online
  Future<bool> _isOnline() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return result != ConnectivityResult.none;
    } catch (e) {
      return true; // Assume online if check fails
    }
  }

  /// Purchase premium with detailed result
  Future<PurchaseResult> purchasePremiumWithResult() async {
    // Check connectivity first
    if (!await _isOnline()) {
      return PurchaseResult.error(PurchaseErrorType.networkError);
    }

    if (!_isAvailable) {
      return PurchaseResult.error(PurchaseErrorType.storeUnavailable);
    }

    final product = premiumProduct;
    if (product == null) {
      return PurchaseResult.error(PurchaseErrorType.productNotFound);
    }

    final purchaseParam = PurchaseParam(productDetails: product);

    // Create a completer to await the actual purchase result from the stream
    _purchaseCompleter = Completer<PurchaseResult>();

    try {
      final started = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      if (!started) {
        _purchaseCompleter = null;
        return PurchaseResult.error(PurchaseErrorType.unknown, 'Failed to start purchase');
      }

      // Wait for the purchase stream to complete (success, cancel, or error)
      // Timeout after 5 minutes in case something goes wrong
      final result = await _purchaseCompleter!.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          _purchaseCompleter = null;
          return PurchaseResult.error(PurchaseErrorType.unknown, 'Purchase timed out');
        },
      );
      return result;
    } catch (e) {
      _purchaseCompleter = null;
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('already owned') || errorStr.contains('already purchased')) {
        return PurchaseResult.error(PurchaseErrorType.alreadyOwned);
      } else if (errorStr.contains('cancelled') || errorStr.contains('canceled')) {
        return PurchaseResult.error(PurchaseErrorType.paymentCancelled);
      } else if (errorStr.contains('declined') || errorStr.contains('failed')) {
        return PurchaseResult.error(PurchaseErrorType.paymentDeclined);
      }
      return PurchaseResult.error(PurchaseErrorType.unknown, e.toString());
    }
  }

  /// Purchase premium (simple bool return for backwards compatibility)
  Future<bool> purchasePremium() async {
    final result = await purchasePremiumWithResult();
    return result.success;
  }

  /// Restore previous purchases
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;
    await _iap.restorePurchases();
  }

  /// Dispose the service
  void dispose() {
    _subscription?.cancel();
  }
}
