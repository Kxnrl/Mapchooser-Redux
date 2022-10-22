#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <smutils>
#include <mapchooser_redux>

// options
#undef REQUIRE_PLUGIN
#include <store>
#include <shop>
#include <fys.pupd>

Handle g_tVote;
Handle g_tRetry;
Handle g_tWarning;

Menu g_hVoteMenu;

ArrayList g_aMapList;
ArrayList g_aNextMapList;
ArrayList g_aNominations;

int g_iExtends;
int g_iMapFileSerial = -1;
int g_iNominateCount;
int g_iRunoffCount;
bool g_bPartyblock;
bool g_bAllowCountdown;
bool g_bHasVoteStarted;
bool g_bWaitingForVote;
bool g_bMapVoteCompleted;
bool g_bChangeMapInProgress;
bool g_bChangeMapAtRoundEnd;
bool g_bWarningInProgress;
bool g_bBlockedSlots;
bool g_bMapLoaded;

bool g_pStore;
bool g_pShop;

enum TimerLocation
{
    TimerLocation_Hint = 0,
    TimerLocation_Text,
    TimerLocation_Chat,
    TimerLocation_HUD
}

enum struct Convars
{
    ConVar TimeLoc;
    ConVar NameTag;
    ConVar TierTag;
    ConVar DescTag;
    ConVar MaxExts;
    ConVar Recents;
    ConVar LtpMtpl;
    ConVar BCState;
    ConVar Shuffle;
    ConVar Refunds;
    ConVar Require;
    ConVar NoVotes;
    ConVar MinRuns;
    ConVar AutoGen;
}

// tier
char g_TierString[MAX_TIER+1][32] = {
    "", "Intro", "Easy", "Normal", "Hard", "Mars", "Death"
};

// cvars
Convars g_ConVars;

MapChange g_MapChange;

#include "mapchooser/cmds.sp"
#include "mapchooser/cvars.sp"
#include "mapchooser/data.sp"
#include "mapchooser/events.sp"
#include "mapchooser/natives.sp"
#include "mapchooser/stocks.sp"

public Plugin myinfo =
{
    name        = "MapChooser Redux",
    author      = "Kyle",
    description = "Automated Map Voting with Extensions",
    version     = MCR_VERSION,
    url         = "https://kxnrl.com"
};

public void OnPluginStart()
{
    SMUtils_SetChatPrefix("[\x02M\x04C\x0CR\x01]");
    SMUtils_SetChatSpaces("   ");
    SMUtils_SetChatConSnd(false);
    SMUtils_SetTextDest(HUD_PRINTCENTER);

    Cmds_OnPluginStart();
    Cvars_OnPluginStart();
    Data_OnPluginStart();
    Events_OnPluginStart();
    Natives_OnPluginStart();

    LoadTranslations("com.kxnrl.mcr.translations");

    g_aMapList     = new ArrayList(ByteCountToCells(128));
    g_aNextMapList = new ArrayList(ByteCountToCells(128));
    g_aNominations = new ArrayList(sizeof(Nominations));
}

public void OnAllPluginsLoaded()
{
    g_pStore = LibraryExists("store");
    g_pShop = LibraryExists("shop-core");

    Data_OnAllPluginsLoaded();
}

public void Pupd_OnCheckAllPlugins()
{
    Pupd_CheckPlugin(false, "https://build.kxnrl.com/updater/MCR/");
    Pupd_CheckTranslation("com.kxnrl.mcr.translations.txt", "https://build.kxnrl.com/updater/MCR/translation/");
}

public void OnConfigsExecuted()
{
    if (ReadMapList(g_aMapList, g_iMapFileSerial, "mapchooser", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER) != null)
        if (g_iMapFileSerial == -1)
            SetFailState("Unable to create a valid map list.");

    g_aNominations.Clear();

    g_iExtends = 0;
    g_bPartyblock = false;
    g_bAllowCountdown = false;
    g_bMapVoteCompleted = false;
    g_bChangeMapAtRoundEnd = false;
    g_iNominateCount = 0;
    g_bMapLoaded = true;

    CreateNextVote();
    SetupTimeleftTimer();
    Call_MapDataLoaded();
    Call_MapVotePoolChanged();
}

public void OnMapEnd()
{
    g_bMapLoaded = false;
    g_bHasVoteStarted = false;
    g_bWaitingForVote = false;
    g_bChangeMapInProgress = false;

    g_tVote = null;
    g_tRetry = null;
    g_tWarning = null;
    g_iRunoffCount = 0;

    Data_OnMapEnd();
}

public void OnClientConnected(int client)
{
    if (GetClientCount(false) >= g_ConVars.MinRuns.IntValue)
    {
        // allow countdown cooldown
        if (!g_bAllowCountdown)
        {
            char map[128];
            GetCurrentMap(map, 128);
            SetCooldown(map, false);
            SetLastPlayed(map, false);
            SaveMapPool(map);

            // marked
            g_bAllowCountdown = true;
        }
    }
}

