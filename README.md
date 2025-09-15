# ATM10 Draconic Reactor Controller (CC:Tweaked)

Controlador seguro, modular y **sin tocar el reactor** (todo por **módem cableado**), compatible con ATM10 (MC 1.20.x). Regula **dos flux gates**: uno de **entrada** (mantener campo) y uno de **salida** (mantener saturación o alcanzar una **generación objetivo**). Incluye asistente **SETUP** en pantalla y **failsafes**.

## Requisitos
- CC:Tweaked
- Draconic Evolution (reactor + 2 flux gates)
- Monitor avanzado 3×3
- Módems **con cable** en el reactor (stabilizer), ambos flux gates, monitor y ordenador

## Instalación (3 opciones)
### A) Con Pastebin (recomendado para usuarios)
1. Sube `pastebin_bootstrap.lua` a Pastebin y copia su **ID**.
2. En el ordenador de CC, ejecuta:
   ```
   pastebin run <PASTEBIN_ID>
   ```
   Esto descargará `installer.lua` desde este repo y hará la instalación.

### B) Con `wget run` directamente desde GitHub
```
wget run https://raw.githubusercontent.com/TuShaggy/posta/main/installer.lua
```

### C) Manual
- Copia `startup.lua` a `/startup.lua`
- Copia `lib/f.lua` a `/lib/f.lua`

## Cableado (no-touch)
```
[Computer]──(wired modem)──[Flux Gate IN]──> Reactor Injector
          └─(wired modem)──[Flux Gate OUT]──> Stabilizer/Core side
          └─(wired modem)──[Monitor 3x3]
          └─(wired modem)──[Reactor Stabilizer]
```
> Ningún bloque necesita estar físicamente pegado al reactor; todo via módem.

## Primer arranque
- El HUD mostrará arriba **SETUP** (botón **siempre visible**). Toca SETUP para mapear reactor, monitor, y puertas **IN/OUT** si tienes >2 gates en red.
- Con 2 gates exactos, el sistema intenta **auto-calibrar** (identificar IN/OUT con un “nudge” seguro). Si no puede, usa SETUP.
- El mapeo se guarda en `config.lua`.

## UI (HUD)
- Arriba izq.: estado del reactor, nombres mapeados (reactor/monitor/gates)
- Arriba der.: botones **MODE: SAT/GEN** y **SETUP**
- Centro: generación y temperatura
- Barras: **Energy Saturation** y **Field Strength**
- Abajo: dos filas de botones
  - Fila `my-1` → **OUT** (<<< << <  OUT:AU/MA  > >> >>>)
  - Fila `my`   → **IN**  (<<< << <  IN:AU/MA   > >> >>>)

## Modos de control de salida
- **SAT (por defecto):** ajusta el flux gate de salida para mantener `TARGET_SAT` (%).
- **GEN:** ajusta salida para alcanzar `TARGET_GEN_RFPT` (RF/t). 
  - Cambia `TARGET_GEN_RFPT` en `startup.lua`.
  - Usa histéresis `DB_GEN` (porcentaje alrededor del objetivo) para estabilidad.

## Failsafes
- **Campo < `FIELD_LOW_TRIP`%** → parar, pasar a **charge**, **IN=CHARGE_FLOW**, **OUT=0**.
- **Temp > `TEMP_MAX`** → parar y minimizar OUT.
- **Auto-rearme** cuando temp < `TEMP_SAFE`.

## Config rápida (ejemplo con tus nombres)
Crea o edita `/config.lua` si quieres fijar nombres manualmente:
```lua
return {
  reactor = "draconic_reactor_1",
  monitor = "monitor_5",
  in_gate = "flow_gate_4",
  out_gate = "flow_gate_9",
}
```

## Troubleshooting
- **No se detecta reactor/monitor/gates** → revisa módems cableados y que `http` esté habilitado en CC.
- **El HUD no responde al tacto** → asegura que es **monitor avanzado** y que tocas en las coordenadas del botón.
- **Oscilaciones** (flujo sube/baja mucho) → baja `IN_KP/IN_KI` o `OUT_KP/OUT_KI`, o aumenta `DB_FIELD/DB_SAT/DB_GEN`.
- **Demasiado calor** con modo GEN → sube objetivo de saturación o baja `TARGET_GEN_RFPT`. El control aplica recorte de salida si `Temp > 7000`.

## Créditos
- Inspirado en el clásico `drmon` de acidjazz; esta implementación es una reescritura para 1.20.x con auto-discovery, asistente y control PI doble.

---

### Comandos útiles de CC
- Ver periféricos: `peripherals` o `lua print(textutils.serialize(peripheral.getNames()))`
- Reiniciar: `reboot`
