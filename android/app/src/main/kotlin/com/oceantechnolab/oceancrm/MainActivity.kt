package com.oceantechnolab.oceancrm

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "com.oceantechnolab.oceancrm/phone_call"
	private val callPhonePermissionRequestCode = 1024

	private var pendingPhoneNumber: String? = null
	private var pendingResult: MethodChannel.Result? = null

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
			.setMethodCallHandler { call, result ->
				when (call.method) {
					"callPhone" -> {
						val phone = call.argument<String>("phone")
						if (phone.isNullOrBlank()) {
							result.error("INVALID_ARGUMENT", "Phone number is required", null)
							return@setMethodCallHandler
						}
						callPhone(phone, result)
					}
					else -> result.notImplemented()
				}
			}
	}

	private fun callPhone(phone: String, result: MethodChannel.Result) {
		if (ContextCompat.checkSelfPermission(this, Manifest.permission.CALL_PHONE) == PackageManager.PERMISSION_GRANTED) {
			startDirectCall(phone, result)
			return
		}

		pendingPhoneNumber = phone
		pendingResult = result
		ActivityCompat.requestPermissions(
			this,
			arrayOf(Manifest.permission.CALL_PHONE),
			callPhonePermissionRequestCode,
		)
	}

	override fun onRequestPermissionsResult(
		requestCode: Int,
		permissions: Array<out String>,
		grantResults: IntArray,
	) {
		super.onRequestPermissionsResult(requestCode, permissions, grantResults)

		if (requestCode != callPhonePermissionRequestCode) return

		val result = pendingResult
		val phone = pendingPhoneNumber
		pendingResult = null
		pendingPhoneNumber = null

		if (result == null || phone == null) return

		if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
			startDirectCall(phone, result)
		} else {
			result.error("PERMISSION_DENIED", "Call permission denied", null)
		}
	}

	private fun startDirectCall(phone: String, result: MethodChannel.Result) {
		try {
			val intent = Intent(Intent.ACTION_CALL, Uri.parse("tel:$phone"))
			startActivity(intent)
			result.success(true)
		} catch (exception: Exception) {
			result.error("CALL_FAILED", exception.message, null)
		}
	}
}
