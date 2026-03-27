package com.deferredlink

import android.content.Context
import android.net.Uri
import android.util.Log
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener

data class ReferrerResult(
  val url: String,
  val clickedAtSeconds: Long,
  val rawReferrer: String
)

class ReferrerParser(private val context: Context) {

  fun fetchDeferredLink(paramKey: String, onResult: (ReferrerResult?) -> Unit) {
    val client = InstallReferrerClient.newBuilder(context).build()

    client.startConnection(object : InstallReferrerStateListener {
      override fun onInstallReferrerSetupFinished(responseCode: Int) {
        when (responseCode) {
          InstallReferrerClient.InstallReferrerResponse.OK -> {
            try {
              val details = client.installReferrer
              val referrerString = details.installReferrer
              val clickedAt = details.referrerClickTimestampSeconds
              val url = extractDeferredLink(referrerString, paramKey)
              if (url != null) {
                onResult(ReferrerResult(url, clickedAt, referrerString))
              } else {
                onResult(null)
              }
            } catch (e: Exception) {
              Log.w(TAG, "Failed to read install referrer", e)
              onResult(null)
            } finally {
              client.endConnection()
            }
          }
          InstallReferrerClient.InstallReferrerResponse.FEATURE_NOT_SUPPORTED,
          InstallReferrerClient.InstallReferrerResponse.SERVICE_UNAVAILABLE -> {
            Log.d(TAG, "Install referrer not available: responseCode=$responseCode")
            onResult(null)
            client.endConnection()
          }
          else -> {
            Log.d(TAG, "Install referrer unknown response: $responseCode")
            onResult(null)
            client.endConnection()
          }
        }
      }

      override fun onInstallReferrerServiceDisconnected() {
        Log.d(TAG, "Install referrer service disconnected")
      }
    })
  }

  private fun extractDeferredLink(referrerString: String, paramKey: String): String? {
    if (referrerString.isBlank()) return null
    return try {
      // Referrer string format: URL-encoded query params (e.g. "utm_source=google&ddl=https%3A%2F%2F...")
      val fakeUri = Uri.parse("https://dummy?$referrerString")
      val encodedValue = fakeUri.getQueryParameter(paramKey)
      if (encodedValue.isNullOrBlank()) null else encodedValue
    } catch (e: Exception) {
      Log.w(TAG, "Failed to parse referrer string", e)
      null
    }
  }

  companion object {
    private const val TAG = "ReferrerParser"
  }
}
