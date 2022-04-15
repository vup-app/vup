# Vup Changelog

## Beta 0.10.0

- New advanced sharing features (with future changes and read+write)
- New and improved drag and drop system
- The ffmpeg installer now also works on Windows
- Fixed high idle CPU usage on Windows
- Added media file picker for iOS
- Added tool to list used MySky paths
- Improved video thumbnail extraction
- Improved Jellyfin folder navigation
- Added settings page to manage SkyFS mounts
- Added support for 3D model thumbnails (requires OpenSCAD to be installed)
- Added support for PDF thumbnails (requires ImageMagick to be installed)
- Added support for SVG thumbnails (requires Inkscape to be installed)
- The image grid view now shows progress bars and offline status for files
- Disable integrated audio player by default
- Improved DirectoryIndex cache efficiency
- Fixed some bugs

## Beta 0.9.0

- BREAKING: Changed Jellyfin server id format to support additional clients. Clear the data or log out in all of your Jellyfin clients after upgrading to the new Vup version.
- Full support for portal-login-with-MySky! You can link your existing portal accounts to your MySky account and then one-click login on all of your devices. Vup automatically creates a skynetfree.net account for new users.
- Completely revamped actions system: All right-click/long-press actions are now more powerful, consistent and safe. This also includes a lot of new features, like making multiple files available offline at once
- Added `DirectoryCacheSyncService` (makes multi-device usage a lot more efficient)
- Added `TemporaryStreamingServerService`
- Added button to upload and share logs in settings (Useful for Android and iOS)
- Added support for "mixed" Jellyfin collections
- Added experimental Cast support
- Improved task progress system (for example dropped files now show up instantly)
- Added new "Devices" settings page which shows a list of devices you use Vup on
- Improved EXIF metadata extraction for images (datetime and gps)
- Added backspace key for navigation
- Added iOS permissions to pick and upload all file types
- Updated macOS icon
- Added some new experimental yt-dlp features
- Fixed some bugs

## Beta 0.8.7

- the portal auth settings page now shows the current portal and stats
- web server: directories and files are now sorted by name
- Jellyfin: fixed movie sort order
- the pin tool now shows a success dialog when done
- added draggable scrollbar for large directories on mobile
- files can now be saved locally on Android and iOS
- the portal sign in form can now be submitted with enter
- existing directories are now merged when using drag 'n drop
- fixed yt-dlp default video resolution
- fixed bug when browsing shared directories
- fixed OMDb metadata provider not adding movie poster in some cases
- fixed some Android bugs

## Beta 0.8.6

- New cache manager with max cache size setting
- You can now use Skynet portals without accounts support
- Text field borders are now visible when using a dark theme
- A lot of bug fixes

## Beta 0.8.0

- Improved Jellyfin media server settings page
- Added powerful metadata support and assistant for TV shows and movies (supported providers: TVmaze, OMDb and AniList)
- Added full subtitle support for movies and videos
- All activity is now synced across all of your devices! (play positions, play counts and last played dates - fully end-to-end-encrypted)
- Custom playlists are now synced across all of your devices (end-to-end-encrypted)
- Added metadata support for .mov, .avi and .wmv video files
- New option to not show full path in tabs title
- Vup now remembers view type (list, grid, gallery) and sort options for every directory
- File and directory selections are cleared when navigating to a different location
- File metadata can now be manually edited in the file details dialog
- New ffmpeg installer for Linux and Windows (ffmpeg is already included on all other platforms)
- Added full metadata and thumbnail support for .epub books and .cbz comics
- Vup now serves two different web-based Jellyfin frontends
- WebDav server: fixed rclone sync retry issue and set modified times correctly
- Automatic chunk retry for large uploads
- Auto retry for failed chunks when streaming
- The integrated Jellyfin server now supports changing client preferences like dark mode
- Added automatic cache cleaner which removes old cache files
- Added "Launch at startup" setting
- Vup now uses a custom user agent, so Skynet portals can easily see who is using Vup (this is not leaking any information)
- Upgraded to latest Flutter version
- Jellyfin media collections are now shown in the sidebar
- Fixed profile flickering issue
- Fixed german language bug
- Fixed issue with non-ascii sync directories
- A lot of other bug fixes and improvements

