#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <mapchooser_redux>

int g_iMapCount = 0;
bool g_bStartup = true;

ConVar mcr_delete_offical_map;
ConVar mcr_generate_mapcycle;
ConVar mcr_generate_mapgroup;

public Plugin myinfo =
{
    name        = "Map Lister Redux",
    author      = "Kyle",
    description = "Automated Map Voting with Extensions",
    version     = MCR_VERSION,
    url         = "https://www.kxnrl.com"
};

public void OnPluginStart()
{
    mcr_delete_offical_map = CreateConVar("mcr_delete_offical_map", "1", "auto-delete offical maps", _, true, 0.0, true, 1.0);
    mcr_generate_mapcycle  = CreateConVar("mcr_generate_mapcycle",  "1", "auto-generate map list in mapcycle.txt", _, true, 0.0, true, 1.0);
    mcr_generate_mapgroup  = CreateConVar("mcr_generate_mapgroup",  "1", "auto-generate map group in gamemodes_server.txt", _, true, 0.0, true, 1.0);

    if (!DirExists("cfg/sourcemod/mapchooser"))
        if (!CreateDirectory("cfg/sourcemod/mapchooser", 511))
            SetFailState("Failed to create folder \"cfg/sourcemod/mapchooser\"");

    AutoExecConfig(true, "maplister_redux", "sourcemod/mapchooser");

    g_iMapCount = GetMapCount();

    CreateTimer(600.0, Timer_Detected, _, TIMER_REPEAT);
}

public Action Timer_Detected(Handle timer)
{
    int count = GetMapCount();
    if (count != g_iMapCount)
    {
        LogMessage("Detected: Map count was changed! last check: %d  current: %d", g_iMapCount, count);
        DeleteMap();
        MapCycle();
        MapGroup();
    }
    return Plugin_Continue;
}

public void OnConfigsExecuted()
{
    if (g_bStartup)
    {
        g_bStartup = false;
        DeleteMap();
        MapCycle();
        MapGroup();
    }
}

static int GetMapCount()
{
    DirectoryListing dir = OpenDirectory("maps");
    if (dir == null)
        ThrowError("Failed to open maps.");

    int count = 0;
    
    FileType type = FileType_Unknown;
    char map[128];
    while(dir.GetNext(map, 128, type))
    {
        if (type != FileType_File || StrContains(map, ".bsp", false) == -1)
            continue;

        count++;
    }
    delete dir;

    return count;
}

static void DeleteMap()
{
    if (!mcr_delete_offical_map.BoolValue)
        return;
    
    LogMessage("Process delete offical maps ...");

    DirectoryListing dir = OpenDirectory("maps");
    if (dir == null)
    {
        LogError("DeleteMap -> Failed to open maps");
        return;
    }
    
    g_iMapCount = 0;

    FileType type = FileType_Unknown;
    char map[128];
    while(dir.GetNext(map, 128, type))
    {
        if (type != FileType_File || StrContains(map, ".bsp", false) == -1)
            continue;
        
        int c = FindCharInString(map, '.', true);
        map[c] = '\0';
        
        if (!IsOfficalMap(map))
        {
            g_iMapCount++;
            continue;
        }

        Format(map, 128, "maps/%s.bsp", map);
        
        LogMessage("%s delete offical map [%s]", DeleteFile(map) ? "Successful" : "Failed", map);
    }
    delete dir;
}

static void MapCycle()
{
    if (!mcr_generate_mapcycle.BoolValue)
        return;
    
    LogMessage("Process generate mapcycle ...");

    File file = OpenFile("mapcycle.txt", "w+");
    if (file == null)
    {
        LogError("MapCycle -> Failed to open mapcycle.txt");
        return;
    }
    
    DirectoryListing dir = OpenDirectory("maps");
    if (dir == null)
    {
        LogError("MapCycle -> Failed to open maps");
        return;
    }

    FileType type = FileType_Unknown;
    char map[128];
    while(dir.GetNext(map, 128, type))
    {
        if (type != FileType_File || StrContains(map, ".bsp", false) == -1)
            continue;
        
        int c = FindCharInString(map, '.', true);
        map[c] = '\0';
        
        file.WriteLine(map);
    }
    delete dir;
    file.Close();
}

static void MapGroup()
{
    if (!mcr_generate_mapgroup.BoolValue)
        return;
    
    LogMessage("Process generate mapgroup ...");

    KeyValues kv = new KeyValues("GameModes_Server.txt");
    
    if (FileExists("gamemodes_server.txt"))
        kv.ImportFromFile("gamemodes_server.txt");
    
    kv.JumpToKey("mapgroups", true);
    
    if (kv.JumpToKey("custom_maps", false))
    {
        kv.GoBack();
        kv.DeleteKey("custom_maps");
    }
    
    kv.JumpToKey("custom_maps", true);
    
    kv.SetString("name", "custom_maps");
    
    kv.JumpToKey("maps", true);
    
    // foreach
    DirectoryListing dir = OpenDirectory("maps");
    if (dir == null)
    {
        LogError("MapGroup -> Failed to open maps");
        delete kv;
        return;
    }
    FileType type = FileType_Unknown;
    char map[128];
    while(dir.GetNext(map, 128, type))
    {
        if (type != FileType_File || StrContains(map, ".bsp", false) == -1)
            continue;
        
        int c = FindCharInString(map, '.', true);
        map[c] = '\0';

        kv.SetString(map, " ");
    }
    delete dir;
    
    kv.Rewind();
    kv.ExportToFile("gamemodes_server.txt");
    
    delete kv;
}

static bool IsOfficalMap(const char[] map)
{
    static ArrayList officalmaps = null;
    if (officalmaps == null)
    {
        // create
        officalmaps = new ArrayList(ByteCountToCells(32));

        // input
        officalmaps.PushString("ar_baggage");
        officalmaps.PushString("ar_dizzy");
        officalmaps.PushString("ar_lunacy");
        officalmaps.PushString("ar_monastery");
        officalmaps.PushString("ar_shoots");
        officalmaps.PushString("coop_kasbah");
        officalmaps.PushString("cs_agency");
        officalmaps.PushString("cs_assault");
        officalmaps.PushString("cs_italy");
        officalmaps.PushString("cs_militia");
        officalmaps.PushString("cs_office");
        officalmaps.PushString("de_bank");
        officalmaps.PushString("de_breach");
        officalmaps.PushString("de_cache");
        officalmaps.PushString("de_canals");
        officalmaps.PushString("de_cbble");
        officalmaps.PushString("de_dust2");
        officalmaps.PushString("de_inferno");
        officalmaps.PushString("de_lake");
        officalmaps.PushString("de_mirage");
        officalmaps.PushString("de_nuke");
        officalmaps.PushString("de_overpass");
        officalmaps.PushString("de_safehouse");
        officalmaps.PushString("de_shortdust");
        officalmaps.PushString("de_shortnuke");
        officalmaps.PushString("de_stmarc");
        officalmaps.PushString("de_studio");
        officalmaps.PushString("de_sugarcane");
        officalmaps.PushString("de_train");
        officalmaps.PushString("de_vertigo");
        officalmaps.PushString("dz_blacksite");
        officalmaps.PushString("dz_junglety");
        officalmaps.PushString("dz_sirocco");
        officalmaps.PushString("gd_cbble");
        officalmaps.PushString("gd_rialto");
        officalmaps.PushString("training1");
    }

    return (officalmaps.FindString(map) > -1);
}