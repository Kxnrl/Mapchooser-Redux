#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <mapchooser_redux>

#undef REQUIRE_PLUGIN
#include <fys.pupd>

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

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("Pupd_CheckPlugin");
    return APLRes_Success;
}

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

public void Pupd_OnCheckAllPlugins()
{
    Pupd_CheckPlugin(false, "https://build.kxnrl.com/updater/MCR/");
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
    char map[128]; bool deleted = false;
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
        
        deleted = true;
        LogMessage("%s delete offical map [%s]", DeleteFile(map) ? "Successful" : "Failed", map);
    }
    delete dir;

    if (deleted)
        ServerCommand("sm_reloadmcr");
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
    static ArrayList officialmaps = null;
    if (officialmaps == null)
    {
        // create
        officialmaps = new ArrayList(ByteCountToCells(32));

        // Operation Broken Fang
        officialmaps.PushString("coop_autumn");
        officialmaps.PushString("coop_fall");
        officialmaps.PushString("cs_apollo");
        officialmaps.PushString("de_ancient");
        officialmaps.PushString("de_elysion");
        officialmaps.PushString("de_engage");
        officialmaps.PushString("de_guard");
        officialmaps.PushString("dz_frostbite");
        officialmaps.PushString("lobby_mapveto");

        // Operation Riptide
        officialmaps.PushString("dz_county");
        officialmaps.PushString("de_extraction");
        officialmaps.PushString("de_ravine");
        officialmaps.PushString("cs_insertion2");
        officialmaps.PushString("de_basalt");

        officialmaps.PushString("cs_climb");
        officialmaps.PushString("de_crete");
        officialmaps.PushString("de_hive");
        officialmaps.PushString("de_iris");
        officialmaps.PushString("dz_ember");
        officialmaps.PushString("dz_vineyard");

        // input
        officialmaps.PushString("ar_baggage");
        officialmaps.PushString("ar_dizzy");
        officialmaps.PushString("ar_lunacy");
        officialmaps.PushString("ar_monastery");
        officialmaps.PushString("ar_shoots");
        officialmaps.PushString("coop_kasbah");
        officialmaps.PushString("cs_agency");
        officialmaps.PushString("cs_assault");
        officialmaps.PushString("cs_italy");
        officialmaps.PushString("cs_militia");
        officialmaps.PushString("cs_office");
        officialmaps.PushString("de_swamp");
        officialmaps.PushString("de_mutiny");
        officialmaps.PushString("de_bank");
        officialmaps.PushString("de_anubis");
        officialmaps.PushString("de_breach");
        officialmaps.PushString("de_cache");
        officialmaps.PushString("de_canals");
        officialmaps.PushString("de_calavera");
        officialmaps.PushString("de_cbble");
        officialmaps.PushString("de_chlorine");
        officialmaps.PushString("de_dust2");
        officialmaps.PushString("de_grind");
        officialmaps.PushString("de_inferno");
        officialmaps.PushString("de_lake");
        officialmaps.PushString("de_mirage");
        officialmaps.PushString("de_mocha");
        officialmaps.PushString("de_nuke");
        officialmaps.PushString("de_overpass");
        officialmaps.PushString("de_pitstop");
        officialmaps.PushString("de_safehouse");
        officialmaps.PushString("de_shortdust");
        officialmaps.PushString("de_shortnuke");
        officialmaps.PushString("de_stmarc");
        officialmaps.PushString("de_studio");
        officialmaps.PushString("de_sugarcane");
        officialmaps.PushString("de_train");
        officialmaps.PushString("de_vertigo");
        officialmaps.PushString("dz_blacksite");
        officialmaps.PushString("dz_junglety");
        officialmaps.PushString("dz_sirocco");
        officialmaps.PushString("gd_cbble");
        officialmaps.PushString("gd_rialto");
        officialmaps.PushString("training1");

        // late
        officialmaps.PushString("de_blagai");
        officialmaps.PushString("de_prime");
        officialmaps.PushString("de_tuscan");
    }

    return (officialmaps.FindString(map) > -1);
}