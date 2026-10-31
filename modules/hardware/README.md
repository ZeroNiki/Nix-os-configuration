# Графика: Intel + NVIDIA

`nvidia.nix` — гибридная графика ноутбука: встроенная Intel Iris Xe показывает картинку, дискретная NVIDIA RTX 4060 (Max-Q / Mobile) включается по запросу (PRIME offload).

Модуль отдельный, а не в `hardware-configuration.nix`, потому что это выбор режима, а не автоопределение железа: генератор этого не напишет, а его вывод не должен затирать эти настройки.

## Что включено

| Опция | Значение | Зачем |
|---|---|---|
| `hardware.graphics.enable` | `true` | Mesa / OpenGL / Vulkan |
| `hardware.graphics.enable32Bit` | `true` | 32-битные библиотеки для Steam и Proton |
| `services.xserver.videoDrivers` | `[ "nvidia" ]` | подключает драйвер NVIDIA (модули ядра, библиотеки), нужен и под Wayland |
| `hardware.nvidia.open` | `true` | открытые модули ядра NVIDIA (для Turing и новее, RTX 4060 подходит) |
| `hardware.nvidia.package` | `nvidiaPackages.stable` | ветка драйвера под текущее ядро (`config.boot.kernelPackages`) |
| `hardware.nvidia.modesetting.enable` | `true` | KMS для `nvidia-drm` |
| `hardware.nvidia.powerManagement.enable` | `true` | сохранение состояния видеопамяти при сне |
| `hardware.nvidia.powerManagement.finegrained` | `true` | NVIDIA полностью засыпает, когда не нужна (важно для батареи) |
| `hardware.nvidia.nvidiaSettings` | `true` | GUI `nvidia-settings` |

## PRIME offload и `nvidia-offload`

Режим `prime.offload`: рабочий стол (dwl) и все программы рисуются на Intel, NVIDIA спит. Программа попадает на NVIDIA, только если её явно запустить через `nvidia-offload` (`enableOffloadCmd = true`). Скрипт выставляет `__NV_PRIME_RENDER_OFFLOAD=1`, `__NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0`, `__GLX_VENDOR_LIBRARY_NAME=nvidia`, `__VK_LAYER_NV_optimus=NVIDIA_only` и запускает команду.

```bash
nvidia-offload <команда> [аргументы]
# проверка: в строке "OpenGL renderer" должна быть NVIDIA (glxinfo в системе не установлен, берётся из mesa-demos)
nix shell --inputs-from /etc/nixos nixpkgs#mesa-demos -c nvidia-offload glxinfo -B
```

Steam: Свойства игры → Параметры запуска:

```
nvidia-offload %command%
```

Проверить, спит ли NVIDIA (`suspended` — спит, `active` — работает) и что на ней запущено:

```bash
cat /sys/bus/pci/devices/0000:01:00.0/power/runtime_status
nvidia-smi        # сам будит GPU на время запроса
```

### busId

`intelBusId = "PCI:0:2:0"`, `nvidiaBusId = "PCI:1:0:0"` — адреса видеокарт на шине PCI:

```bash
nix shell --inputs-from /etc/nixos nixpkgs#pciutils -c lspci -D | grep -E 'VGA|3D'   # lspci в системе не установлен
# 0000:00:02.0 VGA compatible controller: Intel ... Iris Xe Graphics          -> PCI:0:2:0
# 0000:01:00.0 VGA compatible controller: NVIDIA ... RTX 4060 Max-Q / Mobile  -> PCI:1:0:0
```

`lspci` выводит номера шины, устройства и функции в шестнадцатеричном виде, а `busId` ждёт десятичные: `01:00.0` → `PCI:1:0:0`. Менять нужно только на другом железе.

## Если графика не стартует

Отдельного пункта загрузки без NVIDIA (`specialisation.intel-only`) больше нет: он удваивал время вычисления каждой сборки и число записей в меню, а откатиться теперь всегда есть куда. После неудачного обновления драйвера — предыдущее поколение в меню systemd-boot или `Ctrl+Alt+F2` и `sudo nixos-rebuild switch --rollback` (см. [`Usage.md`](../../Usage.md#откат)). Если NVIDIA понадобится выключить надолго — временно `services.xserver.videoDrivers = [ "modesetting" ];`, `prime.offload.enable = false` и `boot.blacklistedKernelModules = [ "nvidia" "nvidia_drm" "nvidia_modeset" "nvidia_uvm" "nouveau" ];` в `nvidia.nix`.

## Внешний монитор и видеокарта

Разъёмы ноутбука подключены к разным видеокартам. Какой выход на какой карте:

```bash
for d in /sys/class/drm/card*-*; do
  c=${d##*/}; card=${c%%-*}
  echo "$c $(basename "$(readlink /sys/class/drm/$card/device/driver)") $(cat "$d/status")"
done
```

На этой машине: `eDP-1`, `DP-1`, `HDMI-A-1` — на Intel (`i915`), `DP-2`, `HDMI-A-2` — на NVIDIA (`nvidia`). Какому физическому порту какое имя соответствует, видно, если подключить монитор и снова выполнить команду (статус станет `connected`).

- **Монитор на разъёме Intel** работает как обычно, NVIDIA продолжает спать.
- **Монитор на разъёме NVIDIA** работает в обычной загрузке: dwl (wlroots) открывает обе видеокарты, рисует на Intel и передаёт кадры NVIDIA для вывода. Пока такой монитор подключён, NVIDIA не уснёт.
- Расположение и масштаб внешнего монитора задаёт kanshi, см. [`home/dwl`](../../home/dwl/README.md#мониторы).

## Смена режима

Другие режимы PRIME (`prime.sync`, `prime.reverseSync`) не настроены. Переключение — правка блока `hardware.nvidia.prime` в `nvidia.nix` (`offload.enable = false` и нужный режим), затем `nixos-rebuild build`, `sudo nixos-rebuild switch` и перезагрузка.
