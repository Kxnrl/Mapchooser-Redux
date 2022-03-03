
stock void GetMapItem(Menu menu, int position, char[] map, int mapLen)
{
    menu.GetItem(position, map, mapLen);
}

stock void AddExtendToMenu(Menu menu, MapChange when)
{
    if ((when == MapChange_Instant || when == MapChange_RoundEnd) && g_ConVars.NoVotes.BoolValue)
        menu.AddItem(VOTE_DONTCHANGE, "Don't Change");
    else if (g_iExtends < g_ConVars.MaxExts.IntValue)
        menu.AddItem(VOTE_EXTEND, "Extend Map");
}

stock void DisplayCountdownHUD(int time)
{
    SetHudTextParams(-1.0, 0.32, 1.2, 0, 255, 255, 255, 0, 30.0, 0.0, 0.0);// Doc -> https://sm.alliedmods.net/new-api/halflife/SetHudTextParams
    for(int client = 1; client <= MaxClients; ++client)
        if (IsClientInGame(client) && !IsFakeClient(client))
            ShowHudText(client, 0, "%T", "mcr countdown hud", client, time); // 叁生鉐 is dead...
}

stock int GetRealPlayers()
{
    int count = 0;
    for(int client = 1; client <= MaxClients; ++client)
        if (IsClientInGame(client) && !IsFakeClient(client))
            count++;

    return count;
}

stock int GetLtpPrice(const char[] map)
{
    int price = GetMapPrice(map);
    float mtp = 1.0 + g_ConVars.LtpMtpl.FloatValue;
    return RoundToCeil(price * mtp);
}

stock int GetNtpPrice(const char[] map)
{
    int price = GetMapPrice(map);
    float mtp = 1.0 - g_ConVars.NtpMtpl.FloatValue;
    return RoundToFloor(price * mtp);
}

stock bool IsRecentlyPlayedMap(const char[] map)
{
    int lastPlayed = GetLastPlayed(map);
    
    if (lastPlayed == -1)
        return false;

    int time = GetTime();
    int diff = time - lastPlayed;
    int hour = diff / 3600;

    if (hour > g_ConVars.Recents.IntValue)
        return false;

    return true;
}

stock bool CleanPlugin()
{
    // delete mapchooser
    if (FileExists("addons/sourcemod/plugins/mapchooser.smx"))
        if (!DeleteFile("addons/sourcemod/plugins/mapchooser.smx"))
            return false;
    
    // delete rockthevote
    if (FileExists("addons/sourcemod/plugins/rockthevote.smx"))
        if (!DeleteFile("addons/sourcemod/plugins/rockthevote.smx"))
            return false;
        
    // delete nominations
    if (FileExists("addons/sourcemod/plugins/nominations.smx"))
        if (!DeleteFile("addons/sourcemod/plugins/nominations.smx"))
            return false;
        
    // delete mapchooser_extended
    if (FileExists("addons/sourcemod/plugins/mapchooser_extended.smx"))
        if (!DeleteFile("addons/sourcemod/plugins/mapchooser_extended.smx"))
            return false;
    
    // delete rockthevote_extended
    if (FileExists("addons/sourcemod/plugins/rockthevote_extended.smx"))
        if (!DeleteFile("addons/sourcemod/plugins/rockthevote_extended.smx"))
            return false;
        
    // delete nominations_extended
    if (FileExists("addons/sourcemod/plugins/nominations_extended.smx"))
        if (!DeleteFile("addons/sourcemod/plugins/nominations_extended.smx"))
            return false;

    return true;
}

