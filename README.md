# Mapchooser-Redux
  
  
|Build Status|Download|
|---|---
|[![Build Status](https://img.shields.io/travis/Kxnrl/Mapchooser-Redux/master.svg?style=flat-square)](https://travis-ci.org/Kxnrl/Mapchooser-Redux?branch=master) |[![Download](https://static.kxnrl.com/images/web/buttons/download.png)](https://build.kxnrl.com/MapChooser-Redux/)  

  
  
### Features  
* Vote next map  
* Rock the vote to change map or extend map  
* Nominate map to vote pool
* Map attributes  
* Party block
  
  
### ConVars  
- **mcr_timer_location**  - Timer Location of HUD.  
- **mcr_include_nametag** - Include name tag in map desc.  
- **mcr_include_desctag** - Include desc tag in map desc.
- **mcr_rectplayed_interval** - How much time in hours ago played can count to recently played pool, (-1 disable all recently played function.  
- **mcr_rectplayed_ltp_mtpl** - What percentage increase of nomination map price for recently played.  
- **mcr_partyblock_enabled** - Enable or not party block fuction.
- **mcr_map_extend_times** - How many times can extend the map.  
- **mcr_delete_offical**  - Auto-delete offical maps.  
- **mcr_generate_mapcycle** - Auto-generate map list in mapcycle.txt.  
- **mcr_generate_mapgroup** - Auto-generate map group in gamemodes_server.txt.  
  
  
### Configs
* map pool in mapcycle.txt by default, you can edit it in 'addons/sourcemod/configs/maplist.cfg'
* map data 'addons/sourcemod/configs/mapdata.txt' 
* if mapdata.txt does not exists, data will be auto-generated  [example](https://github.com/PuellaMagi/Server-Data/blob/master/ZombieEscape/mapdata.txt)  
  
  
### Credit  
[Alliedmodders](https://github.com/alliedmodders) - Developed the original Mapchooser.  
[powerlord](https://github.com/powerlord/sourcemod-mapchooser-extended) - Developed the original Mapchooser Extended.  
