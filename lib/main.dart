import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';

import 'services/fcm_service.dart'; // tambah ini

import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:wastefood/l10n/app_localizations.dart';

// Screens
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/register_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_tab.dart';
import 'screens/profile/account_page.dart';
import 'screens/profile/security_page.dart';
import 'screens/profile/address_page.dart';
import 'screens/profile/add_address_page.dart'; // kalau file-nya di situ
import 'screens/profile/settings_page.dart';
import 'screens/profile/help_page.dart';
import 'screens/profile/address_select_page.dart';
import 'screens/store/store_page.dart';
import 'screens/store/add_store_welcome_page.dart';
import 'screens/store/store_pending_page.dart';
import 'screens/store/store_verification_page.dart';
import 'screens/store/store_info_page.dart';
import 'screens/store/store_performance_page.dart';
import 'screens/store/add_product_page.dart';
import 'screens/store/store_finance_page.dart';
import 'screens/store/product_list_page.dart';
import 'screens/store/store_product_detail_page.dart';
import 'screens/store/store_detail_page.dart';

//keranjang dan checkout
import 'screens/cart/cart_page.dart';
import 'models/cart_item.dart';
import 'screens/checkout/checkout_page.dart';

// *** Tambahan import untuk order pages ***
import 'screens/store/orders_page.dart';
import 'screens/order/order_confirmation_page.dart';
import 'screens/order/order_detail_page.dart';
import 'screens/order/order_success_page.dart';
import 'screens/order/order_canceled_page.dart'; // halaman order batal / cancel

import 'screens/review/review_page.dart';

import 'screens/chat/chat_page.dart'; // pastikan file ini ada di folder yang sama
import 'screens/chat/chat_list_page.dart'; // pastikan file ini ada di folder yang sama

import 'services/presence_service.dart';
import 'package:wastefood/services/navigation_service.dart';
import 'screens/product_detail_page.dart';

final presence = PresenceService();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 🔥 Semua FCM (background, foreground, token, local notif) di-handle oleh FCMService
  await FcmService.initialize();

  // Presence
  presence.init();

  runApp(const MyApp());
}

/// 🌍 Main App Widget
class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => MyAppState();
}

class MyAppState extends State<MyApp> {
  Locale _locale = const Locale('id');
  bool _isDarkMode = false;

