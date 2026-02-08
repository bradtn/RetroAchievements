import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Product ID for premium upgrade - must match Play Console
const String kPremiumProductId = 'premium_upgrade';

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

  /// Callback when purchase is completed
  Function(bool success)? onPurchaseComplete;

  /// Initialize the purchase service
  Future<void> initialize() async {
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

  /// Handle purchase updates
  void _handlePurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (final purchase in purchaseDetailsList) {
      if (purchase.status == PurchaseStatus.pending) {
        _purchasePending = true;
      } else {
        if (purchase.status == PurchaseStatus.error) {
          if (kDebugMode) print('Purchase error: ${purchase.error}');
          onPurchaseComplete?.call(false);
        } else if (purchase.status == PurchaseStatus.purchased ||
                   purchase.status == PurchaseStatus.restored) {
          // Verify and deliver the product
          _verifyAndDeliverProduct(purchase);
        }

        if (purchase.pendingCompletePurchase) {
          _iap.completePurchase(purchase);
        }
        _purchasePending = false;
      }
    }
  }

  /// Verify purchase and deliver premium
  Future<void> _verifyAndDeliverProduct(PurchaseDetails purchase) async {
    // In a production app, you'd verify the purchase with your server
    // For now, we trust the local purchase status
    if (purchase.productID == kPremiumProductId) {
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

  /// Check if store is available
  bool get isAvailable => _isAvailable;

  /// Check if purchase is pending
  bool get isPurchasePending => _purchasePending;

  /// Purchase premium
  Future<bool> purchasePremium() async {
    if (!_isAvailable) {
      if (kDebugMode) print('Store not available');
      return false;
    }

    final product = premiumProduct;
    if (product == null) {
      if (kDebugMode) print('Premium product not found');
      return false;
    }

    final purchaseParam = PurchaseParam(productDetails: product);

    try {
      // Non-consumable purchase (buy once, keep forever)
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);
      return success;
    } catch (e) {
      if (kDebugMode) print('Purchase error: $e');
      return false;
    }
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
