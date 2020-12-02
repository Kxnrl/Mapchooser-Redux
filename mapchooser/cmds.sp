void Cmds_OnPluginStart()
{
    RegAdminCmd("sm_mapvote",    Command_Mapvote,    ADMFLAG_CHANGEMAP, "sm_mapvote - Forces MapChooser to attempt to run a map vote now.");
    RegAdminCmd("sm_setnextmap", Command_SetNextmap, ADMFLAG_CHANGEMAP, "sm_setnextmap <map>");
    RegAdminCmd("sm_clearallcd", Command_ClearAllCD, ADMFLAG_CONFIG,    "sm_clearallcd - Forces Mapchooser to clear map history and cooldown.");
    RegAdminCmd("sm_clearmapcd", Command_ClearMapCD, ADMFLAG_CONFIG,    "sm_clearmapcd - Forces Mapchooser to clear specified map cooldown.");
    RegAdminCmd("sm_resetmapcd", Command_ResetMapCD, ADMFLAG_CONFIG,    "sm_resetmapcd - Forces Mapchooser to reset specified map cooldown.");
    RegAdminCmd("sm_showmcrcd",  Command_ShowMCRCD,  ADMFLAG_CHANGEMAP, "sm_showmcrcd  - show old map list cooldown.");
    RegAdminCmd("sm_reloadmcr",  Command_ReloadMCR,  ADMFLAG_ROOT,      "sm_reloadmcr  - Reload this plugin.");
    RegAdminCmd("sm_dumpmcrmap", Command_DumpMap,    ADMFLAG_CHANGEMAP, "sm_dumpmcrmap - Dump map attributes.");
}

public Action Command_DumpMap(int client, int args)
{
    char map[128];
    if (args < 1)
    {
        GetCurrentMap(map, 128);
    }
    else
    {
        GetCmdArg(1, map, 128);
    }

    DisplayMapAttributes(client, map);

    ReplyToCommand(client, "[\x07M\x04C\x0CR\x01]  Check console output.");

    return Plugin_Handled;
}

public Action Command_SetNextmap(int client, int args)
{
    if (args < 1)
    {
        ReplyToCommand(client, "[\x04MCR\x01]  Usage: sm_setnextmap <map>");
        return Plugin_Handled;
    }

    char map[128];
    GetCmdArg(1, map, 128);

    if (!IsMapValid(map))
    {
        ReplyToCommand(client, "[\x04MCR\x01]  Invalid Map [%s]", map);
        return Plugin_Handled;
    }

    LogAction(client, -1, "\"%L\" changed nextmap to \"%s\"", client, map);

    InternalSetNextMap(map);

    return Plugin_Handled;
}

public Action Command_ClearAllCD(int client, int args)
{
    tChatAll("%t", "mcr clear cd");
    LogAction(client, -1, "%L -> Clear all cooldown.", client);
    ClearAllCooldown(client);
    CreateNextVote();
    return Plugin_Handled;
}

public Action Command_ClearMapCD(int client, int args)
{
    if (args != 1)
    {
        // block
        tChat(client, "Usage: sm_clearmapcd <map>");
        return Plugin_Handled;
    }

    char map[128];
    GetCmdArg(1, map, 128);

    ClearMapCooldown(client, map);
    CreateNextVote();

    return Plugin_Handled;
}

public Action Command_ResetMapCD(int client, int args)
{
    if (args != 1)
    {
        // block
        tChat(client, "Usage: sm_resetmapcd <map>");
        return Plugin_Handled;
    }

    char map[128];
    GetCmdArg(1, map, 128);

    ResetMapCooldown(client, map);
    CreateNextVote();

    return Plugin_Handled;
}

public Action Command_ShowMCRCD(int client, int args)
{
    if   (client)
    tChat(client, "%t", "mcr show cd");
    DisplayCooldownList(client);
    return Plugin_Handled;
}

public Action Command_ReloadMCR(int client, int args)
{
    Data_OnAllPluginsLoaded();
    CreateNextVote();
    SetupTimeleftTimer();
    Call_MapDataLoaded();
    ReplyToCommand(client, "[\x02M\x04C\x0BR]  Mapchooser-Redux has beed reloaded.");
    return Plugin_Handled;
}
