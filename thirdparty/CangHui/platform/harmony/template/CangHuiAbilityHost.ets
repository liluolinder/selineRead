export type CangHuiHostEnvironment = {
  safeArea: { top: number; right: number; bottom: number; left: number };
  colorMode: 'light' | 'dark'; fontScale: number; lifecycleEpoch: number;
};

// Ability adapters call these methods from their native lifecycle. The template intentionally does
// not name a product Ability, bundle, permission or router.
export interface CangHuiAbilityLifecycle {
  onForeground(environment: CangHuiHostEnvironment): void;
  onEnvironmentChanged(environment: CangHuiHostEnvironment): void;
  onBackground(lifecycleEpoch: number): void;
  onDestroy(lifecycleEpoch: number): void;
}
