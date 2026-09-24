import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aaspaas/features/nearby/domain/entities/location_state.dart';
import 'package:aaspaas/features/nearby/presentation/widgets/location_header_badge.dart';
import 'package:aaspaas/features/nearby/presentation/widgets/nearby_permission_view.dart';
import 'package:aaspaas/features/nearby/presentation/widgets/radius_selector.dart';

Widget _wrapWithTheme(Widget child) {
  return MaterialApp(
    home: Scaffold(
      body: child,
    ),
  );
}

void main() {
  group('RadiusSelector', () {
    testWidgets('renders all radius options and triggers callback on tap',
        (tester) async {
      int selectedRadius = 5;

      await tester.pumpWidget(
        _wrapWithTheme(
          StatefulBuilder(
            builder: (context, setState) {
              return RadiusSelector(
                selectedRadiusKm: selectedRadius,
                onRadiusSelected: (radius) {
                  setState(() => selectedRadius = radius);
                },
              );
            },
          ),
        ),
      );

      // Verify all options render
      for (final r in [1, 3, 5, 10, 20]) {
        expect(find.text('$r km'), findsOneWidget);
      }

      // Tap 10 km
      await tester.tap(find.text('10 km'));
      await tester.pumpAndSettle();

      expect(selectedRadius, 10);
    });
  });

  group('LocationHeaderBadge', () {
    testWidgets('renders current GPS location when LocationReady',
        (tester) async {
      bool changeTapped = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          LocationHeaderBadge(
            locationState: const LocationReady(
              latitude: 12.9352,
              longitude: 77.6245,
              isApproximate: false,
            ),
            onChangeLocality: () => changeTapped = true,
          ),
        ),
      );

      expect(find.text('Near your current location'), findsOneWidget);
      expect(find.text('Precise GPS position'), findsOneWidget);
      expect(find.text('Change'), findsOneWidget);

      await tester.tap(find.text('Change'));
      expect(changeTapped, isTrue);
    });

    testWidgets('renders manual locality when LocationManualLocality',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          LocationHeaderBadge(
            locationState: const LocationManualLocality(
              localityName: 'Indiranagar',
              cityName: 'Bengaluru',
              latitude: 12.9784,
              longitude: 77.6408,
            ),
            onChangeLocality: () {},
          ),
        ),
      );

      expect(find.text('Near Indiranagar, Bengaluru'), findsOneWidget);
      expect(find.text('Using selected locality'), findsOneWidget);
    });
  });

  group('NearbyPermissionView', () {
    testWidgets('renders initial prompt with enable button and manual picker',
        (tester) async {
      bool enableTapped = false;
      bool manualTapped = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          NearbyPermissionView(
            locationState: const LocationInitial(),
            onRequestLocation: () => enableTapped = true,
            onChooseLocality: () => manualTapped = true,
            onOpenSettings: () {},
            onOpenLocationSettings: () {},
          ),
        ),
      );

      expect(find.text("Discover What's Around You"), findsOneWidget);
      expect(find.text('Enable Location'), findsOneWidget);
      expect(find.text('Choose Locality Instead'), findsOneWidget);

      await tester.tap(find.text('Enable Location'));
      expect(enableTapped, isTrue);

      await tester.tap(find.text('Choose Locality Instead'));
      expect(manualTapped, isTrue);
    });

    testWidgets('renders permission denied state with retry button',
        (tester) async {
      await tester.pumpWidget(
        _wrapWithTheme(
          NearbyPermissionView(
            locationState: const LocationPermissionDenied(),
            onRequestLocation: () {},
            onChooseLocality: () {},
            onOpenSettings: () {},
            onOpenLocationSettings: () {},
          ),
        ),
      );

      expect(find.text('Location Permission Needed'), findsOneWidget);
      expect(find.text('Allow Location'), findsOneWidget);
    });

    testWidgets('renders permanently denied state with settings button',
        (tester) async {
      bool settingsTapped = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          NearbyPermissionView(
            locationState: const LocationPermissionPermanentlyDenied(),
            onRequestLocation: () {},
            onChooseLocality: () {},
            onOpenSettings: () => settingsTapped = true,
            onOpenLocationSettings: () {},
          ),
        ),
      );

      expect(find.text('Permission Permanently Disabled'), findsOneWidget);
      expect(find.text('Open App Settings'), findsOneWidget);

      await tester.tap(find.text('Open App Settings'));
      expect(settingsTapped, isTrue);
    });

    testWidgets('renders service disabled state with location settings button',
        (tester) async {
      bool locSettingsTapped = false;

      await tester.pumpWidget(
        _wrapWithTheme(
          NearbyPermissionView(
            locationState: const LocationServiceDisabled(),
            onRequestLocation: () {},
            onChooseLocality: () {},
            onOpenSettings: () {},
            onOpenLocationSettings: () => locSettingsTapped = true,
          ),
        ),
      );

      expect(find.text('Location Services Turned Off'), findsOneWidget);
      expect(find.text('Turn On Location'), findsOneWidget);

      await tester.tap(find.text('Turn On Location'));
      expect(locSettingsTapped, isTrue);
    });
  });
}
