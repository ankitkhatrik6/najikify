import 'package:flutter_test/flutter_test.dart';
import 'package:najikify/core/errors/app_exceptions.dart';
import 'package:najikify/core/utils/network_utils.dart';

void main() {
  group('IPv4 subnet maths', () {
    test('parseIpv4 accepts valid addresses and rejects junk', () {
      expect(NetworkUtils.parseIpv4('192.168.1.5'), isNotNull);
      expect(NetworkUtils.parseIpv4('0.0.0.0'), 0);
      expect(NetworkUtils.parseIpv4('255.255.255.255'), 0xFFFFFFFF);

      expect(NetworkUtils.parseIpv4('192.168.1'), isNull);
      expect(NetworkUtils.parseIpv4('192.168.1.256'), isNull);
      expect(NetworkUtils.parseIpv4('192.168.1.-1'), isNull);
      expect(NetworkUtils.parseIpv4('not-an-ip'), isNull);
      expect(NetworkUtils.isValidIpv4('192.168.1.5'), isTrue);
      expect(NetworkUtils.isValidIpv4(''), isFalse);
    });

    test('networkAddress masks the host bits away', () {
      expect(NetworkUtils.networkAddress('192.168.1.57', 24), '192.168.1.0');
      expect(NetworkUtils.networkAddress('10.4.9.200', 16), '10.4.0.0');
      expect(NetworkUtils.networkAddress('172.20.5.5', 12), '172.16.0.0');
      expect(NetworkUtils.networkAddress('192.168.1.57', 32), '192.168.1.57');
    });

    test('sameSubnet only matches inside the prefix', () {
      expect(NetworkUtils.sameSubnet('192.168.1.5', '192.168.1.200', 24), isTrue);
      expect(NetworkUtils.sameSubnet('192.168.1.5', '192.168.2.5', 24), isFalse);
      // A /16 network keeps 192.168.x.x together.
      expect(NetworkUtils.sameSubnet('192.168.1.5', '192.168.9.5', 16), isTrue);
      expect(NetworkUtils.sameSubnet('192.168.1.5', 'bad', 24), isFalse);
    });

    test('maskedNetwork renders the network as users read it', () {
      expect(NetworkUtils.maskedNetwork('192.168.1.57', 24), '192.168.1.x');
      expect(NetworkUtils.maskedNetwork('10.4.9.200', 16), '10.4.x.x');
      expect(NetworkUtils.maskedNetwork('172.20.5.5', 12), '172.x.x.x');
    });

    test('isInAnySubnet walks every interface', () {
      const subnets = [
        LocalSubnet(address: '192.168.1.5', prefixLength: 24),
        LocalSubnet(address: '10.42.0.1', prefixLength: 24),
      ];

      expect(NetworkUtils.isInAnySubnet('192.168.1.77', subnets), isTrue);
      expect(NetworkUtils.isInAnySubnet('10.42.0.99', subnets), isTrue);
      expect(NetworkUtils.isInAnySubnet('192.168.4.77', subnets), isFalse);
      // Mobile-data style address: never a local peer.
      expect(NetworkUtils.isInAnySubnet('100.64.3.9', subnets), isFalse);
      expect(NetworkUtils.isInAnySubnet('192.168.1.5', const []), isFalse);
    });

    test('guessPrefixLength follows the usual router conventions', () {
      expect(NetworkUtils.guessPrefixLength('192.168.1.5'), 24);
      expect(NetworkUtils.guessPrefixLength('10.0.0.5'), 24);
      expect(NetworkUtils.guessPrefixLength('172.20.5.5'), 16);
    });
  });

  group('checkPeer diagnosis', () {
    tearDown(() {
      NetworkUtils.localSubnetsOverride = null;
      NetworkUtils.probeOverride = null;
    });

    test('a reachable peer is accepted even outside the local subnet', () async {
      // e.g. a VPN / routed network: if it answers, it works.
      NetworkUtils.localSubnetsOverride = () async => const [
            LocalSubnet(address: '192.168.1.5', prefixLength: 24),
          ];
      NetworkUtils.probeOverride = (host, port, timeout) async => true;

      final report = await NetworkUtils.checkPeer(
        peerIp: '10.9.9.9',
        peerPort: 53317,
        deviceName: 'Pixel 8',
      );

      expect(report.verdict, PeerNetworkVerdict.reachable);
      expect(report.isReachable, isTrue);
      expect(report.isDifferentNetwork, isFalse);
      expect(report.message, isEmpty);
    });

    test('a peer outside every local subnet is a different network', () async {
      NetworkUtils.localSubnetsOverride = () async => const [
            LocalSubnet(address: '192.168.1.5', prefixLength: 24),
          ];
      NetworkUtils.probeOverride = (host, port, timeout) async => false;

      final report = await NetworkUtils.checkPeer(
        peerIp: '192.168.4.7',
        peerPort: 53317,
        deviceName: 'Pixel 8',
      );

      expect(report.verdict, PeerNetworkVerdict.differentNetwork);
      expect(report.isDifferentNetwork, isTrue);
      expect(report.peerNetworkLabel, '192.168.4.x');
      expect(report.localNetworkLabel, '192.168.1.x');
      expect(report.message, contains('different network'));
      expect(report.message, contains('192.168.4.x'));
      expect(report.message, contains('192.168.1.x'));
      expect(report.message, contains('Pixel 8'));
    });

    test('same subnet but silent is unreachable, not a different network',
        () async {
      NetworkUtils.localSubnetsOverride = () async => const [
            LocalSubnet(address: '192.168.1.5', prefixLength: 24),
          ];
      NetworkUtils.probeOverride = (host, port, timeout) async => false;

      final report = await NetworkUtils.checkPeer(
        peerIp: '192.168.1.9',
        peerPort: 53317,
        deviceName: 'Laptop',
      );

      expect(report.verdict, PeerNetworkVerdict.unreachable);
      expect(report.isDifferentNetwork, isFalse);
      expect(report.message, contains('Cannot reach'));
      expect(report.message, contains('192.168.1.9:53317'));
    });

    test('a device with no local address reports noLocalNetwork', () async {
      NetworkUtils.localSubnetsOverride = () async => const [];
      NetworkUtils.probeOverride = (host, port, timeout) async => false;

      final report = await NetworkUtils.checkPeer(
        peerIp: '100.64.3.9',
        peerPort: 53317,
      );

      expect(report.verdict, PeerNetworkVerdict.noLocalNetwork);
      expect(report.message, contains('no Wi-Fi or LAN address'));
    });
  });

  group('networkFailureFor mapping', () {
    test('different network becomes DifferentNetworkException', () {
      const report = PeerNetworkReport(
        verdict: PeerNetworkVerdict.differentNetwork,
        peerAddress: '192.168.4.7',
        peerPort: 53317,
        peerName: 'Pixel 8',
        localSubnets: [LocalSubnet(address: '192.168.1.5', prefixLength: 24)],
      );

      final failure = networkFailureFor(report);
      expect(failure, isA<DifferentNetworkException>());
      final exception = failure as DifferentNetworkException;
      expect(exception.code, 'DIFFERENT_NETWORK');
      expect(exception.peerNetwork, '192.168.4.x');
      expect(exception.localNetwork, '192.168.1.x');
      expect(exception.message, contains('different network'));
    });

    test('missing local address becomes NetworkUnavailableException', () {
      const report = PeerNetworkReport(
        verdict: PeerNetworkVerdict.noLocalNetwork,
        peerAddress: '100.64.3.9',
        peerPort: 53317,
      );

      expect(networkFailureFor(report), isA<NetworkUnavailableException>());
    });

    test('reachable and unreachable peers are not blocked up front', () {
      const reachable = PeerNetworkReport(
        verdict: PeerNetworkVerdict.reachable,
        peerAddress: '192.168.1.9',
        peerPort: 53317,
      );
      const unreachable = PeerNetworkReport(
        verdict: PeerNetworkVerdict.unreachable,
        peerAddress: '192.168.1.9',
        peerPort: 53317,
      );

      expect(networkFailureFor(reachable), isNull);
      expect(networkFailureFor(unreachable), isNull);
    });
  });
}