public void OnClientDisconnect(int client)
{
    if (!IsClientInGame(client))
        return;

    for (int index = 0; index < g_aNominations.Length; index++)
    {
        Nominations n;
        g_aNominations.GetArray(index, n, sizeof(Nominations));
        if (n.m_Owner == client)
        {
            g_aNominations.Erase(index);
            Call_NominationsReset(n.m_Map, n.m_Owner, g_bPartyblock, NominateResetReason_Disconnect);

            LogMessage("Removed [%s] by %L from nomination list.", n.m_Map, n.m_Owner);

            // party block disconnect
            if (g_bPartyblock)
                g_bPartyblock = false;

            break;
        }
    }
}

/**
 * Notification that the map's time left has changed via a change in the time
 * limit or a change in the game rules (such as mp_restartgame).  This is useful
 * for plugins trying to create timers based on the time left in the map.
 *
 * Calling ExtendMapTimeLimit() from here, without proper precaution, will
 * cause infinite recursion.
 *
 * If the operation is not supported, this will never be called.

 * If the server has not yet processed any frames (i.e. no players have joined
 * the map yet), then this will be called once the server begins ticking, even
 * if there is no time limit set.
 */
public void OnMapTimeLeftChanged()
{
    // anyhow?
    if (!g_bMapLoaded)
        return;

    SetupTimeleftTimer();
}

