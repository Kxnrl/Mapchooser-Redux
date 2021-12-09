void Events_OnPluginStart()
{
    HookEvent("cs_win_panel_match", Event_WinPanel, EventHookMode_Post);
    HookEvent("round_end",          Event_RoundEnd, EventHookMode_Post);
}

public void Event_WinPanel(Handle event, const char[] name, bool dontBroadcast)
{
    char cmap[128], nmap[128];
    GetCurrentMap(cmap, 128);
    GetNextMap(nmap, 128);
    if (!IsMapValid(nmap))
    {
        do
        {
            g_aMapList.GetString(RandomInt(0, g_aMapList.Length-1), nmap, 128);
        }
        while(StrEqual(nmap, cmap));
    }

    DataPack pack = new DataPack();
    pack.WriteString(nmap);
    pack.Reset();
    CreateTimer(60.0, Timer_Monitor, pack, TIMER_FLAG_NO_MAPCHANGE);
}

public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
    if (!g_bChangeMapAtRoundEnd)
        return;

    FindConVar("mp_halftime").SetInt(0);
    FindConVar("mp_timelimit").SetInt(0);
    FindConVar("mp_maxrounds").SetInt(0);
    FindConVar("mp_roundtime").SetInt(1);

    CreateTimer(60.0, Timer_ChangeMap, 0, TIMER_FLAG_NO_MAPCHANGE);

    g_bChangeMapInProgress = true;
    g_bChangeMapAtRoundEnd = false;
}

public Action Timer_Monitor(Handle timer, DataPack pack)
{
    char cmap[128], nmap[128];
    GetCurrentMap(cmap, 128);
    pack.ReadString(nmap, 128);
    delete pack;

    if (StrEqual(nmap, cmap))
        return Plugin_Stop;

    LogMessage("Map has not been changed ? %s -> %s", cmap, nmap);
    ForceChangeLevel(nmap, "BUG: Map not change");

    return Plugin_Stop;
}
