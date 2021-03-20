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
    float m_RefundRatio;

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
            g_MapData.SetArray(map, mapdata, typeofdata, true);
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
        //CleanMapsData(kv);
        LoadAllMapsData(kv);
    }

    kv.Rewind();
    kv.ExportToFile(path);

    delete kv;
}

static void SetAllMapsDefault(KeyValues kv)
{
    ArrayList maps = GetAllMapsName();

    LogMessage("Process SetAllMapsDefault with %d maps.", maps.Length);

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
        strcopy(mapdata.m_Description, 32, "null");
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
    g_MapData.Clear();

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
            strcopy(mapdata.m_Description, 32, "null");
            mapdata.m_Price = 100;
            mapdata.m_PricePartyBlock = 3000;
            mapdata.m_FileSize = GetMapFileSize(map);
            mapdata.m_MaxCooldown = 100;
            g_MapData.SetArray(map, mapdata, typeofdata, true);

            continue;
        }

        MapData mapdata;
        strcopy(mapdata.m_FileName, 128, map);
        kv.GetString("m_Description", mapdata.m_Description, 32, "null");
        mapdata.m_Price           = kv.GetNum("m_Price", 100);
        mapdata.m_PricePartyBlock = kv.GetNum("m_PricePartyBlock", 3000);
        mapdata.m_FileSize        = GetMapFileSize(map);
        mapdata.m_MinPlayers      = kv.GetNum("m_MinPlayers", 0);
        mapdata.m_MaxPlayers      = kv.GetNum("m_MaxPlayers", 0);
        mapdata.m_MaxCooldown     = kv.GetNum("m_MaxCooldown", 100);
        mapdata.m_NominateOnly    = kv.GetNum("m_NominateOnly", 0) == 1;
        mapdata.m_VipOnly         = kv.GetNum("m_VipOnly", 0) == 1;
        mapdata.m_AdminOnly       = kv.GetNum("m_AdminOnly", 0) == 1;
        mapdata.m_RefundRatio     = kv.GetFloat("m_RefundRatio", -1.0);

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
            for (int i = 0; i < c; i++) if (strlen(o[i]) > 0)
                mapdata.m_CertainTimes[StringToInt(o[i])] = true;
        }

        g_MapData.SetArray(map, mapdata, typeofdata, true);
    }

    LogMessage("Mapdata has been loaded with %d/%d maps...", g_MapData.Size, maps.Length);

    delete maps;
}

static void CleanMapsData(KeyValues kv)
{
    kv.Rewind();

    if (!kv.GotoFirstSubKey(true))
        return;

    char map[128], path[128];

    do
    {
        kv.GetSectionName(map, 128);
        FormatEx(path, 128, "maps/%s.bsp", map);

        if (!FileExists(path, true))
        {
            // this file not exists
            kv.DeleteThis();
        }
    }
    while (kv.GotoNextKey(true));
    kv.Rewind();
}

bool GetDescEx(const char[] map, char[] desc, int maxLen, bool includeName, bool includeTag, bool includePrice = false)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        LogMessage("GetDescEx -> Failed to get map %s", map);
        return false;
    }

    strcopy(desc, maxLen, mapdata.m_Description);

    if (includeName)
        Format(desc, maxLen, "%s\n%s", map, desc);

    if (includeTag)
    {
        Format(desc, maxLen, "%s%s", mapdata.m_AdminOnly ? "[ADMIN] "   : "", desc);
        Format(desc, maxLen, "%s%s", mapdata.m_VipOnly   ? "[VIP]     " : "", desc);
    }

    if (includePrice)
    {
        // ?
        Format(desc, maxLen, "%s[%d]", desc, mapdata.m_Price);
    }

    return true;
}

float GetRefundRatio(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        // fallback to default cvar
        return g_ConVars.Refunds.FloatValue;
    }

    if (mapdata.m_RefundRatio < 0.0)
        return g_ConVars.Refunds.FloatValue;

    if (mapdata.m_RefundRatio > 1.0)
        return 1.0;

    return mapdata.m_RefundRatio;
}

bool IsBigMap(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
        return GetMapFileSize(map) > 150;

    return mapdata.m_FileSize > 150;
}

stock int GetRefundCredits(const char[] map)
{
    // disallow refund
    if (g_ConVars.Refunds.FloatValue <= 0.0)
        return 0;

    return RoundToCeil(float(GetPrice(map)) * GetRefundRatio(map));
}

int GetRefundCreditsByNomination(Nominations n)
{
    // disallow refund
    if (g_ConVars.Refunds.FloatValue <= 0.0)
        return 0;

    return RoundToCeil(float(n.m_Price) * GetRefundRatio(n.m_Map));
}

int GetPrice(const char[] map, bool recently = true, bool partyblock = false)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        LogMessage("GetPrice -> Failed to get map %s", map);
        return 100;
    }

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
    {
        LogMessage("GetMinPlayers -> Failed to get map %s", map);
        return 0;
    }

    return mapdata.m_MinPlayers;
}

int GetMaxPlayers(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        LogMessage("GetMaxPlayers -> Failed to get map %s", map);
        return 0;
    }

    return mapdata.m_MaxPlayers;
}

bool IsNominateOnly(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        LogMessage("IsNominateOnly -> Failed to get map %s", map);
        return false;
    }

    return mapdata.m_NominateOnly;
}

bool IsAdminOnly(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        LogMessage("IsAdminOnly -> Failed to get map %s", map);
        return false;
    }

    return mapdata.m_AdminOnly;
}

