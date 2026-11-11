package com.xzactopos.xzactopos_mobile

import android.Manifest
import android.bluetooth.BluetoothManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private val channelName = "com.xzactopos.mobile/bluetooth_printer"
    private val sppUuid: UUID = UUID.fromString("00001101-0000-1000-8000-00805F9B34FB")
    private val ioExecutor = Executors.newSingleThreadExecutor()

    private fun ensureBluetoothPermission(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val granted = ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.BLUETOOTH_CONNECT
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                ActivityCompat.requestPermissions(
                    this,
                    arrayOf(
                        Manifest.permission.BLUETOOTH_CONNECT,
                        Manifest.permission.BLUETOOTH_SCAN
                    ),
                    4102
                )
                return false
            }
        }
        return true
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                val btManager = getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
                val adapter = btManager?.adapter

                when (call.method) {
                    "getBondedDevices" -> {
                        if (adapter == null || !adapter.isEnabled) {
                            result.error("BT_DISABLED", "Bluetooth is unavailable or turned off.", null)
                            return@setMethodCallHandler
                        }
                        if (!ensureBluetoothPermission()) {
                            result.error("BT_PERMISSION", "Bluetooth permission requested. Please try again.", null)
                            return@setMethodCallHandler
                        }
                        try {
                            val bonded = adapter.bondedDevices?.map { dev ->
                                mapOf(
                                    "name" to (dev.name ?: "Bluetooth Printer"),
                                    "address" to dev.address
                                )
                            } ?: emptyList()
                            result.success(bonded)
                        } catch (se: SecurityException) {
                            result.error("BT_PERMISSION", se.message, null)
                        }
                    }

                    "sendBytes" -> {
                        val address = call.argument<String>("address")?.trim()
                        val bytes = call.argument<ByteArray>("bytes")
                        if (address.isNullOrEmpty() || bytes == null) {
                            result.error("INVALID_ARGS", "Printer MAC address and payload are required.", null)
                            return@setMethodCallHandler
                        }
                        if (adapter == null || !adapter.isEnabled) {
                            result.error("BT_DISABLED", "Bluetooth is unavailable or turned off.", null)
                            return@setMethodCallHandler
                        }
                        if (!ensureBluetoothPermission()) {
                            result.error("BT_PERMISSION", "Bluetooth permission requested. Please try again.", null)
                            return@setMethodCallHandler
                        }

                        ioExecutor.execute {
                            var socket: android.bluetooth.BluetoothSocket? = null
                            try {
                                val device = adapter.getRemoteDevice(address.uppercase())
                                try {
                                    adapter.cancelDiscovery()
                                } catch (_: SecurityException) {
                                }
                                socket = device.createRfcommSocketToServiceRecord(sppUuid)
                                socket.connect()
                                val out = socket.outputStream
                                out.write(bytes)
                                out.flush()
                                Thread.sleep(150)
                                runOnUiThread { result.success(null) }
                            } catch (e: Exception) {
                                runOnUiThread {
                                    result.error("BT_SEND_FAILED", e.message ?: "Bluetooth write failed", null)
                                }
                            } finally {
                                try {
                                    socket?.close()
                                } catch (_: Exception) {
                                }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }
}
