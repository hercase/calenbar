# Changelog

Notes for each version, in the words users see on the site's What's new page and in the GitHub
release. Write the next version under "Unreleased" as you go; `scripts/release.sh` turns that
section into the release. Bullets are English; an optional `### es` block carries the Spanish ones.

## Unreleased

### Headline
Quieter notifications, and install from the terminal.

- Settings › Notifications says when macOS has notifications turned off for Calenbar, with a button to fix it.
- Install with Homebrew: `brew install --cask hercase/calenbar/calenbar` (trust the tap when asked).
- Up to five world clocks, and the same time zone can't be added twice.
- The full-screen alert shows the room, who organized the meeting and how many accepted, and counts down live. Snooze for 1, 5 or 10 minutes, or until the meeting starts.
- Settings › Menu Bar explains how to move the item next to the clock.
- Join the next meeting from anywhere with ⌃⌘J (change or remove it in Settings › General). Also in the menu bar item's right-click menu and the panel's ••• menu.
- When an update is waiting, the menu bar icon gets a dot and both menus offer “Update to…” or “Restart to Update”.
- Sharing your screen? Hide event titles and the menu bar says “Meeting • in 12m” until you turn it back on.
- Start a new Google Meet, Zoom or Microsoft Teams call from the panel's ••• menu.
- Time off and holidays stand out: a tinted day in the month view and an icon in the list, for events named Out of office, PTO or vacation, and for holiday calendars.
- Week numbers in the month calendar, optional.
- Fixed: after joining a meeting from Calenbar, the full-screen alert stayed quiet for any later meeting with the same link, including the same meeting moved to a later time. It now only skips the occurrence you joined.
- Settings › Calendars groups calendars by account, with a header row and a hint on each checkbox. Right-click a calendar to hide it from Calenbar in one go.

### es
- Ajustes › Notificaciones avisa cuando macOS tiene las notificaciones de Calenbar desactivadas, con un botón para arreglarlo.
- Instalación con Homebrew: `brew install --cask hercase/calenbar/calenbar` (confiá en el tap cuando lo pida).
- Hasta cinco relojes del mundo, y la misma zona horaria no se puede agregar dos veces.
- La alerta a pantalla completa muestra la sala, quién organiza y cuántos aceptaron, y la cuenta regresiva se actualiza. Posponer por 1, 5 o 10 minutos, o hasta que empiece.
- Ajustes › Barra de menús explica cómo mover el ítem junto al reloj.
- Entrá a la próxima reunión desde cualquier app con ⌃⌘J (cambialo o quitalo en Ajustes › General). También en el clic derecho del ítem y en el menú ••• del panel.
- Cuando hay una actualización esperando, el ícono de la barra muestra un punto y los dos menús ofrecen “Actualizar a…” o “Reiniciar para actualizar”.
- ¿Compartiendo pantalla? Ocultá los títulos y la barra dice “Reunión • en 12m” hasta que lo desactives.
- Iniciá una reunión nueva de Google Meet, Zoom o Microsoft Teams desde el menú ••• del panel.
- Los días libres y feriados se destacan: el día teñido en el mes y un ícono en la lista, para eventos llamados Out of office, PTO o vacaciones, y para calendarios de feriados.
- Números de semana en el calendario del mes, opcional.
- Corregido: después de entrar a una reunión desde Calenbar, la alerta a pantalla completa no aparecía para ninguna reunión posterior con el mismo link, incluida la misma reunión movida más tarde. Ahora solo omite la ocurrencia a la que entraste.
- Ajustes › Calendarios agrupa los calendarios por cuenta, con fila de encabezado y una ayuda en cada casilla. Clic derecho en un calendario para ocultarlo de Calenbar de una.

## 0.4.1 - 2026-10-16

### Headline
Quieter, and clearer when something's missing.

- The full-screen alert is now off by default. Turn it on in Settings › Notifications, and choose which screen it appears on.
- No alert for a meeting you already joined from Calenbar.
- If the Mac has no calendar account yet, the panel and the Calendars tab say so and open Internet Accounts.
- The Calendars tab explains its columns, with Add Account and Open Calendar buttons.
- The menu bar item keeps its place after screen recording or a relaunch.

### es
- La alerta a pantalla completa ahora viene apagada. Se activa en Ajustes › Notificaciones, y se elige en qué pantalla aparece.
- No hay alerta para una reunión a la que ya entraste desde Calenbar.
- Si la Mac todavía no tiene una cuenta de calendario, el panel y la pestaña Calendarios lo dicen y abren Cuentas de Internet.
- La pestaña Calendarios explica sus columnas, con botones Agregar cuenta y Abrir Calendario.
- El ítem de la barra conserva su lugar después de grabar pantalla o relanzar.
