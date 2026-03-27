#import "DeferredLink.h"
#import <UIKit/UIKit.h>

static NSString *const kStorageSuiteKey = @"com.deferredlink.storage";
static NSString *const kConsumedKey = @"deferred_link.consumed";
static NSString *const kLastValueKey = @"deferred_link.last_value";
static NSString *const kLastConsumedAtKey = @"deferred_link.last_consumed_at";
static NSString *const kPayloadSeparator = @"|";

@implementation DeferredLink {
  NSArray<NSString *> *_configDomains;
  NSString *_configAppScheme;
  NSString *_configPasteboardPrefix;
  NSTimeInterval _configPasteboardTTLSeconds;
}

- (instancetype)init {
  self = [super init];
  if (self) {
    _configDomains = @[];
    _configAppScheme = nil;
    _configPasteboardPrefix = @"bodoc:ddl:";
    _configPasteboardTTLSeconds = 900;
    NSLog(@"[DeferredLink] module initialized (defaults: prefix=%@, ttl=%.0f)",
          _configPasteboardPrefix, _configPasteboardTTLSeconds);
  }
  return self;
}

RCT_EXPORT_MODULE(DeferredLink)

+ (BOOL)requiresMainQueueSetup {
  return NO;
}

#pragma mark - Public API

// configure — RCT_EXPORT_METHOD provides both bridge discovery and TurboModule compatibility
RCT_EXPORT_METHOD(configure:(NSDictionary *)config)
{
  NSLog(@"[DeferredLink] configure called with: %@", config);

  if (config[@"domains"]) {
    _configDomains = config[@"domains"];
  }
  if (config[@"appScheme"]) {
    _configAppScheme = config[@"appScheme"];
  }
  NSDictionary *iosConfig = config[@"ios"];
  if (iosConfig) {
    if (iosConfig[@"pasteboardPrefix"]) {
      _configPasteboardPrefix = iosConfig[@"pasteboardPrefix"];
    }
    if (iosConfig[@"pasteboardTTLSeconds"]) {
      _configPasteboardTTLSeconds = [iosConfig[@"pasteboardTTLSeconds"] doubleValue];
    }
  }

  NSLog(@"[DeferredLink] configured — domains=%@, scheme=%@, prefix=%@, ttl=%.0f",
        _configDomains, _configAppScheme, _configPasteboardPrefix, _configPasteboardTTLSeconds);
}

// getInitialDeferredLink — RCT_EXPORT_METHOD provides both bridge discovery and TurboModule compatibility
RCT_EXPORT_METHOD(getInitialDeferredLink:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
  NSLog(@"[DeferredLink] getInitialDeferredLink called (thread: %@)", [NSThread currentThread]);

  NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kStorageSuiteKey];
  BOOL consumed = [defaults boolForKey:kConsumedKey];

  NSLog(@"[DeferredLink] consumed flag = %@, suite = %@", consumed ? @"YES" : @"NO", kStorageSuiteKey);

  if (consumed) {
    NSString *lastValue = [defaults objectForKey:kLastValueKey];
    NSLog(@"[DeferredLink] already consumed (lastValue: %@), returning not-found", lastValue);
    resolve([self buildNotFoundResult]);
    return;
  }

  // UIPasteboard MUST be accessed on the main thread (iOS 16+ silently
  // returns nil and skips the paste banner when accessed off-main).
  dispatch_async(dispatch_get_main_queue(), ^{
    NSLog(@"[DeferredLink] reading pasteboard on main thread");

    NSDictionary *payload = [self parsePasteboardPayload];

    if (!payload) {
      NSLog(@"[DeferredLink] pasteboard payload is nil — returning not-found");
      resolve([self buildNotFoundResult]);
      return;
    }

    NSString *url = payload[@"url"];
    NSNumber *clickedAt = payload[@"clickedAt"];

    NSLog(@"[DeferredLink] payload url=%@, clickedAt=%@, rawValue=%@",
          url, clickedAt, payload[@"rawValue"]);

    // TTL enforcement: reject expired payloads
    if (clickedAt && self->_configPasteboardTTLSeconds > 0) {
      NSTimeInterval now = [[NSDate date] timeIntervalSince1970];
      NSTimeInterval elapsed = now - [clickedAt doubleValue];
      NSLog(@"[DeferredLink] TTL check: elapsed=%.0fs, limit=%.0fs",
            elapsed, self->_configPasteboardTTLSeconds);
      if (elapsed > self->_configPasteboardTTLSeconds) {
        NSLog(@"[DeferredLink] payload expired — returning not-found");
        resolve([self buildNotFoundResult]);
        return;
      }
    }

    // Domain validation
    if (![self isDomainAllowed:url]) {
      NSLog(@"[DeferredLink] domain not allowed for url: %@", url);
      resolve([self buildNotFoundResult]);
      return;
    }

    [self markConsumed:url];

    NSMutableDictionary *result = [NSMutableDictionary dictionaryWithDictionary:@{
      @"found": @YES,
      @"source": @"ios_pasteboard",
      @"url": url,
      @"rawValue": payload[@"rawValue"] ?: url,
    }];

    if (clickedAt) {
      result[@"clickedAt"] = clickedAt;
    }

    NSDictionary *metadata = [self parseUrlMetadata:url];
    if (metadata && metadata.count > 0) {
      result[@"metadata"] = metadata;
    }

    NSLog(@"[DeferredLink] SUCCESS — found deferred link: %@", url);
    resolve([result copy]);
  });
}

