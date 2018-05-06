# Mapchooser-Redux
  
Build Status: [![Build Status](https://travis-ci.org/Kxnrl/Mapchooser-Redux.svg?branch=master)](https://travis-ci.org/Kxnrl/Mapchooser-Redux)
  
  
### Features  
* Vote next map  
* Rock the vote to change map or extend map  
* Nominate map to vote pool
* Map attributes  
* Arms Fix (for custom models)
  
  
### ConVars  
- **mcr_timer_location**  - Timer Location of HUD.  
- **mcr_csgo_arms_fix**   - Enable arms fix.  
- **mcr_old_maps_count**  - How many maps in cooldown list.  
- **mcr_delete_offical**  - Auto-delete offical maps. 
- **mcr_include_nametag** - Include name tag in map desc.  
  
  
### Configs
* map pool in mapcycle.txt by default, you can edit it in 'addons/sourcemod/configs/maplist.cfg'
* map data 'addons/sourcemod/configs/mapdata.txt' 
* if mapdata.txt does not exists, data will be auto-generated  [example](https://github.com/CSGOGAMERS-Community/CG-Server/blob/master/ZombieEscape/mapdata.txt)  
* if you need arms fix, add "+mapgroup custom_maps" into command line.
  
  
### Credit  
[Alliedmodders](https://github.com/alliedmodders) - Developed the original Mapchooser.  
[powerlord](https://github.com/powerlord/sourcemod-mapchooser-extended) - Developed the original Mapchooser Extended.  
