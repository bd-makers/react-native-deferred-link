# @bdmakers/react-native-deferred-link

Deferred deep link recovery for React Native

## Installation

```sh
npm install @bdmakers/react-native-deferred-link
```

## Usage

```js
import { DeferredLink } from '@bdmakers/react-native-deferred-link';

// Configure (call once at app startup)
DeferredLink.configure({
  domains: ['your-domain.com'],
  appScheme: 'yourapp',
});

// Get deferred link on first launch
const result = await DeferredLink.getInitialDeferredLink();
if (result.found) {
  console.log('Deferred link URL:', result.url);
  console.log('Source:', result.source); // 'android_install_referrer' | 'ios_pasteboard'
}

// Clear consumed link
await DeferredLink.clearConsumedDeferredLink();
```

## Contributing

- [Development workflow](CONTRIBUTING.md#development-workflow)
- [Sending a pull request](CONTRIBUTING.md#sending-a-pull-request)
- [Code of conduct](CODE_OF_CONDUCT.md)

## License

MIT

---

Made with [create-react-native-library](https://github.com/callstack/react-native-builder-bob)