void SetupTimeleftTimer()
{
    if (g_bMapVoteCompleted)
    {
        PrintToServer("Map vote had been completed.");
        return;
    }

    int timeLeft = GetTimeLeft();

    // if timeLeft <= 0 meaning going to intermission
    if (timeLeft <= 0)
        return;

    if (timeLeft - 300 < 0 && !g_bHasVoteStarted)
    {
        SetupWarningTimer(WarningType_Vote);
        return;
    }
    
    if (g_aMapList.Length <= 0)
    {
        LogError("No enough maps to start the vote.");
        return;
    }

    if (g_tWarning == null)
    {
        if (g_tVote != null)
            KillTimer(g_tVote);

        g_tVote = CreateTimer(float(timeLeft - 300), Timer_StartWarningTimer, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public Action Timer_StartWarningTimer(Handle timer)
{
    g_tVote = null;
    
    if (!g_bWarningInProgress || g_tWarning == null)
        SetupWarningTimer(WarningType_Vote);

    return Plugin_Stop;
}

public Action Timer_StartMapVote(Handle timer, DataPack data)
{
    static int timePassed;

    if (!g_aMapList.Length || g_bMapVoteCompleted || g_bHasVoteStarted)
    {
        g_tWarning = null;
        return Plugin_Stop;
    }

    data.Reset();
    int warningMaxTime = data.ReadCell();
    int warningTimeRemaining = warningMaxTime - timePassed;

    switch(view_as<TimerLocation>(g_ConVars.TimeLoc.IntValue))
    {
        case TimerLocation_Text: tTextAll("%t", g_ConVars.Shuffle.BoolValue ? "mcr countdown text hint shuffle" : "mcr countdown text hint", warningTimeRemaining);
        case TimerLocation_Chat: tChatAll("%t", g_ConVars.Shuffle.BoolValue ? "mcr countdown chat shuffle"      : "mcr countdown chat",      warningTimeRemaining);
        case TimerLocation_Hint: tHintAll("%t", g_ConVars.Shuffle.BoolValue ? "mcr countdown text hint shuffle" : "mcr countdown text hint", warningTimeRemaining);
        case TimerLocation_HUD:  DisplayCountdownHUD(warningTimeRemaining);
    }

    if (timePassed++ >= warningMaxTime)
    {
        if (timer == g_tRetry)
        {
            g_bWaitingForVote = false;
            g_tRetry = null;
        }
        else
        {
            g_tWarning = null;
        }
    
        timePassed = 0;
        MapChange mapChange = view_as<MapChange>(data.ReadCell());
        ArrayList arraylist = view_as<ArrayList>(data.ReadCell());

        InitiateVote(mapChange, arraylist);
        
        return Plugin_Stop;
    }

    return Plugin_Continue;
}

public Action Command_Mapvote(int client, int args)
{
    tChatAll("%t", "mcr voting started");

    SetupWarningTimer(WarningType_Vote, MapChange_MapEnd, null, true);

    LogAction(client, -1, "%L -> called mapvote.", client);

    return Plugin_Handled;    
}

void InitiateVote(MapChange when, ArrayList inputlist)
{
    g_bWaitingForVote = true;
    g_bWarningInProgress = false;

    if (IsVoteInProgress())
    {
        LogMessage("IsVoteInProgress -> %d", FAILURE_TIMER_LENGTH);
        
        DataPack data = new DataPack();
        data.WriteCell(FAILURE_TIMER_LENGTH);
        data.WriteCell(when);
        data.WriteCell(inputlist);
        data.Reset();

        g_tRetry = CreateTimer(1.0, Timer_StartMapVote, data, TIMER_FLAG_NO_MAPCHANGE|TIMER_REPEAT|TIMER_DATA_HNDL_CLOSE);

        return;
    }

    if (g_bMapVoteCompleted && g_bChangeMapInProgress)
        return;

    SetHudTextParams(-1.0, 0.32, 3.5, 0, 255, 255, 255, 0, 0.3, 0.3, 0.3);
    for(int client = 1; client <= MaxClients; ++client)
        if (IsClientInGame(client) && !IsFakeClient(client))
            ShowHudText(client, 0, "%T", "mcr voting started", client);

    g_MapChange = when;
    
    g_bWaitingForVote = false;
    g_bHasVoteStarted = true;

    Handle menuStyle = GetMenuStyleHandle(MenuStyle_Default);

    if (menuStyle != INVALID_HANDLE)
        g_hVoteMenu = CreateMenuEx(menuStyle, Handler_MapVoteMenu, MenuAction_End | MenuAction_Display | MenuAction_DisplayItem | MenuAction_VoteCancel);
    else
        g_hVoteMenu = new Menu(Handler_MapVoteMenu, MenuAction_End | MenuAction_Display | MenuAction_DisplayItem | MenuAction_VoteCancel);

    Handle radioStyle = GetMenuStyleHandle(MenuStyle_Radio);

    if (GetMenuStyle(g_hVoteMenu) == radioStyle)
    {
        g_bBlockedSlots = true;
        if (!g_ConVars.NoVotes.BoolValue)
        {
            g_hVoteMenu.AddItem(LINE_SPACER, "", ITEMDRAW_SPACER);
        }
        g_hVoteMenu.AddItem(LINE_ONE, "Choose something...", ITEMDRAW_DISABLED);
        g_hVoteMenu.AddItem(LINE_TWO, "...will ya?", ITEMDRAW_DISABLED);
    }
    else
        g_bBlockedSlots = false;

    if (g_ConVars.NoVotes.BoolValue)
    {
        g_hVoteMenu.OptionFlags = MENUFLAG_BUTTON_NOVOTE; 
    }

    g_hVoteMenu.SetTitle("选择下一张地图\n ");
    g_hVoteMenu.VoteResultCallback = Handler_MapVoteFinished;

    int shuffleStart = -2;

    if (g_bPartyblock)
    {
        for(int i = 0; i < 5; i++)
        {
            Nominations n;
            g_aNominations.GetArray(0, n, sizeof(Nominations));
            AddMapItem(g_hVoteMenu, n.m_Map, g_ConVars.NameTag.BoolValue, g_ConVars.TierTag.BoolValue, !g_ConVars.DescTag.BoolValue, n.m_Owner, i == 0 ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
        }

        //AddExtendToMenu(g_hVoteMenu, when);
    }
    else if (inputlist == null)
    {
        char map[128];
        int voteSize = 5, nominationsToAdd = g_aNominations.Length >= voteSize ? voteSize : g_aNominations.Length;

        static ArrayList votePool = null;
        if (votePool != null)
            delete votePool;
        votePool = new ArrayList(sizeof(Nominations));

        if (g_ConVars.Shuffle.BoolValue && g_aNominations.Length >= g_ConVars.Require.IntValue)
        {
            // all maps should be shuffle.
            shuffleStart = -1;

            // randomly pool
            for(int i = 0; i < nominationsToAdd; i++)
            {
                Nominations n;
                g_aNominations.GetArray(i, n, sizeof(Nominations));
                votePool.PushArray(n, sizeof(Nominations));
                RemoveStringFromArray(g_aNextMapList, n.m_Map);
            }

            if (votePool.Length < voteSize && g_aNextMapList.Length == 0)
            {
                if (votePool.Length == 0)
                {
                    LogMessage("No maps available for vote.");
                    return;
                }
                else
                {
                    LogMessage("No enough maps to fill map list.");
                    voteSize = votePool.Length;
                }
            }
            int count = 0;
            while(votePool.Length < voteSize && count < g_aNextMapList.Length)
            {
                g_aNextMapList.GetString(count, map, 128);        
                count++;

                Nominations n;
                strcopy(n.m_Map, 128, map);
                n.m_Owner = -1;
                votePool.PushArray(n, sizeof(Nominations));
            }
            // Randomly menu
            while (votePool.Length > 0)
            {
                Nominations n;
                int i = RandomInt(0, votePool.Length - 1);
                votePool.GetArray(i, n, sizeof(Nominations));
                votePool.Erase(i);
                AddMapItem(g_hVoteMenu, n.m_Map, g_ConVars.NameTag.BoolValue, g_ConVars.TierTag.BoolValue, !g_ConVars.DescTag.BoolValue, n.m_Owner);
            }
        }
        else
        {
            // we just shuffle random maps
            shuffleStart = nominationsToAdd - 1;
            
            for(int i = 0; i < nominationsToAdd; i++)
            {
                Nominations n;
                g_aNominations.GetArray(i, n, sizeof(Nominations));

                AddMapItem(g_hVoteMenu, n.m_Map, g_ConVars.NameTag.BoolValue, g_ConVars.TierTag.BoolValue, !g_ConVars.DescTag.BoolValue, n.m_Owner);
                RemoveStringFromArray(g_aNextMapList, map);
            }

            int i = nominationsToAdd;
            int count = 0;

            if (i < voteSize && g_aNextMapList.Length == 0)
            {
                if (i == 0)
                {
                    LogMessage("No maps available for vote.");
                    return;
                }
                else
                {
                    LogMessage("Not enough maps to fill map list.");
                    voteSize = i;
                }
            }

            while(i < voteSize && count < g_aNextMapList.Length)
            {
                g_aNextMapList.GetString(count, map, 128);        
                count++;

                AddMapItem(g_hVoteMenu, map, g_ConVars.NameTag.BoolValue, g_ConVars.TierTag.BoolValue, !g_ConVars.DescTag.BoolValue);
                i++;
            }
        }

        //g_aNominations.Clear();

        AddExtendToMenu(g_hVoteMenu, when);
    }
    else
    {
        char map[128];
        for(int i = 0; i < inputlist.Length; i++)
        {
            inputlist.GetString(i, map, 128);

            if (IsMapValid(map))
                AddMapItem(g_hVoteMenu, map, g_ConVars.NameTag.BoolValue, g_ConVars.TierTag.BoolValue, !g_ConVars.DescTag.BoolValue, GetNominationOwner(map));
            else if (StrEqual(map, VOTE_DONTCHANGE))
                g_hVoteMenu.AddItem(VOTE_DONTCHANGE, "Don't Change");
            else if (StrEqual(map, VOTE_EXTEND))
                g_hVoteMenu.AddItem(VOTE_EXTEND, "Extend Map");
        }
        delete inputlist;
    }

    if (5 <= GetMaxPageItems(GetMenuStyle(g_hVoteMenu)))
        g_hVoteMenu.Pagination = MENU_NO_PAGINATION;

    LogMessage("g_hVoteMenu -> shuffleStart = %d | count = %d", shuffleStart, g_hVoteMenu.ItemCount);

    if (shuffleStart > -2)
    {
        // HACK
        // if using shuffle
        // we start at index 4 ~ 8
        g_hVoteMenu.ShufflePerClient(shuffleStart + 4, 8);
    }

    g_hVoteMenu.DisplayVoteToAll(15);

    Call_MapVoteStarted();

    LogAction(-1, -1, "Voting for next map has started.");
    tChatAll("%t", "mcr voting started");
}

public void Handler_VoteFinishedGeneric(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    char map[128];
    GetMapItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], map, 128);

    Call_MapVoteEnd(map, g_bPartyblock, GetMapNominator(map));

    if (strcmp(map, VOTE_EXTEND, false) == 0)
    {
        g_iExtends++;

        int timeLimit;
        if (GetMapTimeLimit(timeLimit))
            if (timeLimit > 0)
                ExtendMapTimeLimit(1200);                        

        tChatAll("%t", "mcr extend map", item_info[0][VOTEINFO_ITEM_VOTES], num_votes);
        LogAction(-1, -1, "Voting for next map has finished. The current map has been extended.");

        g_bHasVoteStarted = false;
        CreateNextVote();
        SetupTimeleftTimer();
    }
    else if (strcmp(map, VOTE_DONTCHANGE, false) == 0)
    {
        tChatAll("%t", "mcr dont change", item_info[0][VOTEINFO_ITEM_VOTES], num_votes);
        LogAction(-1, -1, "Voting for next map has finished. 'No Change' was the winner");
        
        g_bHasVoteStarted = false;
        CreateNextVote();
        SetupTimeleftTimer();
    }
    else
    {
        if (g_MapChange == MapChange_Instant)
        {
            g_bChangeMapInProgress = true;
            CreateTimer(10.0 , Timer_ChangeMaprtv, _, TIMER_FLAG_NO_MAPCHANGE);
        }
        else if (g_MapChange == MapChange_RoundEnd)
        {
            g_bChangeMapAtRoundEnd = true;
            FindConVar("mp_halftime").SetInt(0);
            FindConVar("mp_timelimit").SetInt(0);
            FindConVar("mp_maxrounds").SetInt(0);
            FindConVar("mp_roundtime").SetInt(1);
        }

        FindConVar("nextlevel").SetString(map);
        SetNextMap(map);

        g_bHasVoteStarted = false;
        g_bMapVoteCompleted = true;
        
        tChatAll("%t", "mcr next map", map, item_info[0][VOTEINFO_ITEM_VOTES], num_votes);
        if (g_ConVars.DescTag.BoolValue)
        {
            char desc[128];
            GetDescEx(map, desc, 128, _, _, _, true);
            SMUtils_SkipNextPrefix();
            ChatAll("\x0E ➤ \x0E ➢ \x0E ➣ \x01  \x0A[\x05%s\x0A]", desc);
        }
        LogAction(-1, -1, "Voting for next map has finished. Nextmap: %s.", map);
    }

    // refunds
    RefundAllCredits(map);

    // reset
    g_bPartyblock = false;
}


public Action Timer_ChangeMaprtv(Handle hTimer)
{
    FindConVar("mp_halftime").SetInt(0);
    FindConVar("mp_timelimit").SetInt(0);
    FindConVar("mp_maxrounds").SetInt(0);
    FindConVar("mp_roundtime").SetInt(1);

    for(int client = 1; client <= MaxClients; ++client)
    if (IsClientInGame(client))
    if (IsPlayerAlive(client))
    ForcePlayerSuicide(client);

    CreateTimer(60.0, Timer_ChangeMap, 0, TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Stop;
}

public void Handler_MapVoteFinished(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    if (num_items > 1 && g_iRunoffCount < 1)
    {
        g_iRunoffCount++;
        int highest_votes = item_info[0][VOTEINFO_ITEM_VOTES];
        int required_percent = 50;
        int required_votes = RoundToCeil(float(num_votes) * float(required_percent) / 100);
        
        if (highest_votes == item_info[1][VOTEINFO_ITEM_VOTES])
        {
            g_bHasVoteStarted = false;

            ArrayList mapList = new ArrayList(ByteCountToCells(128));

            for(int i = 0; i < num_items; i++)
            {
                if (item_info[i][VOTEINFO_ITEM_VOTES] == highest_votes)
                {
                    char map[128];
                    GetMapItem(menu, item_info[i][VOTEINFO_ITEM_INDEX], map, 128);
                    mapList.PushString(map);
                }
                else
                    break;
            }
            
            tChatAll("%t", "mcr tier", mapList.Length);
            SetupWarningTimer(WarningType_Revote, view_as<MapChange>(g_MapChange), mapList);
            return;
        }
        else if (highest_votes < required_votes)
        {
            g_bHasVoteStarted = false;

            ArrayList mapList = new ArrayList(ByteCountToCells(128));

            char map[128];
            GetMapItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], map, 128);

            mapList.PushString(map);

            for(int i = 1; i < num_items; i++)
            {
                if (mapList.Length < 2 || item_info[i][VOTEINFO_ITEM_VOTES] == item_info[i - 1][VOTEINFO_ITEM_VOTES])
                {
                    GetMapItem(menu, item_info[i][VOTEINFO_ITEM_INDEX], map, 128);
                    mapList.PushString(map);
                }
                else
                    break;
            }
            tChatAll("%t", "mcr runoff", required_percent);
            SetupWarningTimer(WarningType_Revote, view_as<MapChange>(g_MapChange), mapList);
            return;
        }
    }

    Handler_VoteFinishedGeneric(menu, num_votes, num_clients, client_info, num_items, item_info);
}

public int Handler_MapVoteMenu(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_End:
        {
            g_hVoteMenu = null;
            delete menu;
        }
        case MenuAction_Display:
        {
            char text[32];
            FormatEx(text, 32, "%T \n ", "vote item title", param1);
            SetPanelTitle(view_as<Handle>(param2), text);
        }
        case MenuAction_DisplayItem:
        {
            char map[128];
            char buffer[128];

            menu.GetItem(param2, map, 128, _, _, _, param1);

            if (StrEqual(map, VOTE_EXTEND, false))
                FormatEx(buffer, 128, "%T", "vote item extend", param1);
            else if (StrEqual(map, VOTE_DONTCHANGE, false))
                FormatEx(buffer, 128, "%T", "vote item dont change", param1);
            else if (StrEqual(map, LINE_ONE, false))
                FormatEx(buffer, 128, "%T", "LINE_ONE", param1);
            else if (StrEqual(map, LINE_TWO, false))
                FormatEx(buffer, 128, "%T", "LINE_TWO", param1);

            if (buffer[0] != '\0')
                return RedrawMenuItem(buffer);
        }
        case MenuAction_VoteCancel:
        {
            if (param1 == VoteCancel_NoVotes)
            {
                int count = GetMenuItemCount(menu);
                
                int item;
                char map[128];
                
                do
                {
                    int startInt = 0;
                    if (g_bBlockedSlots)
                        startInt = 2;
                    item = RandomInt(startInt, count - 1);
                    menu.GetItem(item, map, 128, _, _, _, -1);
                }
                while(strcmp(map, VOTE_EXTEND, false) == 0);

                SetNextMap(map);
                g_bMapVoteCompleted = true;
            }
            g_bHasVoteStarted = false;
        }
    }

    return 0;
}