  void setLocale(Locale locale) => setState(() => _locale = locale);
  void toggleDarkMode(bool value) => setState(() => _isDarkMode = value);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WasteFood',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey, // 🔥 WAJIB ADA
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      themeMode: _isDarkMode ? ThemeMode.dark : ThemeMode.light,
      locale: _locale,
      supportedLocales: const [Locale('en'), Locale('id')],
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      onGenerateRoute: _generateRoute,
    );
  }

  /// 🧭 Routing Configuration
  Route<dynamic> _generateRoute(RouteSettings settings) {
    final args = settings.arguments;

    switch (settings.name) {
      case '/':
        return _build(const SplashScreen());
      case '/login':
        return _build(const LoginScreen());
      case '/register':
        return _build(const RegisterScreen());
      case '/home':
        return _build(const HomeScreen());
      case '/profile':
        return _build(const ProfileTab());

      // Profile Sub Pages
      case '/profile/account':
        return _build(const AccountPage());
      case '/profile/security':
        return _build(const SecurityPage());
      case '/profile/address':
        return _build(const AddressPage());
      case '/profile/settings':
        return _build(
          SettingsPage(
            onLocaleChange: setLocale,
            onDarkModeChange: toggleDarkMode,
            isDarkMode: _isDarkMode,
          ),
        );
      case '/profile/help':
        return _build(const HelpPage());
      case '/address/select':
        return _build(const AddressSelectPage());

      // Store
      case '/store':
        return _build(const StorePage());
      case '/store/add/welcome':
        return _build(const AddStoreWelcomePage());
      case '/store/pending':
        return _build(const StorePendingPage());
      case '/store/verif':
        if (args is Map<String, dynamic>) {
          return _build(StoreVerificationPage(storeData: args));
        }
        return _errorRoute('Data verifikasi toko tidak ditemukan');
      case '/store/info':
        return _build(const StoreInfoPage());
      case '/store/performance':
        return _build(const StorePerformancePage());
      case '/store/add_product':
        if (args is Map<String, dynamic> && args.containsKey('tokoId')) {
          return _build(AddProductPage(tokoId: args['tokoId']));
        }
        return _errorRoute('Data toko tidak lengkap');
      case '/store/finance':
        if (args is Map<String, dynamic> &&
            args.containsKey('tokoId') &&
            args.containsKey('userUid')) {
          return _build(
            StoreFinancePage(tokoId: args['tokoId'], userUid: args['userUid']),
          );
        }
        return _errorRoute('Data toko atau user tidak lengkap');
      case '/store/product_list':
        return _build(const StoreProductListPage());
      case '/store/product_detail':
        if (args is Map<String, dynamic> && args.containsKey('productData')) {
          return _build(
            StoreProductDetailPage(productData: args['productData']),
          );
        }
        return _errorRoute('Data produk tidak ditemukan');
      case '/store/detail':
        if (args is Map<String, dynamic> &&
            args.containsKey('tokoId') &&
            args.containsKey('tokoNama')) {
          return _build(
            StoreDetailPage(tokoId: args['tokoId'], tokoNama: args['tokoNama']),
          );
        }
        return _errorRoute('Data toko tidak lengkap');
      case '/store/orders':
        if (args is Map<String, dynamic> && args.containsKey('tokoId')) {
          return _build(
            OrdersPage(tokoId: args['tokoId']),
          ); // ✅ sekarang tidak error
        }
        return _errorRoute('Data toko tidak ditemukan');

      // Cart & Checkout
      case '/cart':
        return _build(const CartPage());
      case '/checkout':
        if (args is List<CartItem>) {
          return MaterialPageRoute(builder: (_) => CheckoutPage(items: args));
        }
        return _errorRoute('Data keranjang tidak valid');

      // ✅ Tambahkan ini di bawahnya:
      case '/alamat-pilih':
        return MaterialPageRoute(builder: (_) => AddressSelectPage());

      // kalo alamat ga ada
      case '/address-add':
        return _build(const AddAddressPage());

      case '/orders':
        final tokoId = settings.arguments as String; // ambil dari arguments
        return _build(OrdersPage(tokoId: tokoId)); // masukkan ke constructor

      case '/order/confirmation':
        return MaterialPageRoute(builder: (_) => const OrderConfirmationPage());

      case '/order-detail':
        if (args is String) {
          return _build(OrderDetailPage(orderId: args));
        }
        return _errorRoute('Order ID tidak valid');

      case '/order-canceled':
        if (args is String) {
          return _build(OrderCanceledPage(orderId: args));
        }
        return _errorRoute('Order ID tidak valid');

      case '/order-success':
        if (args is Map<String, dynamic>) {
          final orderId = args['orderId'] ?? '';
          final totalHarga = args['totalHarga'] ?? 0;
          final items = List<Map<String, dynamic>>.from(args['items'] ?? []);
          final tokoId = args['tokoId'] ?? ''; // ← Tambahkan ini

          return _build(
            OrderSuccessPage(
              orderId: orderId,
              totalHarga: totalHarga,
              items: items,
              tokoId: tokoId, // ← Dan ini juga
            ),
          );
        }
        return _errorRoute('Argument untuk order success tidak valid');

      case '/review':
        if (args is Map<String, String> &&
            args.containsKey('produkId') &&
            args.containsKey('userId') &&
            args.containsKey('tokoId') &&
            args.containsKey('orderId')) {
          return MaterialPageRoute(
            builder:
                (_) => ReviewPage(
                  produkId: args['produkId']!,
                  userId: args['userId']!,
                  tokoId: args['tokoId']!,
                  orderId: args['orderId']!,
                ),
          );
        }
        return _errorRoute('Parameter tidak valid untuk halaman review');

      // Chat
      case '/chat/list':
        return _build(ChatListPage());

      case '/chat/detail':
        if (args is Map<String, dynamic> &&
            args.containsKey('userId') &&
            args.containsKey('tokoId')) {
          return _build(
            ChatPage(userId: args['userId'], tokoId: args['tokoId']),
          );
        }
        return _errorRoute('Data chat tidak lengkap');

      // ⭐ ROUTE UNTUK CUSTOMER BUKA PRODUK DARI NOTIFIKASI
      case '/product-detail':
        if (args is Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => ProductDetailPage(productData: args),
          );
        }
        return _errorRoute('Product data tidak valid untuk notifikasi');

      // Default / Error
      default:
        return _errorRoute('Halaman tidak ditemukan: ${settings.name}');
    }
  }

  MaterialPageRoute _build(Widget page) =>
      MaterialPageRoute(builder: (_) => page);

  MaterialPageRoute _errorRoute(String message) {
    return MaterialPageRoute(
      builder:
          (_) => Scaffold(
            appBar: AppBar(title: const Text('Error')),
            body: Center(
              child: Text(message, style: const TextStyle(fontSize: 16)),
            ),
          ),
    );
  }
}
