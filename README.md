# 🔥 OnePlus 13T / 13S Custom Kernel Builder (SM8750)

Автоматическая сборка GKI-ядра (Android 15 / Linux 6.6) на последних исходниках **OnePlusOSS** для **OnePlus 13T** и **OnePlus 13S** с выборочной интеграцией патчей от [`epicmann24/android_kernel_common_oneplus_sm8750`](https://github.com/epicmann24/android_kernel_common_oneplus_sm8750).

## Возможности
- **Устройства:** только `OnePlus 13T` (`oneplus/sm8750_b_16.0.0_oneplus_13t`) и `OnePlus 13S` (`oneplus/sm8750_b_16.0.0_oneplus_13s`).
- **Автоподбор последней версии Root:** `BakaSU` (ReSukiSU), `SukiSU Nova` (SukiSU Ultra + KPM `patch_linux`) и `KernelSU Next`.
- **Автоподбор последнего SUSFS:** автоматическая синхронизация последнего коммита `gki-android15-6.6` из `simonpunk/susfs4ksu`.
- **Выборочные патчи перед запуском Action:**
  - `epicmann_patches`: включить/выключить патчи `epicmann24`.
  - `epicmann_filter`: `all` либо категории (`charging,thermal,haptics,wakelock,sched,mm,io,net,display`) или конкретные SHA-коммиты.
  - Переключатели `enable_kpm`, `enable_hmbird`, `enable_opt`, `enable_bbr3`, `enable_bbg`, `enable_ntsync`, `enable_ds`.
- **Брендинг ядра:** поле `kernel_uname` (по умолчанию `encoren` → `6.6.118-android15-encoren`).