public Action Timer_ChangeMap(Handle timer)
{
    g_bChangeMapInProgress = false;

    char map[128];
    
    if (!GetNextMap(map, 128))
    {
        ThrowError("Timer_ChangeMap -> !GetNextMap");
        return Plugin_Stop;    
    }

    LogMessage("Timer_ChangeMap -> ForceChangeLevel -> %s", map);
    ForceChangeLevel(map, "Map Vote");
 
    return Plugin_Stop;
}

bool RemoveStringFromArray(ArrayList array, const char[] str)
{
    int index = array.FindString(str);
    if (index != -1)
    {
        array.Erase(index);
        return true;
    }

    return false;
}

void CreateNextVote()
{
    g_aNextMapList.Clear();

    ArrayList tempMaps = g_aMapList.Clone();

    ShuffleStringArray(tempMaps);

    char map[128];
    GetCurrentMap(map, 128);
    RemoveStringFromArray(tempMaps, map);

    for(int x = 0; x < tempMaps.Length; ++x)
    {
        tempMaps.GetString(x, map, 128);
        // we remove big maps( >150 will broken fastdl .bz2), nice map, and only nominations, in cooldown, is not in certain times, requires min players.
        if (IsBigMap(map) || 
            IsNominateOnly(map) || 
            IsAdminOnly(map) || 
            IsVIPOnly(map) || 
            GetCooldown(map) > 0 || 
            IsCertainTimes(map) == false || 
            GetMinPlayers(map) > 0 ||
            IsDisabled(map))
        {
            tempMaps.Erase(x);
            x--;
        }
    }

    int players = GetRealPlayers();
    for(int x = 0; x < tempMaps.Length; ++x)
    {
        tempMaps.GetString(x, map, 128);
        // we remove map if player amount not match with configs
        int max = GetMaxPlayers(map);
        int min = GetMinPlayers(map);
        if ((min != 0 && players < min) || (max != 0 && players > max))
        {
            tempMaps.Erase(x);
            x--;
        }
    }

    // check outside forward
    for(int x = 0; x < tempMaps.Length; ++x)
    {
        tempMaps.GetString(x, map, 128);
        if (!AllowInNextVotePool(map))
        {
            tempMaps.Erase(x);
            x--;
        }
    }

    int limit = (5 < tempMaps.Length ? 5 : tempMaps.Length);

    for(int i = 0; i < limit; i++)
    {
        int b = RandomInt(0, tempMaps.Length - 1);
        tempMaps.GetString(b, map, 128);
        g_aNextMapList.PushString(map);
        tempMaps.Erase(b);
    }

    delete tempMaps;
}

