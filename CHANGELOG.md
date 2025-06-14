# Changelog

> **Note:** This changelog has been moved from the script header into this `CHANGELOG.md` file.

| Version      | Date         | Notes                                                                                                                           |
|--------------|--------------|---------------------------------------------------------------------------------------------------------------------------------|
| **2025.6.1** | 14.06.2025   | Added full rollback on failure (cleanup of service, binary, config and cron); enforced root-only install check; moved config directory to `/etc/cloudflared`; enhanced installer prompts (cancel option, colourised prompts); updated updater script to use `wget` with baked-in architecture placeholder; improved cron management for auto-updates. |
| 2025.5.1     | 29.05.2025   | Introduced `print_info`/`print_error` functions; added ANSI-coloured output (green for instructions, red for errors); refactored messaging; added optional automatic update via cron. |
| 2024.12.2    | 23.12.2024   | Added back the Cloudflared Daemon auto-update – will make this optional next.                                                   |
| 2024.12.1    | 20.12.2024   | Modularised script functions.                                                                                                   |
| 2024.3.1     | 08.03.2024   | Script updates and improvements.                                                                                                |
| 2023.5.1     | 08.05.2023   | Maintenance and cleanup.                                                                                                        |
| 2022.11.1    | 09.11.2022   | Fixed typo for x86 installs.                                                                                                    |
| 2022.9.1     | 10.09.2022   | Added new Cloudflare web install option.                                                                                        |
| 2022.8.2     | 03.08.2022   | Updated Cloudflared updater.                                                                                                    |
| 2022.8.1     | 01.08.2022   | Updated script to check for packages.                                                                                           |
| 2022.7.2     | 27.07.2022   | Added support for OpenWrt_X86.                                                                                                  |
| 2022.7.1     | 02.07.2022   | Clean up script.                                                                                                                |
| 2022.6.10    | 25.06.2022   | Updated user messaging and tunnel name fix.                                                                                     |
| 2022.6.9     | 23.06.2022   | Added check if there is enough free space.                                                                                      |
| 2022.6.8     | 21.06.2022   | Multiple formatting updates.                                                                                                    |
| 2022.6.3     | 21.06.2022   | Script cleanup.                                                                                                                 |
| 2022.6.2     | 20.06.2022   | Script fixes and updates.                                                                                                       |
| **1.0**      |              | Initial Release.                                                                                                                |