## Beta 0.7.9

- new portal selection and login dialog
- hover over usage bar shows portal account limits
- Updated Jellyfin music support: browse by directory, create playlists, sort by most played, ...
- Jellyfin shows resumable videos (movies and shows)
- right-click -> pin all
- thumbnail load delay for fast scrolling
- 1000+ thumbnail fix

## Beta 0.7.7

- Custom Skynet portal support
- Support for auth-only portals
- Experimental support for Portal-Login-with-MySky
- Used storage in your portal account now shown in the sidebar
- Dialog for new users to create some common home directories automatically
- New and improved YT-DLP integration (selection of what to download with preview images, smart select, progress indicators)
- Integrated Jellyfin-compatible server for streaming music, podcasts, audiobooks and movies (better support for TV shows coming later)
- Tool to check for any unpinned files and pin them to your portal account
- Multiple tabs
- New directory actions (right-click or long press): Open in new tab, Rename, Add to Quick Access, Move to trash
- New file actions (right-click or long press): Copy Web Server URL, Rename, Make available offline
- New dialog that shows previous versions of a file and makes it possible to restore them
- New file details dialog
- Pin directories to the quick access sidebar area
- Custom window design
- Minimize to tray on desktop platforms
- Double-click to open on desktop platforms
- Multi-select files when holding CTRL
- CTRL+A shortcut to select everything in current dir
- Option to start Vup minimized
- Improved audio, video and image metadata view
- Delete files and directories permanently (does not unpin yet)
- New app icon
- Support for custom color themes (synced between all devices)
- Support for custom fonts
- multi-select actions (select all, unselect all, invert selection, share all, copy all, move all, move to trash)
- improved metadata extraction (ffmpeg is now used for all videos and music)
- thumbnails for all videos are now generated automatically
- Improved sync progress indicator
- global clipboard to move and copy multiple files or directories
- Linux: Integrated installer and updater
- Android: Background service for web, WebDAV and Jellyfin server
- New experimental column view
- Option to watch opened files for changes and automatically upload them
- Improved sharing system
- Improved thumbnail image cache
- Improved MIME type handling
- bind ip options for all integrated servers (localhost by default)
- Disabled global audio, video and image indexer (use Jellyfin instead)
- All logs are now written to a temporary log file to make debugging easier
- New hooks/tasks/workflows/scripts automation system
- Changed default chunk size to 1 MB (instead of 1 MiB)
- Streamed music files are now automatically stored offline after listening to them once
- Added logout button
- Folders are now called directories consistently
- Fixed a ton of bugs


## Beta 0.6.0

- Added new search with global and recursive option and a simple filter for file system entity types
- Added auto sync on all platforms (with user-defined intervals)
- Added "realtime" sync for desktop platforms (highly experimental)
- Added support for a split-screen view
- Added multi file and directory selection
- Added Koel Server
- Added Trash feature
- Sharing links can now be opened on Android from any other app or browser
- Improved directory listing performance (faster, uses a lot less bandwidth)
- Metadata now contains both sha256 and sha1 hashes (can be used with rclone sync, set the vendor setting to `nextcloud`)
- Improved upload progress indicator
- Added new settings page to manage media file indexes
- Added storage quota indicator (uses test data atm)
- Improved App Layout
- Ensure only one instance of Vup is running at once
- APK files can now be installed from Vup
- Polished the web server UI
- Added feature to save files locally
- Added button to delete locally saved files
- Improved data storage paths on all platforms
- Directories are now supported for drag and drop
- Improved sharing experience
- Updated file+folder icons
- JSON Debug info can now be selected and copied
- Fixed a lot of bugs
