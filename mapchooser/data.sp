/*
enum struct MapData
{
    // mapdata.kv
    char m_FileName[128];
    char m_Description[64];
    int  m_Price;
    int  m_PricePartyBlock;
    int  m_FileSize;
    int  m_MinPlayers;
    int  m_MaxPlayers;
    int  m_MaxCooldown;
    bool m_NominateOnly;
    bool m_VipOnly;
    bool m_AdminOnly;
    bool m_CertainTimes[24]; // 0-23

    // mappool.kv
    int  m_CooldownLeft;
    int  m_RecentlyPlayed;
}
*/

static StringMap g_MapData;

public any Native_GetMapData(Handle plugin, int numParams)
{
    char map[128];
    GetNativeString(1, map, 128);
    MapData mapdata;
    bool r = g_MapData.GetArray(map, mapdata, typeofdata);
    SetNativeArray(2, mapdata, GetNativeCell(3));
    return r;
}

void Data_OnPluginStart()
{
    g_MapData = new StringMap();
}

void Data_OnAllPluginsLoaded()
{
    LoadMapData();
    LoadMapPool();
}

void Data_OnMapEnd()
{
    if (!g_bAllowCountdown)
        return;

    ArrayList maps = GetAllMapsName();

    char map[128]; MapData mapdata;
    for(int index = 0; index < maps.Length; index++)
    {
        maps.GetString(index, map, 128);

        if (!g_MapData.GetArray(map, mapdata, typeofdata))
            continue;

        if (mapdata.m_CooldownLeft > 0)
        {
            mapdata.m_CooldownLeft--;
            SaveMapPool(map);
        }
    }
}

static void LoadMapData()
{
    char path[128];
    BuildPath(Path_SM, path, 128, "configs/mapdata.kv");

    KeyValues kv = new KeyValues("MapData");
    if (!FileExists(path))
    {
        SetAllMapsDefault(kv);
    }
    else
    {
        kv.ImportFromFile(path);
        LoadAllMapsData(kv);
    }

    kv.Rewind();
    kv.ExportToFile(path);

    delete kv;
}

static void SetAllMapsDefault(KeyValues kv)
{
    ArrayList maps = GetAllMapsName();

    char map[128];
    for(int index = 0; index < maps.Length; index++)
    {
        maps.GetString(index, map, 128);

        kv.JumpToKey(map, true);
        kv.SetString("m_Description",  "null");
        kv.SetString("m_CertainTimes", "all");
        kv.SetNum("m_Price", 100);
        kv.SetNum("m_PricePartyBlock", 3000);
        kv.SetNum("m_MinPlayers", 0);
        kv.SetNum("m_MaxPlayers", 0);
        kv.SetNum("m_MaxCooldown", 100);
        kv.SetNum("m_NominateOnly", 0);
        kv.SetNum("m_VipOnly", 0);
        kv.SetNum("m_AdminOnly", 0);
        kv.Rewind();

        MapData mapdata;
        strcopy(mapdata.m_FileName,   128, map);
        strcopy(mapdata.m_Description, 64, "null");
        mapdata.m_Price = 100;
        mapdata.m_PricePartyBlock = 3000;
        mapdata.m_FileSize = GetMapFileSize(map);
        mapdata.m_MaxCooldown = 100;
        g_MapData.SetArray(map, mapdata, typeofdata, true);
    }

    delete maps;
}

