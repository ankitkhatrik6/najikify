package com.najikify.app

import android.content.Context
import android.net.ConnectivityManager
import java.net.Inet4Address

/**
 * Reads the device's local IPv4 addresses **with their prefix lengths**.
 *
 * Dart's `NetworkInterface.list()` cannot see the netmask, which is exactly
 * what Najikify needs to tell whether a peer address could possibly be on this
 * network. `LinkProperties.linkAddresses` exposes it, and `ConnectivityManager`
 * needs only the (already declared) ACCESS_NETWORK_STATE permission — no
 * location permission, unlike SSID lookups.
 *
 * Exposed to Dart through the `najikify/network` channel
 * (`NetworkUtils.localSubnets` in `lib/core/utils/network_utils.dart`).
 *
 * Everything is best-effort: an empty list simply makes Dart fall back to the
 * `ip` command or conventional guesses, so this must never throw.
 */
object NetworkInspector {

    /**
     * Every non-loopback IPv4 link address as
     * `{"address": "192.168.1.5", "prefixLength": 24, "interfaceName": "wlan0"}`.
     */
    fun linkAddresses(context: Context): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        val manager = context.getSystemService(Context.CONNECTIVITY_SERVICE)
            as? ConnectivityManager ?: return result

        try {
            for (network in manager.allNetworks) {
                val properties = runCatching {
                    manager.getLinkProperties(network)
                }.getOrNull()
                if (properties == null) continue

                val name = properties.interfaceName ?: ""
                for (linkAddress in properties.linkAddresses) {
                    val address = linkAddress.address
                    if (address !is Inet4Address || address.isLoopbackAddress) continue

                    val host = address.hostAddress
                    if (host.isNullOrEmpty()) continue

                    result.add(
                        mapOf(
                            "address" to host,
                            "prefixLength" to linkAddress.prefixLength,
                            "interfaceName" to name,
                        )
                    )
                }
            }
        } catch (e: Exception) {
            // Return whatever was collected so far.
        }

        return result
    }
}
