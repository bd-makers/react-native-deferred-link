package com.deferredlink

import com.facebook.react.BaseReactPackage
import com.facebook.react.bridge.NativeModule
import com.facebook.react.bridge.ReactApplicationContext
import com.facebook.react.module.model.ReactModuleInfo
import com.facebook.react.module.model.ReactModuleInfoProvider
import java.util.HashMap

class DeferredLinkPackage : BaseReactPackage() {
  override fun getModule(name: String, reactContext: ReactApplicationContext): NativeModule? {
    return if (name == DeferredLinkModule.NAME) {
      DeferredLinkModule(reactContext)
    } else {
      null
    }
  }

  override fun getReactModuleInfoProvider() = ReactModuleInfoProvider {
    mapOf(
      DeferredLinkModule.NAME to ReactModuleInfo(
        name = DeferredLinkModule.NAME,
        className = DeferredLinkModule.NAME,
        canOverrideExistingModule = false,
        needsEagerInit = false,
        isCxxModule = false,
        isTurboModule = BuildConfig.IS_NEW_ARCHITECTURE_ENABLED
      )
    )
  }
}
