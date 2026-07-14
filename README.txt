PHOTOS
------
Your photos live in `public/photos/` (already added, converted from HEIC to JPG).
To decide which photo appears where, edit `content/photos.ts`:
  • puzzlePhoto  → the hotel jigsaw puzzle
  • gallery[]    → the relationship timeline, welcome & finale screens

To swap a photo, drop a new .jpg into `public/photos/` and update the path in
content/photos.ts (or just overwrite an existing file with the same name).

MUSIC
-----
The background music plays straight from YouTube (no file needed). It's set in
components/MusicPlayer.tsx:
  • VIDEO_ID  — the YouTube video id (currently the song from your link)
  • START_AT  — where it starts, in seconds (currently 48 = 0:48)

  • Mobile browsers block auto-play with sound until the first screen tap, so on
    a phone the song begins the moment she taps (essentially immediately).
  • Needs an internet connection on the phone.
  • A floating mute button on every screen toggles it.
