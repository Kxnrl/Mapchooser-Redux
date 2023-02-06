// MAIN_FILE ../mapchooser_redux.sp

void Cvars_OnPluginStart()
{
    g_ConVars.TimeLoc = CreateConVar("mcr_timer_hud_location",    "3", "Timer Location of HUD - 0: Hint,  1: Text,  2: Chat,  3: Game",                                                   _, true,  0.0, true,   3.0);
    g_ConVars.NameTag = CreateConVar("mcr_include_nametag",       "1", "include name tag in map desc",                                                                                    _, true,  0.0, true,   1.0);
    g_ConVars.TierTag = CreateConVar("mcr_include_tiertag",       "1", "incluee tier tag in map desc",                                                                                    _, true,  0.0, true,   1.0);
    g_ConVars.DescTag = CreateConVar("mcr_include_desctag",       "1", "include desc tag in map desc",                                                                                    _, true,  0.0, true,   1.0);
    g_ConVars.MaxExts = CreateConVar("mcr_map_extend_times",      "3", "How many times can extend the map.",                                                                              _, true,  0.0, true,   9.0);
    g_ConVars.Recents = CreateConVar("mcr_rectplayed_interval", "144", "How much time in hours ago played can count to recently played pool, (-1 disable all recently played function) ", _, true, -1.0, true, 300.0);
    g_ConVars.LtpMtpl = CreateConVar("mcr_rectplayed_ltp_mtpl", "0.5", "What percentage increase of nomination map price for recently played",                                            _, true,  0.0, true,   9.9);
    g_ConVars.BCState = CreateConVar("mcr_partyblock_enabled",    "1", "Enable or not party block fuction.",                                                                              _, true,  0.0, true,   1.0);
    g_ConVars.Shuffle = CreateConVar("mcr_votemenu_shuffle",      "1", "Enable or not shuffle mapvote menu.",                                                                             _, true,  0.0, true,   1.0);
    g_ConVars.Refunds = CreateConVar("mcr_refund_credits_ratio","0.6", "Refund ratio of credits if map fail to be choosen.",                                                              _, true,  0.0, true,   1.0);
    g_ConVars.Require = CreateConVar("mcr_shuffle_require_maps",  "1", "How many nominations can shuaffle the map vote menu.",                                                            _, true,  0.0, true,   5.0);
    g_ConVars.NoVotes = CreateConVar("mcr_add_novote_button",     "1", "Add no vote button into menu.",                                                                                   _, true,  0.0, true,   1.0);
    g_ConVars.MinRuns = CreateConVar("mcr_min_players_run_cd",   "20", "How many players required to run cooldown.",                                                                      _, true,  0.0, true,  64.0);
    g_ConVars.AutoGen = CreateConVar("mcr_mapdata_auto_generate", "0", "Auto generate map data if missing map.",                                                                          _, true,  0.0, true,   1.0);

    CreateConVar("mcr_command_broadcast", "0", "Allow command broadcast.");

    if (!DirExists("cfg/sourcemod/mapchooser"))
        if (!CreateDirectory("cfg/sourcemod/mapchooser", 511))
            SetFailState("Failed to create folder \"cfg/sourcemod/mapchooser\"");

    AutoExecConfig(true, "mapchooser_redux", "sourcemod/mapchooser");

    ConVar cvar;

    cvar = FindConVar("mp_endmatch_votenextmap");
    cvar.SetBool(false);
    cvar.AddChangeHook(OnCvarChanged_Disable);

    cvar = FindConVar("mp_match_end_restart");
    cvar.SetBool(false);
    cvar.AddChangeHook(OnCvarChanged_Disable);

    cvar = FindConVar("mp_match_end_changelevel");
    cvar.SetBool(true);
    cvar.AddChangeHook(OnCvarChanged_Enable);
}

public void OnCvarChanged_Disable(ConVar cvar, const char[] nv, const char[] ov)
{
    cvar.SetBool(false, true, true);
}

public void OnCvarChanged_Enable(ConVar cvar, const char[] nv, const char[] ov)
{
    cvar.SetBool(true, true, true);
}