# Changelog

Notes for each version, in the words users see on the site's What's new page and in the GitHub
release. Write the next version under "Unreleased" as you go; `scripts/release.sh` turns that
section into the release. Bullets are English; an optional `### es` block carries the Spanish ones.

## Unreleased

- Rest the pointer on the menu bar item and the event's card appears: time, room, who's coming, Join. Off in Settings › Menu Bar if you prefer.
- Busy days show at a glance: the fill behind each day number gets stronger with the number of meetings, light, busy, packed. Holidays and days off are written in the accent colour.
- The "Update available" pill in the panel is easier to see.
- World clocks: type what your team says, “ET”, “PT”, “CET”, “UTC”, and the right zone comes up first.
- New Meeting › My Room: set your standing room (a fixed Meet, your Zoom personal meeting id) in Settings › General, and it opens with the link already on the clipboard.
- Paste, copy, cut, select all and undo now work in the Settings text fields (⌘V, ⌘C, ⌘X, ⌘A, ⌘Z), and ⌘W closes the window.

### es
- Apoyá el puntero en el ítem de la barra y aparece la tarjeta del evento: hora, sala, quién viene, Unirse. Se apaga en Ajustes › Barra de menús si preferís.
- Los días cargados se ven de un vistazo: el fondo detrás de cada número se intensifica con la cantidad de reuniones, tranquilo, cargado, imposible. Los feriados y días libres van escritos en el color de acento.
- El aviso "Actualización disponible" del panel se ve mejor.
- Relojes del mundo: escribí lo que dice tu equipo, “ET”, “PT”, “CET”, “UTC”, y la zona correcta aparece primero.
- Nueva reunión › Mi sala: cargá tu sala fija (un Meet permanente, tu ID personal de Zoom) en Ajustes › General, y se abre con el link ya en el portapapeles.
- Pegar, copiar, cortar, seleccionar todo y deshacer ya funcionan en los campos de texto de Ajustes (⌘V, ⌘C, ⌘X, ⌘A, ⌘Z), y ⌘W cierra la ventana.

## 0.5.0 - 2026-10-16

### Headline
A shortcut to join, an alert that doesn't take over, and days off on the calendar.
Un atajo para entrar, una alerta que no tapa todo, y los días libres en el calendario.

- **⌃⌘J joins the next meeting from any app.** Change or remove the shortcut in Settings › General. The same action is in the menu bar item's right-click menu and the panel's ••• menu.
- **The alert is a small card now.** It appears in a corner of the screen when a meeting starts, over every desktop and full-screen app, with a live countdown, the room, who's coming, Join and Snooze (1, 5 or 10 minutes, or until it starts). Overlapping meetings stack their cards. Full screen is still there as a choice. Both styles leave on their own when the meeting ends.
- **Try before you decide.** Settings › Notifications has “Send Test Notification” and “Show Test Alert”.
- **Days off on the calendar.** Time off (Out of office, PTO, vacation and their equivalents in nine languages) and holiday calendars tint their days in the month view and get an icon in the list.
- **How busy is that day.** One, two or three dots under each day, and optional week numbers.
- **Calendars, by account.** Settings › Calendars groups them by account; unchecking List drops a calendar from Calenbar in one click, and the ••• button hides it, shows it everywhere or marks it as a holidays calendar.
- **Mirrored events show once.** A personal event copied into a work calendar is one row, even when the copy says just “Busy” or carries a tag; the card names the other calendar.
- **Sharing your screen?** Hide event titles and the menu bar says “Meeting • in 12m” until you turn it back on.
- **New meeting, now.** Start a Google Meet, Zoom or Microsoft Teams call from the panel's ••• menu.
- **Updates you can see.** When one is waiting, the menu bar icon gets a dot and both menus offer “Update to…” or “Restart to Update”.
- **No Accessibility permission.** On displays without a notch, the title width is Automatic (it learns how much room your apps leave) or Short, Medium or Long.
- Up to five world clocks, with no duplicates. Settings › Notifications says when macOS has notifications turned off for Calenbar. Install with Homebrew: `brew install --cask hercase/calenbar/calenbar --no-quarantine`.

### es
- **⌃⌘J entra a la próxima reunión desde cualquier app.** Cambiá o quitá el atajo en Ajustes › General. La misma acción está en el clic derecho del ítem de la barra y en el menú ••• del panel.
- **La alerta ahora es una tarjeta chica.** Aparece en una esquina de la pantalla cuando empieza una reunión, sobre todos los escritorios y apps a pantalla completa, con cuenta regresiva, la sala, quién viene, Unirse y Posponer (1, 5 o 10 minutos, o hasta que empiece). Las reuniones superpuestas apilan sus tarjetas. Pantalla completa sigue como opción. Las dos se van solas cuando termina la reunión.
- **Probá antes de decidir.** Ajustes › Notificaciones tiene “Enviar notificación de prueba” y “Mostrar alerta de prueba”.
- **Días libres en el calendario.** Los días libres (Out of office, PTO, vacaciones y sus equivalentes en nueve idiomas) y los calendarios de feriados tiñen sus días en el mes y llevan un ícono en la lista.
- **Qué tan cargado está el día.** Uno, dos o tres puntos debajo de cada día, y números de semana opcionales.
- **Calendarios, por cuenta.** Ajustes › Calendarios los agrupa por cuenta; desmarcar Lista saca un calendario de Calenbar con un clic, y el botón ••• lo oculta, lo muestra en todos lados o lo marca como calendario de feriados.
- **Los eventos reflejados aparecen una vez.** Un evento personal copiado al calendario de trabajo es una sola fila, aunque la copia diga solo “Ocupado” o lleve una etiqueta; la tarjeta dice en qué otro calendario está.
- **¿Compartiendo pantalla?** Ocultá los títulos y la barra dice “Reunión • en 12m” hasta que lo desactives.
- **Reunión nueva, ya.** Iniciá una llamada de Google Meet, Zoom o Microsoft Teams desde el menú ••• del panel.
- **Actualizaciones que se ven.** Cuando hay una esperando, el ícono de la barra muestra un punto y los dos menús ofrecen “Actualizar a…” o “Reiniciar para actualizar”.
- **Sin permiso de Accesibilidad.** En pantallas sin notch, el ancho del título es Automático (aprende cuánto lugar dejan tus apps) o Corto, Medio o Largo.
- Hasta cinco relojes del mundo, sin duplicados. Ajustes › Notificaciones avisa cuando macOS tiene las notificaciones de Calenbar desactivadas. Instalación con Homebrew: `brew install --cask hercase/calenbar/calenbar --no-quarantine`.

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