bool CanVoteStart()
{
    if (g_bWaitingForVote || g_bHasVoteStarted)
        return false;

    return true;
}

bool InternalSetNextMap(const char[] map, int client)
{
    if (!Call_OnSetNextMap(map, client) || IsDisabled(map))
        return false;

    SetNextMap(map);
    Call_SetNextMapManually(map, client);
    g_bMapVoteCompleted = true;
    RefundAllCredits(map);
    return true;
}

NominateResult InternalNominateMap(const char[] map, bool force, int owner, bool partyblock)
{
    if (!IsMapValid(map) || IsDisabled(map))
        return NominateResult_InvalidMap;

    if (!Call_OnNominateMap(map, owner, partyblock, false))
    {
        // rejected
        return NominateResult_Reject;
    }

    for (int i = 0; i < g_aNominations.Length; i++)
    {
        Nominations n;
        g_aNominations.GetArray(i, n, sizeof(Nominations));
        if (strcmp(n.m_Map, map) == 0)
            return NominateResult_AlreadyInVote;
    }

    if (g_aNominations.Length >= 5 && !force)
        return NominateResult_VoteFull;

    if (IsVIPOnly(map) && !IsClientVIP(owner))
        return NominateResult_VIPOnly;

    if (IsAdminOnly(map) && !IsClientAdmin(owner))
        return NominateResult_AdminOnly;

    if (GetCooldown(map) > 0)
        return NominateResult_RecentlyPlayed;

    if (!IsCertainTimes(map))
        return NominateResult_CertainTimes;

    int max = GetMaxPlayers(map);
    if (max != 0 && GetRealPlayers() > max)
        return NominateResult_MaxPlayers;
    
    int min = GetMinPlayers(map);
    if (min != 0 && GetRealPlayers() < min)
        return NominateResult_MinPlayers;

    if (g_pStore && Store_GetClientCredits(owner) < GetPrice(map))
        return NominateResult_NoCredits;

    if (g_pShop && MG_Shop_GetClientMoney(owner) < GetPrice(map))
        return NominateResult_NoCredits;

    if (g_bPartyblock)
        return NominateResult_PartyBlock;

    if (partyblock && owner)
    {
        if (!g_ConVars.BCState.BoolValue)
        {
            // ?
            return NominateResult_PartyBlockDisabled;
        }

        int price = GetPrice(map, false, true); Nominations n;
        if (!Call_OnNominatePrice(map, owner, price, partyblock))
        {
            // block
            return NominateResult_NoCredits;
        }

        for (int i = 0; i < g_aNominations.Length; i++)
        {
            g_aNominations.GetArray(i, n, sizeof(Nominations));
            price += n.m_Price;
            PrintToServer("Foreach [%s] niminations list.", n.m_Map);
        }

        if (g_pStore && Store_GetClientCredits(owner) < price)
            return NominateResult_NoCredits;

        if (g_pShop && MG_Shop_GetClientMoney(owner) < price)
            return NominateResult_NoCredits;

        while (g_aNominations.Length > 0)
        {
            g_aNominations.GetArray(0, n, sizeof(Nominations));
            g_aNominations.Erase(0);
            Call_NominationsReset(n.m_Map, n.m_Owner, false, NominateResetReason_PartyBlock);
            PrintToServer("Erase [%s] niminations list.", n.m_Map);

            int refund = GetRefundCreditsByNomination(n);

            char reason[128];
            FormatEx(reason, sizeof(reason), "nomination-refund-partyblock-[%s]", n.m_Map);

            if (ClientIsValid(n.m_Owner) && refund > 0)
            if (g_pStore)
            {
                Store_SetClientCredits(n.m_Owner, Store_GetClientCredits(n.m_Owner)+refund, reason);
                Chat(n.m_Owner, "%T", "mcr nominate fallback", n.m_Owner, n.m_Map, refund);
            }
            else if (g_pShop)
            {
                MG_Shop_ClientEarnMoney(n.m_Owner, refund, reason);
                Chat(n.m_Owner, "%T", "mcr nominate fallback", n.m_Owner, n.m_Map, refund);
            }

            LogMessage("%L was remove from nominations list with map [%s]", n.m_Owner, n.m_Map);
        }

        char reason[128];
        FormatEx(reason, sizeof(reason), "nomination-partyblock-[%s]", map);

        if (g_pStore)
        {
            Store_SetClientCredits(owner, Store_GetClientCredits(owner)-price, reason);
            Chat(owner, "%T", "nominate partyblock cost", owner, map, price);
        }
        else if (g_pShop)
        {
            MG_Shop_ClientCostMoney(owner, price, reason);
            Chat(owner, "%T", "nominate partyblock cost", owner, map, price);
        }

        n.m_Owner = owner;
        n.m_Price = price;
        strcopy(n.m_Map, 128, map);
        GetClientName(owner, n.m_OwnerName, 25);
        GetClientAuthId(owner, AuthId_Steam2, n.m_OwnerAuth, 32);
        g_aNominations.PushArray(n, sizeof(Nominations));
        g_bPartyblock = true;
        Call_OnNominatedMap(map, owner, partyblock, false);
        return NominateResult_PartyBlockAdded;
    }

    if (owner)
    for (int i = 0; i < g_aNominations.Length; i++)
    {
        Nominations n;
        g_aNominations.GetArray(i, n, sizeof(Nominations));

        if (n.m_Owner == owner)
        {
            Call_NominationsReset(n.m_Map, n.m_Owner, false, NominateResetReason_Replace);

            int price = GetPrice(map);
            if (!Call_OnNominatePrice(map, owner, price, partyblock))
            {
                // block
                return NominateResult_NoCredits;
            }

            int refund = GetRefundCreditsByNomination(n);

            char reason[256];
            FormatEx(reason, sizeof(reason), "nomination-replace-[%s]->[%s]", n.m_Map, map);

            if (g_pStore)
            {
                Store_SetClientCredits(owner, Store_GetClientCredits(owner)+refund-price, reason);
                Chat(owner, "%T", "mcr nominate fallback", owner, n.m_Map, refund);
                Chat(owner, "%T", "nominate nominate cost", owner, map, price);
            }
            else if (g_pShop)
            {
                MG_Shop_ClientEarnMoney(owner, refund, reason);
                Chat(owner, "%T", "mcr nominate fallback", owner, n.m_Map, refund);
                MG_Shop_ClientCostMoney(owner, price, "nomination-nominate");
                Chat(owner, "%T", "nominate nominate cost", owner, map, price);
            }

            strcopy(n.m_Map, 128, map);
            n.m_Owner = owner;
            n.m_Price = price;
            g_aNominations.SetArray(i, n, sizeof(Nominations));

            Call_OnNominatedMap(map, owner, partyblock, true);
            return NominateResult_Replaced;
        }
    }

    while(g_aNominations.Length > 5)
    {
        Nominations n;
        g_aNominations.GetArray(0, n, sizeof(Nominations));
        Call_NominationsReset(n.m_Map, n.m_Owner, false, NominateResetReason_ForceFull);
        g_aNominations.Erase(0);
    }

    int price = GetPrice(map);
    if (!Call_OnNominatePrice(map, owner, price, partyblock))
    {
        // block
        return NominateResult_NoCredits;
    }

    if (ClientIsValid(owner) && price > 0)
    {
        char reason[256];
        FormatEx(reason, sizeof(reason), "nomination-nominate-[%s]", map);

        if (g_pStore)
        {
            Store_SetClientCredits(owner, Store_GetClientCredits(owner)-price, reason);
            Chat(owner, "%T", "nominate nominate cost", owner, map, price);
        }
        else if (g_pShop)
        {
            MG_Shop_ClientCostMoney(owner, price, reason);
            Chat(owner, "%T", "nominate nominate cost", owner, map, price);
        }
    }

    Nominations n;
    n.m_Owner = owner;
    n.m_Price = price;
    strcopy(n.m_Map, 128, map);
    GetClientName(owner, n.m_OwnerName, 25);
    GetClientAuthId(owner, AuthId_Steam2, n.m_OwnerAuth, 32);
    g_aNominations.PushArray(n, sizeof(Nominations));
    Call_OnNominatedMap(map, owner, partyblock, false);
    return NominateResult_Added;
}

