import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

/// Service for managing Google AdMob ads
class AdService {
  static final AdService _instance = AdService._internal();
  factory AdService() => _instance;
  AdService._internal();

  bool _isInitialized = false;
  bool _canShowPersonalizedAds = false;
  bool _hasRequestedATT = false;

  /// Whether personalized ads can be shown (user granted tracking permission)
  bool get canShowPersonalizedAds => _canShowPersonalizedAds;

  /// Initialize the Mobile Ads SDK
  /// Must be called after requesting ATT permission on iOS
  Future<void> initialize() async {
    if (_isInitialized) return;

    // On iOS, we'll request ATT permission separately after app is fully visible
    if (Platform.isIOS) {
      // Don't schedule here - ATT will be requested from the UI layer
      // after the app is fully visible and the user has context
    } else {
      // Android doesn't require ATT
      _canShowPersonalizedAds = true;
    }

    await MobileAds.instance.initialize();
    _isInitialized = true;

    if (kDebugMode) {
      print('AdMob initialized. Personalized ads: $_canShowPersonalizedAds');
    }
  }

  /// Request ATT permission - call this from UI after app is fully visible
  Future<void> requestTrackingPermission() async {
    if (!Platform.isIOS) return;
    if (_hasRequestedATT) return;
    _hasRequestedATT = true;

    await _requestTrackingAuthorization();
  }

  /// Request App Tracking Transparency authorization on iOS
  Future<void> _requestTrackingAuthorization() async {
    try {
      if (kDebugMode) {
        print('ATT: Checking tracking authorization status...');
      }

      // Check current status first
      final status = await AppTrackingTransparency.trackingAuthorizationStatus;

      if (kDebugMode) {
        print('ATT: Current status = $status');
      }

      if (status == TrackingStatus.notDetermined) {
        if (kDebugMode) {
          print('ATT: Status not determined, requesting authorization...');
        }

        // Request authorization
        final result = await AppTrackingTransparency.requestTrackingAuthorization();
        _canShowPersonalizedAds = result == TrackingStatus.authorized;

        if (kDebugMode) {
          print('ATT: Request result = $result, personalized ads = $_canShowPersonalizedAds');
        }
      } else {
        _canShowPersonalizedAds = status == TrackingStatus.authorized;

        if (kDebugMode) {
          print('ATT: Status already set to $status, personalized ads = $_canShowPersonalizedAds');
        }
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print('ATT: Error requesting authorization: $e');
        print('ATT: Stack trace: $stackTrace');
      }
      // Default to non-personalized ads on error
      _canShowPersonalizedAds = false;
    }
  }

  /// Get the banner ad unit ID
  String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-2658368978045167/6585548356';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-2658368978045167/6226868390';
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Get the interstitial ad unit ID (test IDs for development)
  String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/1033173712';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/4411468910';
    }
    throw UnsupportedError('Unsupported platform');
  }

  /// Get the appropriate ad request based on tracking authorization
  AdRequest get _adRequest {
    if (_canShowPersonalizedAds) {
      return const AdRequest();
    } else {
      // Non-personalized ads for users who denied tracking
      return const AdRequest(
        nonPersonalizedAds: true,
      );
    }
  }

  /// Create a banner ad
  BannerAd createBannerAd({
    required void Function(Ad) onAdLoaded,
    required void Function(Ad, LoadAdError) onAdFailedToLoad,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: AdSize.banner,
      request: _adRequest,
      listener: BannerAdListener(
        onAdLoaded: onAdLoaded,
        onAdFailedToLoad: onAdFailedToLoad,
        onAdOpened: (ad) {
          if (kDebugMode) print('Banner ad opened');
        },
        onAdClosed: (ad) {
          if (kDebugMode) print('Banner ad closed');
        },
      ),
    );
  }
}