static void LoadAllMapsData(KeyValues kv)
{
    ArrayList maps = GetAllMapsName();

    char map[128];
    for(int index = 0; index < maps.Length; index++)
    {
        maps.GetString(index, map, 128);
        kv.Rewind();

        if (!kv.JumpToKey(map, false))
        {
            // ?
            LogMessage("%s is missing in mapdata.", map);

            kv.JumpToKey(map, true);
            kv.SetString("m_Description",  "null");
            kv.SetString("m_CertainTimes", "all");
            kv.SetNum("m_Price", 100);
            kv.SetNum("m_PricePartyBlock", 3000);
            kv.SetNum("m_MinPlayers", 0);
            kv.SetNum("m_MaxPlayers", 0);
            kv.SetNum("m_MaxCooldown", 100);
            kv.SetNum("m_NominateOnly", 0);
            kv.SetNum("m_VipOnly", 0);
            kv.SetNum("m_AdminOnly", 0);
            kv.Rewind();

            MapData mapdata;
            strcopy(mapdata.m_FileName,   128, map);
            strcopy(mapdata.m_Description, 64, "null");
            mapdata.m_Price = 100;
            mapdata.m_PricePartyBlock = 3000;
            mapdata.m_FileSize = GetMapFileSize(map);
            mapdata.m_MaxCooldown = 100;
            g_MapData.SetArray(map, mapdata, typeofdata, true);

            continue;
        }

        MapData mapdata;
        strcopy(mapdata.m_FileName, 128, map);
        kv.GetString("m_Description", mapdata.m_Description, 64, "null");
        mapdata.m_Price           = kv.GetNum("m_Price", 100);
        mapdata.m_PricePartyBlock = kv.GetNum("m_PricePartyBlock", 3000);
        mapdata.m_FileSize        = GetMapFileSize(map);
        mapdata.m_MinPlayers      = kv.GetNum("m_MinPlayers", 0);
        mapdata.m_MaxPlayers      = kv.GetNum("m_MaxPlayers", 0);
        mapdata.m_MaxCooldown     = kv.GetNum("m_MaxCooldown", 100);
        mapdata.m_NominateOnly    = kv.GetNum("m_NominateOnly", 0) == 1;
        mapdata.m_VipOnly         = kv.GetNum("m_VipOnly", 0) == 1;
        mapdata.m_AdminOnly       = kv.GetNum("m_AdminOnly", 0) == 1;

        char m_CertainTimes[128];
        kv.GetString("m_CertainTimes", m_CertainTimes, 128, "all");
        if (strcmp(m_CertainTimes, "all") == 0)
        {
            // all time
            for (int i = 0; i < 24; i++)
                mapdata.m_CertainTimes[i] = true;
        }
        else
        {
            char o[24][4];
            int c = ExplodeString(m_CertainTimes, ",", o, 24, 4, false);
            for (int i = 0; i < c; i++)
                mapdata.m_CertainTimes[StringToInt(o[i])] = true;
        }

        g_MapData.SetArray(map, mapdata, typeofdata, true);
    }

    delete maps;
}

bool GetDescEx(const char[] map, char[] desc, int maxLen, bool includeName, bool includeTag, bool includePrice = false)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return false;

    strcopy(desc, maxLen, mapdata.m_Description);

    if (includeName)
        Format(desc, maxLen, "%s\n%s", map, desc);

    if (includeTag)
    {
        Format(desc, maxLen, "%s%s", mapdata.m_AdminOnly ? "✪" : "", desc);
        Format(desc, maxLen, "%s%s", mapdata.m_VipOnly   ? "♚" : "", desc);
    }

    if (includePrice)
    {
        // ?
        Format(desc, maxLen, "%s[%d]", desc, mapdata.m_Price);
    }

    return true;
}

bool IsBigMap(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return GetMapFileSize(map) > 150;

    return mapdata.m_FileSize > 150;
}

int GetPrice(const char[] map, bool recently = true, bool partyblock = false)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return 100;

    if (partyblock)
        return mapdata.m_PricePartyBlock;

    if (recently && g_ConVars.Recents.IntValue > -1)
    {
        int last = GetLastPlayed(map);
        int time = GetTime();
        int hour = (time - last) / 3600;
        if (hour < g_ConVars.Recents.IntValue) //
        {
            return RoundFloat(mapdata.m_Price *= (1.0 + g_ConVars.LtpMtpl.FloatValue));
        }
    }

    return mapdata.m_Price;
}

int GetMinPlayers(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return 0;

    return mapdata.m_MinPlayers;
}

int GetMaxPlayers(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return 0;

    return mapdata.m_MaxPlayers;
}

bool IsNominateOnly(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return false;

    return mapdata.m_NominateOnly;
}

bool IsAdminOnly(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return false;

    return mapdata.m_AdminOnly;
}

bool IsVIPOnly(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return false;

    return mapdata.m_VipOnly;
}

bool IsCertainTimes(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return false;

    return mapdata.m_CertainTimes[GetTodayHours()];
}

bool SetLastPlayed(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return false;

    mapdata.m_RecentlyPlayed = GetTime();
    SaveMapPool(map);
    return true;
}

int GetLastPlayed(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return 0;

    return mapdata.m_RecentlyPlayed;
}

int GetCooldown(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return 0;

    return mapdata.m_CooldownLeft;
}