// clearConsumedDeferredLink — RCT_EXPORT_METHOD provides both bridge discovery and TurboModule compatibility
RCT_EXPORT_METHOD(clearConsumedDeferredLink:(RCTPromiseResolveBlock)resolve
                  reject:(RCTPromiseRejectBlock)reject)
{
  NSLog(@"[DeferredLink] clearConsumedDeferredLink called");
  NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kStorageSuiteKey];
  [defaults removeObjectForKey:kConsumedKey];
  [defaults removeObjectForKey:kLastValueKey];
  [defaults removeObjectForKey:kLastConsumedAtKey];
  resolve(nil);
}

#pragma mark - Pasteboard

/// Reads and parses pasteboard content.
/// Payload format: `<prefix><epoch_seconds>|<url>` (with timestamp)
///            or:  `<prefix><url>` (legacy, no TTL enforcement)
/// Returns dictionary with keys: url, rawValue, clickedAt (optional), or nil if invalid.
- (NSDictionary *)parsePasteboardPayload {
  UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
  NSString *text = pasteboard.string;

  NSLog(@"[DeferredLink] parsePasteboardPayload — isMainThread=%@, raw text=%@",
        [NSThread isMainThread] ? @"YES" : @"NO",
        text ? [NSString stringWithFormat:@"\"%@\" (len=%lu)", text, (unsigned long)text.length] : @"nil");

  if (!text || text.length == 0) {
    NSLog(@"[DeferredLink] pasteboard is empty");
    return nil;
  }

  // Prefix filtering
  if (_configPasteboardPrefix && _configPasteboardPrefix.length > 0) {
    if (![text hasPrefix:_configPasteboardPrefix]) {
      return nil;
    }
    NSString *rawValue = text;
    text = [text substringFromIndex:_configPasteboardPrefix.length];

    if (text.length == 0) {
      return nil;
    }

    // Try to parse timestamp|url format
    NSRange separatorRange = [text rangeOfString:kPayloadSeparator];
    if (separatorRange.location != NSNotFound) {
      NSString *timestampStr = [text substringToIndex:separatorRange.location];
      NSString *url = [text substringFromIndex:NSMaxRange(separatorRange)];

      // Validate timestamp is numeric
      NSTimeInterval timestamp = [timestampStr doubleValue];
      if (timestamp > 0 && url.length > 0) {
        return @{
          @"url": url,
          @"rawValue": rawValue,
          @"clickedAt": @(timestamp),
        };
      }
    }

    // Legacy format: entire remaining text is the URL
    return @{
      @"url": text,
      @"rawValue": rawValue,
    };
  }

  // No prefix configured: treat entire text as URL
  return @{
    @"url": text,
    @"rawValue": text,
  };
}

#pragma mark - Validation

- (BOOL)isDomainAllowed:(NSString *)urlString {
  if (_configDomains.count == 0) {
    return YES;
  }

  NSURL *url = [NSURL URLWithString:urlString];
  NSString *host = url.host;
  if (!host) {
    return NO;
  }

  for (NSString *domain in _configDomains) {
    if ([host isEqualToString:domain] ||
        [host hasSuffix:[@"." stringByAppendingString:domain]]) {
      return YES;
    }
  }

  return NO;
}

#pragma mark - URL Metadata

- (NSDictionary *)parseUrlMetadata:(NSString *)urlString {
  NSURL *url = [NSURL URLWithString:urlString];
  if (!url) {
    return nil;
  }

  NSURLComponents *components = [NSURLComponents componentsWithURL:url resolvingAgainstBaseURL:NO];
  NSArray<NSURLQueryItem *> *queryItems = components.queryItems;
  if (!queryItems || queryItems.count == 0) {
    return nil;
  }

  NSMutableDictionary *metadata = [NSMutableDictionary dictionary];
  for (NSURLQueryItem *item in queryItems) {
    if (item.value) {
      metadata[item.name] = item.value;
    }
  }

  return metadata.count > 0 ? [metadata copy] : nil;
}

#pragma mark - Storage

- (void)markConsumed:(NSString *)url {
  NSUserDefaults *defaults = [[NSUserDefaults alloc] initWithSuiteName:kStorageSuiteKey];
  [defaults setBool:YES forKey:kConsumedKey];
  [defaults setObject:url forKey:kLastValueKey];
  [defaults setDouble:[[NSDate date] timeIntervalSince1970] forKey:kLastConsumedAtKey];
}

- (NSDictionary *)buildNotFoundResult {
  return @{
    @"found": @NO,
    @"source": @"none",
  };
}

#pragma mark - TurboModule

- (std::shared_ptr<facebook::react::TurboModule>)getTurboModule:
    (const facebook::react::ObjCTurboModule::InitParams &)params
{
    return std::make_shared<facebook::react::NativeDeferredLinkSpecJSI>(params);
}

@end
