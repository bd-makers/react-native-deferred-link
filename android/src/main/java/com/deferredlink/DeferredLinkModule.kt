package com.deferredlink

import android.net.Uri
import android.util.Log
import com.facebook.react.bridge.Arguments
import com.facebook.react.bridge.Promise
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.bridge.ReadableMap
import com.facebook.react.bridge.WritableMap

class DeferredLinkModule(reactContext: ReactApplicationContext) :
  NativeDeferredLinkSpec(reactContext) {

  private val storage = DeferredLinkStorage(reactContext)
  private val referrerParser = ReferrerParser(reactContext)

  private var configDomains: List<String> = emptyList()
  private var configAppScheme: String? = null
  private var configReferrerParamKey: String = DEFAULT_REFERRER_PARAM_KEY

  override fun configure(config: ReadableMap) {
    if (config.hasKey("domains")) {
      val domainsArray = config.getArray("domains")
      val domains = mutableListOf<String>()
      if (domainsArray != null) {
        for (i in 0 until domainsArray.size()) {
          domainsArray.getString(i)?.let { domains.add(it) }
        }
      }
      configDomains = domains
    }

    if (config.hasKey("appScheme")) {
      configAppScheme = config.getString("appScheme")
    }

    if (config.hasKey("android")) {
      val androidConfig = config.getMap("android")
      if (androidConfig?.hasKey("installReferrerParamKey") == true) {
        configReferrerParamKey =
          androidConfig.getString("installReferrerParamKey") ?: DEFAULT_REFERRER_PARAM_KEY
      }
    }
  }

  override fun getInitialDeferredLink(promise: Promise) {
    if (storage.consumed) {
      promise.resolve(buildNotFoundResult())
      return
    }

    referrerParser.fetchDeferredLink(configReferrerParamKey) { referrerResult ->
      if (referrerResult == null) {
        promise.resolve(buildNotFoundResult())
        return@fetchDeferredLink
      }

      val url = referrerResult.url

      if (!isDomainAllowed(url)) {
        Log.d(TAG, "Domain not in allowed list: $url")
        promise.resolve(buildNotFoundResult())
        return@fetchDeferredLink
      }

      storage.markConsumed(url)

      val result = Arguments.createMap().apply {
        putBoolean("found", true)
        putString("source", "android_install_referrer")
        putString("url", url)
        putString("rawValue", referrerResult.rawReferrer)
        if (referrerResult.clickedAtSeconds > 0) {
          putDouble("clickedAt", referrerResult.clickedAtSeconds.toDouble())
        }
        val metadata = parseUrlMetadata(url)
        if (metadata != null) {
          putMap("metadata", metadata)
        }
      }
      promise.resolve(result)
    }
  }

  override fun clearConsumedDeferredLink(promise: Promise) {
    storage.clear()
    promise.resolve(null)
  }

  private fun isDomainAllowed(url: String): Boolean {
    if (configDomains.isEmpty()) return true
    return try {
      val host = Uri.parse(url).host ?: return false
      configDomains.any { domain ->
        host == domain || host.endsWith(".$domain")
      }
    } catch (e: Exception) {
      Log.w(TAG, "Failed to parse URL for domain check", e)
      false
    }
  }

  private fun parseUrlMetadata(url: String): WritableMap? {
    return try {
      val uri = Uri.parse(url)
      val paramNames = uri.queryParameterNames
      if (paramNames.isEmpty()) return null
      Arguments.createMap().apply {
        for (key in paramNames) {
          val value = uri.getQueryParameter(key)
          if (value != null) {
            putString(key, value)
          }
        }
      }
    } catch (e: Exception) {
      Log.w(TAG, "Failed to parse URL metadata", e)
      null
    }
  }

  private fun buildNotFoundResult(): ReadableMap {
    return Arguments.createMap().apply {
      putBoolean("found", false)
      putString("source", "none")
    }
  }

  companion object {
    const val NAME = NativeDeferredLinkSpec.NAME
    private const val TAG = "DeferredLinkModule"
    private const val DEFAULT_REFERRER_PARAM_KEY = "ddl"
  }
}