bool SetCooldown(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return false;

    mapdata.m_CooldownLeft = mapdata.m_MaxCooldown;
    SaveMapPool(map);
    return true;
}

static void LoadMapPool()
{
    char path[128];
    BuildPath(Path_SM, path, 128, "data/mappool.kv");

    KeyValues kv = new KeyValues("MapData");
    if (!FileExists(path))
    {
        delete kv;
        return;
    }

    ArrayList maps = GetAllMapsName();

    char map[128];
    for(int index = 0; index < maps.Length; index++)
    {
        maps.GetString(index, map, 128);

        MapData mapdata;
        if (!g_MapData.GetArray(map, mapdata, typeofdata))
        {
            // ??
            continue;
        }

        if (kv.JumpToKey(map, false))
        {
            mapdata.m_CooldownLeft = kv.GetNum("m_CooldownLeft", 0);
            mapdata.m_RecentlyPlayed = kv.GetNum("m_RecentlyPlayed", 0);
            g_MapData.SetArray(map, mapdata, typeofdata, true);
        }
    }

    delete kv;
    delete maps;
}

static void SaveMapPool(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        // ??
        return;
    }

    char path[128];
    BuildPath(Path_SM, path, 128, "data/mappool.kv");

    KeyValues kv = new KeyValues("MapData");
    if (!FileExists(path))
    {
        delete kv;
        return;
    }
    else
    {
        kv.ImportFromFile(path);
    }

    kv.JumpToKey(map, true);
    kv.SetNum("m_CooldownLeft", mapdata.m_CooldownLeft);
    kv.SetNum("m_RecentlyPlayed", mapdata.m_RecentlyPlayed);
    kv.Rewind();
    kv.ExportToFile(path);

    delete kv;

    Call_MapVotePoolChanged();
}


void ClearAllCooldown()
{
    ArrayList maps = GetAllMapsName();

    char map[128]; MapData mapdata;
    for(int index = 0; index < maps.Length; index++)
    {
        maps.GetString(index, map, 128);

        if (!g_MapData.GetArray(map, mapdata, typeofdata))
            continue;

        if (mapdata.m_CooldownLeft > 0)
        {
            mapdata.m_CooldownLeft--;
            SaveMapPool(map);
        }
    }
}

void ClearMapCooldown(int client, const char[] map)
{
    char alter[128];
    for (int i = 0; i < g_aMapList.Length; i++)
    {
        g_aMapList.GetString(i, alter, 128);

        if (StrContains(alter, map, false) > -1)
        if (SetCooldown(alter))
        {
            tChatAll("%t", "mcr clear map cd", map);
            LogAction(client, -1, "%L -> Clear [%s] cooldown.", client, map);
        }
    }
}

void ResetMapCooldown(int client, const char[] map)
{
    char alter[128]; MapData mapdata;
    for (int i = 0; i < g_aMapList.Length; i++)
    {
        g_aMapList.GetString(i, alter, 128);

        if (StrContains(alter, map, false) > -1)
        if (g_MapData.GetArray(alter, mapdata, typeofdata))
        {
            mapdata.m_CooldownLeft = mapdata.m_MaxCooldown;
            SaveMapPool(alter);

            tChatAll("%t", "mcr reset map cd", map);
            LogAction(client, -1, "%L -> Reset [%s] cooldown.", client, map);
        }
    }
}

void DisplayCooldownList(int client)
{
    PrintToConsole(client, "============[MCR]============");
    char map[128]; MapData mapdata;
    for (int i = 0; i < g_aMapList.Length; i++)
    {
        g_aMapList.GetString(i, map, 128);

        if (g_MapData.GetArray(map, mapdata, typeofdata))
        {
            if (mapdata.m_CooldownLeft > 0)
            {
                PrintToConsole(client, "[%s/%s] -> %s", PadLeft(mapdata.m_CooldownLeft, 3), PadLeft(mapdata.m_MaxCooldown, 3), map);
            }
        }
    }
}

ArrayList GetCooldownMaps()
{
    ArrayList maps = new ArrayList(ByteCountToCells(128));

    char map[128]; MapData mapdata;
    for (int i = 0; i < g_aMapList.Length; i++)
    {
        g_aMapList.GetString(i, map, 128);

        if (g_MapData.GetArray(map, mapdata, typeofdata))
        {
            if (mapdata.m_CooldownLeft > 0)
            {
                maps.PushString(map);
            }
        }
    }

    return maps;
}