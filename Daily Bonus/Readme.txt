
Colors are configured in the translation file.
Entry in databases.cfg : " evd_bonus "


Solution for exclusion:
SQL:
// Exception reported: Failed on write row: Incorrect string value: '\xF0\x9F\x8C\x99' for column 'name' at row 1
// =>
ALTER TABLE `evdbonus` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

Requirements
Ядро плагина - [Shop] Core (Fork)
Ядро плагина - [VIP] Core

Variables
All settings via config
Commands
/bonus - Открыть меню

Installation
Unpack the archive and scatter the files into folders
Add an entry to databases.cfg
Setting up the config
Rebooting the server