# Android device pass (audit item 12)

_Prepared 2026-09-17 from `docs/audit-2026-09-16.md`. The audit walked every
screen on the iPhone 17 simulator only. This list is what a person with an
Android phone checks. Tick each line, write "fail" plus one line of what you
saw, and paste the result as a comment on the brain task "Act on the
jackdaw-mobile audit" (tag `mantle-roadmap`)._

## 0. Set up

- [ ] Phone: USB debugging on. `adb devices` shows it.
- [ ] Build and install the release build (debug key signs it when
      `android/key.properties` is absent; that is fine for this pass):

  ```bash
  cd ~/Projects/mantle-mobile && fvm flutter run --release
  ```

- [ ] Note the phone model and Android version here: ______
- [ ] Sign in to the dev brain. Type the credentials yourself.

## 1. Install and first run

- [ ] Splash is brand brown on light and on dark. No white flash.
- [ ] Launcher icon is the badge on brown (adaptive icon).
- [ ] First screen asks for the server. An `http://` address to a public
      host shows the warning; `https://` passes.
- [ ] Login lands on Home. Tiles, stats and the server card fill.

## 2. Push on a real device (audit "Needs a human")

Send yourself a message from the web app or another agent for each line.

- [ ] Opening Events or Settings the first time shows the rationale sheet
      BEFORE the Android notification prompt. "Not now" is remembered.
- [ ] App in the background: notification arrives, shows the decrypted text.
- [ ] App killed (swipe away): notification still arrives.
- [ ] Phone locked: the lock screen shows the decrypted text, not a
      placeholder.
- [ ] Tap the notification: the right agent thread opens.
- [ ] Push Reset in Settings asks to confirm, then a new message still
      arrives.

Direct push (the no-Google path), if this phone can use it:

- [ ] Turn it on in Settings. The foreground-service notification appears.
- [ ] Reboot the phone. The service comes back on its own.
- [ ] Sign out. The service stops and its notification goes.

## 3. Alarms on a real device

- [ ] Add an event with a reminder 2 minutes ahead. Lock the phone. The
      alarm fires on time with the phone locked.
- [ ] Android 12+: the exact-alarm permission prompt appears once. Deny it,
      make another event: the reminder still fires, possibly a little late
      (inexact fallback).
- [ ] Edit the reminder lead on an event: the new time fires, the old one
      does not.
- [ ] Delete an event with a reminder: nothing fires.
- [ ] Reboot with a reminder pending: it still fires after the reboot.

## 4. Software keyboard on the four capture screens

The simulator used the Mac keyboard, so none of this was seen.

Chat

- [ ] The composer stays above the keyboard. Nothing is hidden.
- [ ] The field grows to several lines and stays visible.
- [ ] Keyboard "send" sends once. A second send during a reply is refused.

Notes

- [ ] The quick-add row stays above the keyboard.
- [ ] Scroll the list with the keyboard open: the last note is reachable.
- [ ] The edit sheet scrolls; the field is not cut by the keyboard.

Tasks

- [ ] Quick-add row above the keyboard; last task reachable.
- [ ] The edit sheet with due date and priority fits above the keyboard.

Journal

- [ ] The composer stays above the keyboard (audit bug 7).
- [ ] The field grows to four lines and stays visible.
- [ ] Voice: hold to record, release, the text arrives.

Search

- [ ] Type, then scroll the results: the last hit is reachable.
- [ ] Scrolling closes the keyboard.

## 5. Chat

- [ ] Date dividers and the time under a bubble look right.
- [ ] Scroll up: the jump button appears. Tap: it lands at the bottom.
- [ ] Attach a document with the file picker (`file_picker` 13, the pin is
      gone): the system picker opens, the file attaches, the send works.
- [ ] Files: upload a document through the same picker.
- [ ] Attach a photo from the gallery: it sends. Tap it: full screen.
- [ ] Airplane mode on, send: the message queues. Airplane mode off: it
      goes out.
- [ ] Stop during a streaming reply: the reply stops.
- [ ] Long-press a bubble: the sheet shows the full time stamp and Copy works.

## 6. Android back button and gestures

- [ ] Back from a sheet closes the sheet, not the screen.
- [ ] Back from a thread goes to the inbox, then Home, then exits.
- [ ] Back after a deep link from a notification goes somewhere sensible,
      not to a blank screen.
- [ ] Predictive back (Android 14+) does not show a broken frame.

## 7. Touch and screen readers

- [ ] Set the font size and display size to the largest. Events time
      column, Notes edit sheet and Settings rows do not overflow.
- [ ] TalkBack on: header icons announce their labels. Every icon-only
      button has a name.
- [ ] Every small control (done circles, chips, chevrons) is easy to hit.

## 8. Landscape and safe areas

- [ ] Rotate on Chat: bubbles keep a sane width; composer is not too tall.
- [ ] Rotate on Pages, Notes, Tasks, Search, Files: the rows between the
      header and the list keep side insets (no text under the camera cut-out).

## 9. Settings identity and sign out

- [ ] Card shows the server, the signed-in email, app version and server
      version.
- [ ] Change server asks first. Cancel keeps you signed in.
- [ ] Clear cache asks first, then an open thread reloads.
- [ ] Sign out asks first. After it: no notification arrives for the old
      account, and Events shows no alarms.

## 10. Location and Files

- [ ] Turn on location sharing in Settings: the permission prompt appears,
      a sent message carries the location.
- [ ] Files: browse folders, upload a document through the picker, open an
      image preview.
- [ ] Files: tap a PDF, then **Open**. Progress shows, then the phone's PDF
      viewer (or an "open with" chooser) opens the file under its real name.
- [ ] Same for a Word or Excel file and a video. A type nothing on the phone
      opens (try a `.step` or `.bin`) falls back to the share sheet and the
      sheet says so.
- [ ] **Share** on any file offers the share sheet with the file attached.
- [ ] A file over 100 MB shows "Download … MB and open"; Cancel mid-download
      returns to the buttons and leaves nothing behind.
- [ ] On a page, a file chip that is not an image opens the same sheet.
- [ ] Sign out, sign back in: opening the same file downloads it again (the
      cache went with the session).
- [ ] App info → Permissions lists no storage, photos or videos permission.

## 11. Theme

- [ ] Follow-system switches light and dark with the phone setting.
- [ ] Random theme changes the theme; status colours stay readable on it.

## Results

Paste the failed lines with one sentence each on the brain task. Anything
green needs no comment.