bool InternalRemoveNominationByOwner(int owner)
{
    for (int i = 0; i < g_aNominations.Length; i++)
    {
        Nominations n;
        g_aNominations.GetArray(i, n, sizeof(Nominations));
        if (n.m_Owner == owner)
        {
            int refund = GetRefundCreditsByNomination(n);

            if (ClientIsValid(n.m_Owner) && refund > 0)
            {
                char reason[128];
                FormatEx(reason, sizeof(reason), "nomination-refund-internal-owner-[%s]", n.m_Map);

                if (g_pStore)
                {
                    Store_SetClientCredits(owner, Store_GetClientCredits(owner)+refund, reason);
                    Chat(owner, "%T", "mcr nominate fallback", owner, n.m_Map, refund);
                }
                else if (g_pShop)
                {
                    MG_Shop_ClientEarnMoney(owner, refund, reason);
                    Chat(owner, "%T", "mcr nominate fallback", owner, n.m_Map, refund);
                }
            }

            g_aNominations.Erase(i);
            Call_NominationsReset(n.m_Map, n.m_Owner, g_bPartyblock, NominateResetReason_Remove);
            return true;
        }
    }

    return false;
}

bool InternalRemoveNominationByMap(const char[] map)
{
    for (int i = 0; i < g_aNominations.Length; i++)
    {
        Nominations n;
        g_aNominations.GetArray(i, n, sizeof(Nominations));
        if (strcmp(map, n.m_Map) == 0)
        {
            int refund = GetRefundCreditsByNomination(n);

            if (ClientIsValid(n.m_Owner) && refund > 0)
            {
                char reason[128];
                FormatEx(reason, sizeof(reason), "nomination-refund-internal-map-[%s]", n.m_Map);

                if (g_pStore)
                {
                    Store_SetClientCredits(n.m_Owner, Store_GetClientCredits(n.m_Owner)+refund, reason);
                    Chat(n.m_Owner, "%T", "mcr nominate fallback", n.m_Owner, n.m_Map, refund);
                }
                else if (g_pShop)
                {
                    MG_Shop_ClientEarnMoney(n.m_Owner, refund, reason);
                    Chat(n.m_Owner, "%T", "mcr nominate fallback", n.m_Owner, n.m_Map, refund);
                }
            }

            g_aNominations.Erase(i);
            Call_NominationsReset(n.m_Map, n.m_Owner, g_bPartyblock, NominateResetReason_Remove);
            return true;
        }
    }

    return false;
}

