# Changelog

Notes for each version, in the words users see on the site's What's new page and in the GitHub
release. Write the next version under "Unreleased" as you go; `scripts/release.sh` turns that
section into the release. Bullets are English; an optional `### es` block carries the Spanish ones.
Lead each bullet with what it solves for the user (see "Writing for users" in CONTRIBUTING.md).

## 0.7.1 - 2026-10-21

### Headline
Blocks booked from a free gap end on the quarter hour.
Los bloques que armás desde un hueco libre terminan en el cuarto de hora.

- **Meetings end at a time people write.** Booking a gap at 3:46 now gives 3:46–4:15, not 3:46–4:16, and the arrows move to 4:00, 4:30 and so on.

### es
- **Las reuniones terminan en horarios redondos.** Si agendás un hueco a las 3:46, queda de 3:46 a 4:15 y no hasta 4:16, y las flechas lo mueven a 4:00, 4:30 y así.

## 0.7.0 - 2026-10-21

### Headline
Your free time in the agenda, and every meeting opens with the account you were invited with.
Tu tiempo libre en la agenda, y cada reunión se abre con la cuenta a la que te invitaron.

- **See your free time.** The agenda shows the gaps between meetings and before the first one (“free until 9:30”), and the one you're in counts down (“45m free until 3:30”). Hover a gap to turn it into focus, lunch or a meeting; focus and lunch show as busy to others. Turn it off in Settings › General.
- **Join with the right account.** With several Google accounts, Meet now opens with the one that was invited and, in Chrome, Brave, Edge or Vivaldi, in that account's profile. In Firefox you pick the profile for each account in Settings › General.
- **No more quitting by accident.** Quit now asks first, since alerts stop until you open Calenbar again.
- **The 5-minute flashes start on time.** They used to start while the menu bar still said “in 6m”.

### es
- **Tu tiempo libre, a la vista.** La agenda muestra los huecos entre reuniones y antes de la primera (“libre hasta 9:30”), y el hueco en el que estás va descontando (“45m libre hasta 3:30”). Pasá el puntero por un hueco para convertirlo en focus, almuerzo o reunión; focus y almuerzo les aparecen como ocupados a los demás. Se apaga en Ajustes › General.
- **Entrá con la cuenta correcta.** Si tenés varias cuentas de Google, Meet ahora se abre con la cuenta a la que te invitaron y, en Chrome, Brave, Edge o Vivaldi, en el perfil de esa cuenta. En Firefox elegís el perfil de cada cuenta en Ajustes › General.
- **No más salir sin querer.** Salir ahora pide confirmación, porque los avisos se cortan hasta que vuelvas a abrir Calenbar.
- **Los destellos de los 5 minutos llegan a tiempo.** Antes empezaban cuando la barra todavía decía “en 6m”.

## 0.6.1 - 2026-10-19

### Headline
The alert still comes if you opened the meeting early, and tidier buttons on the event card.
La alerta llega aunque hayas abierto la reunión antes, y botones más prolijos en la tarjeta del evento.

- **Joined early, still reminded.** Opening a meeting from Calenbar minutes before it starts often leaves you in the waiting room, or in another tab. The alert now stays quiet only when you joined within two minutes of the start.
- **Event card buttons.** Skip and Open in Calendar are proper buttons, lined up under Join.

### es
- **Entraste antes, igual te avisa.** Abrir una reunión desde Calenbar unos minutos antes suele dejarte en la sala de espera, o en otra pestaña. Ahora la alerta solo se calla si entraste dentro de los dos minutos previos al inicio.
- **Botones de la tarjeta del evento.** Omitir y Abrir en Calendario son botones de verdad, alineados debajo de Unirse.

## 0.6.0 - 2026-10-19

### Headline
Double bookings in plain sight, clocks that explain themselves, and a card on hover.
Dobles turnos a la vista, relojes que se explican solos, y una tarjeta al pasar el puntero.

- **Double bookings show up.** Meetings that share a time slot sit together in the list under “At the same time”, so you see the clash before it happens and pick one.
- **Hover the menu bar item** and the event's card appears: time, room, who's coming, Join. Off in Settings › Menu Bar if you prefer.
- **World clocks that explain themselves.** Type what your team says, “ET”, “PT”, “CET”, “UTC”, and the right zone comes up first. Each clock shows its short name (PDT, CEST, BST), its UTC offset, and a note when its clocks change within the month, with the offset you will have from then on. Arrows reorder them.
- **My Room.** Set your standing room (a fixed Meet, your Zoom personal meeting id) in Settings › General; New Meeting › My Room opens it with the link already on the clipboard.
- **Fixes.** A meeting a few days out gets its notification once it comes within a day. The test alert no longer silences a live one, and turning the alert off removes cards already on screen. A short meeting with “vacation” in its title no longer counts as a day off. Title width in Settings › Menu Bar now applies on MacBooks with a notch too.

### es
- **Los dobles turnos se ven.** Las reuniones que comparten horario van juntas en la lista bajo “A la misma hora”, así ves el choque antes de que pase y elegís una.
- **Pasá el puntero por el ítem de la barra** y aparece la tarjeta del evento: hora, sala, quién viene, Unirse. Se apaga en Ajustes › Barra de menús si preferís.
- **Relojes del mundo que se explican solos.** Escribí lo que dice tu equipo, “ET”, “PT”, “CET”, “UTC”, y la zona correcta aparece primero. Cada reloj muestra su nombre corto (PDT, CEST, BST), su desfase UTC y una nota cuando su horario cambia dentro del mes, con el desfase que vas a tener desde entonces. Las flechas los reordenan.
- **Mi sala.** Cargá tu sala fija (un Meet permanente, tu ID personal de Zoom) en Ajustes › General; Nueva reunión › Mi sala la abre con el link ya en el portapapeles.
- **Correcciones.** Una reunión de acá a unos días recibe su notificación cuando entra en las 24 horas. La alerta de prueba ya no silencia una real, y apagar la alerta quita las tarjetas que ya estaban. Una reunión corta con “vacaciones” en el título ya no cuenta como día libre. El ancho del título en Ajustes › Barra de menús ahora también aplica en MacBooks con notch.

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
