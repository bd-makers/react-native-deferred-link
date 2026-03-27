import { NativeModules } from 'react-native';

import type { Spec } from './NativeDeferredLink';
import NativeDeferredLink from './NativeDeferredLink';
import type {
  DeferredLinkConfig,
  DeferredLinkResult,
  IDeferredLinkModule,
} from './types';

export type {
  DeferredLinkConfig,
  DeferredLinkResult,
  DeferredLinkSource,
  IDeferredLinkModule,
} from './types';

const TAG = '[react-native-deferred-link]';

const LINKING_WARNING =
  `${TAG} Native module not found. ` +
  'Make sure you have run `pod install` and rebuilt the app. ' +
  'Deferred link features will be unavailable.';

const nativeModule: Spec | null =
  NativeDeferredLink ??
  (NativeModules.DeferredLink as Spec | undefined) ??
  null;

if (!nativeModule) {
  console.warn(LINKING_WARNING);
} else {
  console.log(
    `${TAG} Native module loaded (turbo=${!!NativeDeferredLink}, bridge=${!!NativeModules.DeferredLink})`
  );
}

const NOT_FOUND_RESULT: DeferredLinkResult = {
  found: false,
  source: 'none',
};

export const DeferredLink: IDeferredLinkModule = {
  configure(config: DeferredLinkConfig): void {
    if (!nativeModule) {
      console.warn(`${TAG} configure skipped — native module is null`);
      return;
    }
    console.log(`${TAG} configure`, JSON.stringify(config));
    nativeModule.configure(config as unknown as Object);
  },

  async getInitialDeferredLink(): Promise<DeferredLinkResult> {
    if (!nativeModule) {
      console.warn(
        `${TAG} getInitialDeferredLink skipped — native module is null`
      );
      return NOT_FOUND_RESULT;
    }
    console.log(`${TAG} getInitialDeferredLink called`);
    const raw = await nativeModule.getInitialDeferredLink();
    const result = raw as unknown as DeferredLinkResult;
    console.log(
      `${TAG} getInitialDeferredLink result:`,
      JSON.stringify(result)
    );
    return result;
  },

  async clearConsumedDeferredLink(): Promise<void> {
    if (!nativeModule) {
      return;
    }
    console.log(`${TAG} clearConsumedDeferredLink called`);
    await nativeModule.clearConsumedDeferredLink();
  },
};
