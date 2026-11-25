# 🔥 OnePlus 13T / 13S Custom Kernel Builder (SM8750)

Автоматическая сборка GKI-ядра (Android 15 / Linux 6.6) на последних исходниках **OnePlusOSS** для **OnePlus 13T** и **OnePlus 13S** с выборочной интеграцией патчей от [`epicmann24/android_kernel_common_oneplus_sm8750`](https://github.com/epicmann24/android_kernel_common_oneplus_sm8750).

## Возможности
- **Устройства:** только `OnePlus 13T` (`oneplus/sm8750_b_16.0.0_oneplus_13t`) и `OnePlus 13S` (`oneplus/sm8750_b_16.0.0_oneplus_13s`).
- **Автоподбор последней версии Root:** `BakaSU` (ReSukiSU), `SukiSU Nova` (SukiSU Ultra + KPM `patch_linux`) и `KernelSU Next`.
- **Автоподбор последнего SUSFS:** автоматическая синхронизация последнего коммита `gki-android15-6.6` из `simonpunk/susfs4ksu`.
- **NoMount:** переключатель `enable_nomount` по умолчанию включает драйвер из последнего стабильного релиза. ZIP метамодуля той же версии доступен отдельно в артефактах сборки. При включённом `make_release` он также добавляется в GitHub Release. Устанавливайте его через менеджер KernelSU.
- **BBRv3:** `enable_bbr3` встраивает алгоритм `bbr3` в ядро. Патчи Epicmann24, которые меняют файлы этого бэкпорта, пропускаются.
- **Выборочные патчи перед запуском Action:**
  - `epicmann_patches`: включить/выключить патчи `epicmann24`. При включённом SUSFS применяются после него и пропускают изменения в защищённых файлах, в том числе при выборе по SHA.
  - `epicmann_filter`: `all` либо категории (`charging,thermal,haptics,wakelock,sched,mm,io,net,display`) или конкретные SHA-коммиты. Автоматический режим берёт изменения форка после последнего импорта платформы. Патчи с конфликтами пропускаются целиком. Для `local_lock`, MGLRU и LZ4 используются реализации из исходников OnePlus.
  - Переключатели `enable_kpm`, `enable_hmbird`, `enable_opt`, `enable_bbr3`, `enable_bbg`, `enable_ntsync`, `enable_ds`.
- **Брендинг ядра:** поле `kernel_uname` (по умолчанию `encoren` → `6.6.118-android15-encoren`).