stock int SetupWarningTimer(WarningType type, MapChange when = MapChange_MapEnd, Handle mapList = null, bool force = false)
{
    if (g_aMapList.Length <= 0 || g_bChangeMapInProgress || g_bHasVoteStarted || (!force && g_bMapVoteCompleted))
        return;

    if (g_bWarningInProgress && g_tWarning != null)
        KillTimer(g_tWarning);

    g_bWarningInProgress = true;
    
    int cvarTime;

    switch (type)
    {
        case WarningType_Vote:
        {
            cvarTime = 15;
        }
        
        case WarningType_Revote:
        {
            cvarTime = 5;
        }

        case WarningType_Delay:
        {
            cvarTime = 30;
        }
    }

    DataPack data = new DataPack();
    data.WriteCell(cvarTime);
    data.WriteCell(when);
    data.WriteCell(mapList);
    data.Reset();
    g_tWarning = CreateTimer(1.0, Timer_StartMapVote, data, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT|TIMER_DATA_HNDL_CLOSE);
}

stock bool IsMapEndVoteAllowed()
{
    if (g_bMapVoteCompleted || g_bHasVoteStarted)
        return false;

    return true;
}

stock ArrayList GetAllMapsName()
{
    ArrayList maps = new ArrayList(ByteCountToCells(128));

    DirectoryListing dir = OpenDirectory("maps");
    if (dir == null)
    {
        LogError("GetAllMapsName -> Failed to open maps.");
        return maps;
    }

    FileType type = FileType_Unknown;
    char map[128];
    while(dir.GetNext(map, 128, type))
    {
        if (type != FileType_File || StrContains(map, ".bsp", false) == -1)
            continue;

        // https://github.com/Kxnrl/Mapchooser-Redux/issues/27
        if (StrContains(map, ".bsp.bz2", false) > -1)
            continue;

        int c = FindCharInString(map, '.', true);
        map[c] = '\0';

        if (!IsMapValid(map))
        {
            LogError("GetAllMapsName -> %s is invalid map.", map);
            continue;
        }

        maps.PushString(map);
    }

    delete dir;
    return maps;
}

stock int GetNominationOwner(const char[] map)
{
    for (int i = 0; i < g_aNominations.Length; i++)
    {
        Nominations n;
        g_aNominations.GetArray(i, n, sizeof(Nominations));
        if (strcmp(map, n.m_Map) == 0)
            return n.m_Owner;
    }
    return -1;
}

stock bool AddMapItem(Menu menu, const char[] map, bool includeTag, bool includeTier, bool ori = false, int client = -1, int flag = ITEMDRAW_DEFAULT)
{
    if (!ori)
    {
        char trans[128];
        if (GetDescEx(map, trans, 128, true, includeTag, false, includeTier))
        {
            if (ClientIsValid(client))
            {
                char name[16];
                GetClientName(client, name, 16);
                Format(trans, 192, "%s %s: %s", trans, g_bPartyblock ? "pb" : "by", name);
            }
            // not null
            return menu.AddItem(map, trans, flag);
        }
    }

    return menu.AddItem(map, map);
}

stock int GetMapFileSize(const char[] map)
{
    char path[128];
    FormatEx(path, 128, "maps/%s.bsp", map);
    return FileSize(path) / 1048576+1;
}

stock char[] PadLeft(int value, int len = 0, const char[] padleft = "  ")
{
    char buffer[16];
    FormatEx(buffer, 16, "%d", value);

    if (len > 0)
    {
        int csl = len - strlen(buffer);

        for(int i = 0; i < csl; i++)
        {
            Format(buffer, 16, "%s%s", padleft, buffer);
        }
    }

    return buffer;
}

stock any clamp(any min, any max, any value)
{
    if (value < min)
        value = min;
    if (value > max)
        value = max;
    return value;
}

stock int GetTimeLeft()
{
    if (g_pMaps)
        return Maps_GetTimeLeft();

    int timeLeft;
    return GetMapTimeLeft(timeLeft) ? timeLeft : 0;
}

stock void ShuffleStringArray(ArrayList array)
{
    char buffer[256];
    ArrayList dummy = new ArrayList(ByteCountToCells(256));
    while (array.Length > 0)
    {
        array.GetString(0, buffer, 256);
        dummy.PushString(buffer);
        array.Erase(0);
    }

    while (dummy.Length > 0)
    {
        int index = RandomInt(0, dummy.Length -1);
        dummy.GetString(index, buffer, 256);
        dummy.Erase(index);
        array.PushString(buffer);
    }
}