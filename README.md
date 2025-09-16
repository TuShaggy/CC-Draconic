📜 README.md
# ⚡ ATM10 Draconic Reactor Controller (v2.0)

Controlador seguro y modular para el **Draconic Reactor** usando **CC:Tweaked**.  
Diseñado para ATM10 (MC 1.20.x), compatible también con ATM9 y otros packs.  

Versión **2.0** → modular, interfaz minimalista, animación de inicio,  
setup gráfico en el monitor, botón de encendido/apagado y más modos de control.

---

## 🚀 Instalación rápida

**Instalar todo con `installer.lua`:**
bash
wget run https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/installer.lua
reboot


Actualizar sin perder configuración (usa installer.lua de nuevo):

wget run https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/installer.lua
reboot


Actualizar forzando limpieza total (update.lua, borra config):

wget run https://raw.githubusercontent.com/TuShaggy/CC-Draconic/main/update.lua
reboot


Instalación manual (avanzado):

Copia los ficheros del repo a / y lib/ en tu ordenador de CC.

Archivos requeridos:

startup.lua

reactor.lua

setup.lua

ui.lua

lib/f.lua

📂 Estructura de ficheros
/ (root)
 ├─ startup.lua      → Entrypoint, carga módulos
 ├─ reactor.lua      → Lógica del reactor (encendido/apagado, info)
 ├─ setup.lua        → Asistente gráfico para mapear periféricos
 ├─ ui.lua           → Interfaz de usuario (HUD minimalista)
 ├─ lib/
 │   └─ f.lua        → Helpers (clear, beep, format, etc)
 ├─ installer.lua    → Instala/actualiza sin borrar config
 ├─ update.lua       → Fuerza actualización completa (incluye config.lua)
 └─ VERSION          → Número de versión actual

📊 Funciones principales

Animación de inicio con barra de carga y sonidos (si hay altavoz conectado).

Setup gráfico → selecciona periféricos (Reactor, Monitor, Flux Gates) directamente en el monitor.

HUD minimalista → estado claro y limpio del reactor: SAT, Field, Generación, Temperatura.

Botón POWER → enciende o apaga el reactor desde el HUD.

Pestaña CTRL → modos de operación (SAT, MAXGEN, ECO, TURBO, PROTECT).

Pestaña HUD → elegir estilo visual de los botones (Circle, Hex, Rhombus, Square).

Failsafe básico → si faltan periféricos, muestra advertencia en pantalla.

🔧 Configuración

El mapeo de periféricos se guarda en config.lua tras el Setup gráfico:

return {
  reactor = "draconic_reactor_1",
  monitor = "monitor_5",
  in_gate = "flow_gate_4",
  out_gate = "flow_gate_9",
  hud_style = "CIRCLE"
}


Para resetearlo → borra config.lua y reinicia.

Para actualizar sin perder config → usa installer.lua.

Para resetear todo (incluido config) → usa update.lua.

🖥️ Requisitos

CC:Tweaked

Draconic Evolution (reactor + 2 flux gates)

Monitor avanzado (mínimo 3×3 recomendado)

Módem cableado en todos los periféricos

Opcional: Speaker para sonidos de alerta y animación

🛠️ Troubleshooting

No se detecta reactor/monitor/gates → revisa módems cableados.

Botones no responden → asegúrate de que el monitor es avanzado y estás tocando dentro de la zona.

El reactor no enciende → revisa que esté cargado (50% field y 100% saturation) antes de presionar POWER.

Quiero volver a empezar → borra config.lua o usa update.lua.

📑 Documentación adicional

CHANGELOG.md → historial de cambios y mejoras por versión.

VERSION → contiene solo el número de versión actual (ej: 2.0).

📜 Créditos

Inspirado en drmon de acidjazz
.

Reescrito y actualizado para ATM10 con interfaz gráfica, modularidad y mejoras.