int GetMapNominator(const char[] map)
{
    while (g_aNominations.Length > 0)
    {
        Nominations n;
        g_aNominations.GetArray(0, n, sizeof(Nominations));

        if (strcmp(map, n.m_Map) == 0)
        {
            // skip passing map
            return FindClientByAuth(n.m_OwnerAuth);
        }
    }

    return -1;
}

void RefundAllCredits(const char[] map)
{
    while (g_aNominations.Length > 0)
    {
        Nominations n;
        g_aNominations.GetArray(0, n, sizeof(Nominations));

        g_aNominations.Erase(0);
        Call_NominationsReset(n.m_Map, n.m_Owner, g_bPartyblock, NominateResetReason_Refund);

        if (strcmp(map, n.m_Map) == 0)
        {
            // skip passing map
            Call_NominationsVoted(n.m_Map, n.m_OwnerName, n.m_OwnerAuth);
            continue;
        }

        if (g_bPartyblock)
        {
            // skip all partyblocks
            continue;
        }

        int refund = GetRefundCreditsByNomination(n);

        if (refund > 0 && ClientIsValid(n.m_Owner))
        {
            char reason[128];
            FormatEx(reason, sizeof(reason), "nomination-refund-fallback-map-[%s]", n.m_Map);
            
            if (g_pStore)
            {
                Store_SetClientCredits(n.m_Owner, Store_GetClientCredits(n.m_Owner)+refund, reason);
                Chat(n.m_Owner, "%T", "mcr nominate fallback", n.m_Owner, n.m_Map, refund);
            }
            else if (g_pShop)
            {
                MG_Shop_ClientEarnMoney(n.m_Owner, refund, reason);
                Chat(n.m_Owner, "%T", "mcr nominate fallback", n.m_Owner, n.m_Map, refund);
            }
        }
    }

    g_aNominations.Clear();
}