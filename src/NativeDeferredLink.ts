import type { TurboModule } from 'react-native';
import { TurboModuleRegistry } from 'react-native';

export interface Spec extends TurboModule {
  configure(config: Object): void;
  getInitialDeferredLink(): Promise<Object>;
  clearConsumedDeferredLink(): Promise<void>;
}

export default TurboModuleRegistry.get<Spec>('DeferredLink');
