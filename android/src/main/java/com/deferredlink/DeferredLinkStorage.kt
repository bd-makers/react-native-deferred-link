package com.deferredlink

import android.content.Context
import android.content.SharedPreferences

class DeferredLinkStorage(context: Context) {

  private val prefs: SharedPreferences =
    context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

  var consumed: Boolean
    get() = prefs.getBoolean(KEY_CONSUMED, false)
    set(value) = prefs.edit().putBoolean(KEY_CONSUMED, value).apply()

  var lastValue: String?
    get() = prefs.getString(KEY_LAST_VALUE, null)
    set(value) = prefs.edit().putString(KEY_LAST_VALUE, value).apply()

  var lastConsumedAt: Long
    get() = prefs.getLong(KEY_LAST_CONSUMED_AT, 0L)
    set(value) = prefs.edit().putLong(KEY_LAST_CONSUMED_AT, value).apply()

  fun markConsumed(url: String) {
    prefs.edit()
      .putBoolean(KEY_CONSUMED, true)
      .putString(KEY_LAST_VALUE, url)
      .putLong(KEY_LAST_CONSUMED_AT, System.currentTimeMillis())
      .apply()
  }

  fun clear() {
    prefs.edit()
      .remove(KEY_CONSUMED)
      .remove(KEY_LAST_VALUE)
      .remove(KEY_LAST_CONSUMED_AT)
      .apply()
  }

  companion object {
    private const val PREFS_NAME = "deferred_link_storage"
    private const val KEY_CONSUMED = "deferred_link.consumed"
    private const val KEY_LAST_VALUE = "deferred_link.last_value"
    private const val KEY_LAST_CONSUMED_AT = "deferred_link.last_consumed_at"
  }
}
