export type DeferredLinkSource =
  | 'android_install_referrer'
  | 'ios_pasteboard'
  | 'none';

export type DeferredLinkResult = {
  found: boolean;
  source: DeferredLinkSource;
  url?: string;
  rawValue?: string;
  clickedAt?: number;
  isFirstLaunch?: boolean;
  metadata?: Record<string, string>;
};

export type DeferredLinkConfig = {
  domains: string[];
  appScheme?: string;
  ios?: {
    pasteboardPrefix?: string;
    pasteboardTTLSeconds?: number;
  };
  android?: {
    installReferrerParamKey?: string;
  };
};

export interface IDeferredLinkModule {
  configure(config: DeferredLinkConfig): void;
  getInitialDeferredLink(): Promise<DeferredLinkResult>;
  clearConsumedDeferredLink(): Promise<void>;
}