bool IsVIPOnly(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        LogMessage("IsVIPOnly -> Failed to get map %s", map);
        return false;
    }

    return mapdata.m_VipOnly;
}

bool IsCertainTimes(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        LogMessage("IsCertainTimes -> Failed to get map %s", map);
        return false;
    }

    return mapdata.m_CertainTimes[GetTodayHours()];
}

bool SetLastPlayed(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        LogMessage("SetLastPlayed -> Failed to get map %s", map);
        return false;
    }

    mapdata.m_RecentlyPlayed = GetTime();
    g_MapData.SetArray(map, mapdata, typeofdata, true);
    SaveMapPool(map);
    return true;
}

int GetLastPlayed(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        LogMessage("GetLastPlayed -> Failed to get map %s", map);
        return 0;
    }

    return mapdata.m_RecentlyPlayed;
}

int GetCooldown(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        LogMessage("GetCooldown -> Failed to get map %s", map);
        return 0;
    }

    return mapdata.m_CooldownLeft;
}

bool SetCooldown(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        LogMessage("SetCooldown -> Failed to get map %s", map);
        return false;
    }

    mapdata.m_CooldownLeft = mapdata.m_MaxCooldown;
    g_MapData.SetArray(map, mapdata, typeofdata, true);
    SaveMapPool(map);
    return true;
}

bool ClearCooldown(const char[] map)
{
    MapData mapdata;
    if (!g_MapData.GetArray(map, mapdata, typeofdata))
    {
        LogMessage("ClearCooldown -> Failed to get map %s", map);
        return false;
    }

    mapdata.m_CooldownLeft = 0;
    g_MapData.SetArray(map, mapdata, typeofdata, true);
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
    if (!kv.ImportFromFile(path))
    {
        LogMessage("LoadMapPool -> failed to import keyvalues from %s", path);
        delete kv;
        return;
    }

    ArrayList maps = GetAllMapsName();

    char map[128];
    for(int index = 0; index < maps.Length; index++)
    {
        maps.GetString(index, map, 128);
        kv.Rewind();

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
        LogMessage("SaveMapPool -> Failed to save %s", map);
        return;
    }

    char path[128];
    BuildPath(Path_SM, path, 128, "data/mappool.kv");

    KeyValues kv = new KeyValues("MapData");
    if (FileExists(path))
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

void ClearAllCooldown(int client)
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
            if (!Call_OnClearMapCooldown(map, client))
                continue;

            mapdata.m_CooldownLeft = 0;
            g_MapData.SetArray(map, mapdata, typeofdata, true);
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

        if (StrContains(alter, map, false) > -1 && Call_OnClearMapCooldown(map, client))
        if (ClearCooldown(alter))
        {
            tChatAll("%t", "mcr clear map cd", alter);
            LogAction(client, -1, "%L -> Clear [%s] cooldown.", client, alter);
        }
    }
}

void ResetMapCooldown(int client, const char[] map)
{
    char alter[128];
    for (int i = 0; i < g_aMapList.Length; i++)
    {
        g_aMapList.GetString(i, alter, 128);

        if (StrContains(alter, map, false) > -1 && Call_OnResetMapCooldown(map, client))
        if (SetCooldown(alter))
        {
            tChatAll("%t", "mcr reset map cd", alter);
            LogAction(client, -1, "%L -> Reset [%s] cooldown.", client, alter);
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
                PrintToConsole(client, "[%s/%s] -> %s", PadLeft(mapdata.m_CooldownLeft, 3, " "), PadLeft(mapdata.m_MaxCooldown, 3, " "), map);
            }
        }
    }
}

void GetCooldownMaps(ArrayList maps)
{
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
}

void DisplayMapAttributes(int client, const char[] map)
{
    char alter[128]; MapData mapdata;
    for (int i = 0; i < g_aMapList.Length; i++)
    {
        g_aMapList.GetString(i, alter, 128);

        if (StrContains(alter, map, false) > -1)
        if (g_MapData.GetArray(alter, mapdata, typeofdata))
        {
            PrintToConsole(client, "===========[%s]===========", alter);
            PrintToConsole(client, "m_FileName       : %s", mapdata.m_FileName);
            PrintToConsole(client, "m_Description    : %s", mapdata.m_Description);
            PrintToConsole(client, "m_Price          : %d", mapdata.m_Price);
            PrintToConsole(client, "m_PricePartyBlock: %d", mapdata.m_PricePartyBlock);
            PrintToConsole(client, "m_FileSize       : %d", mapdata.m_FileSize);
            PrintToConsole(client, "m_MinPlayers     : %d", mapdata.m_MinPlayers);
            PrintToConsole(client, "m_MinPlayers     : %d", mapdata.m_MaxPlayers);
            PrintToConsole(client, "m_MaxCooldown    : %d", mapdata.m_MaxCooldown);
            PrintToConsole(client, "m_NominateOnly   : %b", mapdata.m_NominateOnly);
            PrintToConsole(client, "m_AdminOnly      : %b", mapdata.m_AdminOnly);
            PrintToConsole(client, "m_VipOnly        : %b", mapdata.m_VipOnly);
            PrintToConsole(client, "m_CooldownLeft   : %d", mapdata.m_CooldownLeft);
            PrintToConsole(client, "m_RecentlyPlayed : %d", mapdata.m_RecentlyPlayed);
            PrintToConsole(client, "m_RefundRatio    : %f", mapdata.m_RefundRatio);
        }
    }
}