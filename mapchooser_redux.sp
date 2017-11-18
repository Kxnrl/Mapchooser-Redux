#include <mapchooser_redux>
#include <nextmap>
#include <store>
#include <cstrike>
#include <sdktools>

// options
#undef REQUIRE_PLUGIN
#include <cg_core>

#pragma newdecls required

Handle g_NominationsResetForward;
Handle g_MapVoteStartedForward;
Handle g_MapVoteEndForward;
Handle g_MapDataLoadedForward;

Handle g_tVote;
Handle g_tRetry;
Handle g_tWarning;

Handle g_hVoteMenu;

ArrayList g_aMapList;
ArrayList g_aNominateList;
ArrayList g_aNominateOwners;
ArrayList g_aOldMapList;
ArrayList g_aNextMapList;

int g_iExtends;
int g_iMapFileSerial = -1;
int g_iNominateCount;
int g_iRunoffCount;
bool g_bHasVoteStarted;
bool g_bWaitingForVote;
bool g_bMapVoteCompleted;
bool g_bChangeMapInProgress;
bool g_bChangeMapAtRoundEnd;
bool g_bWarningInProgress;
bool g_bBlockedSlots;

bool g_bZombieEscape;
bool g_srvCSGOGAMERS;
bool g_bHookEventEnd;

MapChange g_eChangeTime;

enum TimerLocation
{
    TimerLocation_Hint = 0,
    TimerLocation_Center = 1,
    TimerLocation_Chat = 2,
    TimerLocation_HUD = 3
}
// Edit this to config Warning HUD.
TimerLocation g_TimerLocation = TimerLocation_HUD;

enum WarningType
{
    WarningType_Vote,
    WarningType_Revote
}


//credits: https://github.com/powerlord/sourcemod-mapchooser-extended
//credits: https://github.com/alliedmodders/sourcemod/blob/master/plugins/

public Plugin myinfo =
{
    name        = "MapChooser Redux",
    author      = "Kyle",
    description = "Automated Map Voting with Extensions",
    version     = MCR_VERSION,
    url         = "http://steamcommunity.com/id/_xQy_/"
};

public void OnPluginStart()
{
    int iArraySize = ByteCountToCells(256);
    g_aMapList = CreateArray(iArraySize);
    g_aNominateList = CreateArray(iArraySize);
    g_aNominateOwners = CreateArray(1);
    g_aOldMapList = CreateArray(iArraySize);
    g_aNextMapList = CreateArray(iArraySize);

    RegAdminCmd("sm_mapvote", Command_Mapvote, ADMFLAG_CHANGEMAP, "sm_mapvote - Forces MapChooser to attempt to run a map vote now.");
    RegAdminCmd("sm_setnextmap", Command_SetNextmap, ADMFLAG_CHANGEMAP, "sm_setnextmap <map>");

    g_NominationsResetForward = CreateGlobalForward("OnNominationRemoved", ET_Ignore, Param_String, Param_Cell);
    g_MapVoteStartedForward = CreateGlobalForward("OnMapVoteStarted", ET_Ignore);
    g_MapVoteEndForward = CreateGlobalForward("OnMapVoteEnd", ET_Ignore, Param_String);
    g_MapDataLoadedForward = CreateGlobalForward("OnMapDataLoaded", ET_Ignore);

    HookEvent("cs_win_panel_match", Event_WinPanel, EventHookMode_Post);
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    if(!CleanPlugin())
    {
        strcopy(error, err_max, "can not clean files.");
        return APLRes_Failure;
    }
    
    RegPluginLibrary("mapchooser");

    CreateNative("NominateMap", Native_NominateMap);
    CreateNative("RemoveNominationByMap", Native_RemoveNominationByMap);
    CreateNative("RemoveNominationByOwner", Native_RemoveNominationByOwner);
    CreateNative("InitiateMapChooserVote", Native_InitiateVote);
    CreateNative("CanMapChooserStartVote", Native_CanVoteStart);
    CreateNative("HasEndOfMapVoteFinished", Native_CheckVoteDone);
    CreateNative("GetExcludeMapList", Native_GetExcludeMapList);
    CreateNative("GetNominatedMapList", Native_GetNominatedMapList);
    CreateNative("EndOfMapVoteEnabled", Native_EndOfMapVoteEnabled);
    CreateNative("CanNominate", Native_CanNominate);
    
    MarkNativeAsOptional("CG_ShowGameTextAll");
    MarkNativeAsOptional("CG_ClientIsVIP");

    return APLRes_Success;
}

public void OnLibraryAdded(const char[] name)
{
    if(strcmp(name, "csgogamers") == 0)
        g_srvCSGOGAMERS = true;
}

public void OnLibraryRemoved(const char[] name)
{
    if(strcmp(name, "csgogamers") == 0)
        g_srvCSGOGAMERS = false;
}

public void CG_OnServerLoaded()
{
    g_srvCSGOGAMERS = true;
}

public void OnConfigsExecuted()
{
    g_srvCSGOGAMERS = LibraryExists("csgogamers");

    if(g_srvCSGOGAMERS)
        g_bHookEventEnd = HookEventEx("round_end", Event_RoundEnd, EventHookMode_Post);
    
    CheckMapCycle();
    BuildKvMapData();
    CheckMapData();
    
    g_bZombieEscape = (FindPluginByFile("zombiereloaded.smx") != INVALID_HANDLE);

    if(ReadMapList(g_aMapList, g_iMapFileSerial, "mapchooser", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER) != INVALID_HANDLE)
        if(g_iMapFileSerial == -1)
            SetFailState("Unable to create a valid map list.");

    SetConVarBool(FindConVar("mp_endmatch_votenextmap"), false);

    CreateNextVote();
    SetupTimeleftTimer();

    g_iExtends = 0;
    g_bMapVoteCompleted = false;
    g_bChangeMapAtRoundEnd = false;
    g_iNominateCount = 0;

    ClearArray(g_aNominateList);
    ClearArray(g_aNominateOwners);

    if(GetArraySize(g_aOldMapList) < 1)
    {
        char filepath[128];
        BuildPath(Path_SM, filepath, 128, "data/mapchooser_oldlist.txt");
    
        if(!FileExists(filepath))
            return;

        Handle file;
        if((file = OpenFile(filepath, "r")) != INVALID_HANDLE)
        {
            ClearArray(g_aOldMapList);

            char fileline[128];

            while(ReadFileLine(file, fileline, 128))
            {
                TrimString(fileline);

                if(!StrContains(fileline, "de_", false) || !StrContains(fileline, "cs_", false) || !StrContains(fileline, "gd_", false) || !StrContains(fileline, "train", false) || !StrContains(fileline, "ar_", false))
                    continue;
                
                PushArrayString(g_aOldMapList, fileline);
            }

            CloseHandle(file);
        }
    }
}

public void OnMapEnd()
{
    if(g_bHookEventEnd)
        UnhookEvent("round_end", Event_RoundEnd, EventHookMode_Post);

    g_bHasVoteStarted = false;
    g_bWaitingForVote = false;
    g_bChangeMapInProgress = false;

    g_tVote = INVALID_HANDLE;
    g_tRetry = INVALID_HANDLE;
    g_tWarning = INVALID_HANDLE;
    g_iRunoffCount = 0;
    
    char map[128];
    GetCurrentMap(map, 128);
    PushArrayString(g_aOldMapList, map);
    
    int maxOld = 15;
    if(g_bZombieEscape) maxOld = 60;

    if(GetArraySize(g_aOldMapList) > maxOld)
        RemoveFromArray(g_aOldMapList, 0);
    
    char filepath[128];
    BuildPath(Path_SM, filepath, 128, "data/mapchooser_oldlist.txt");

    if(FileExists(filepath))
        DeleteFile(filepath);

    Handle file = OpenFile(filepath, "w");

    if(file == INVALID_HANDLE)
    {
        LogError("Open old map list fialed");
        return;
    }

    int size = GetArraySize(g_aOldMapList);

    for(int i = 0; i < size; ++i)
    {
        GetArrayString(g_aOldMapList, i, map, 128);
        WriteFileLine(file, map);
    }

    CloseHandle(file);
}

public void OnClientDisconnect(int client)
{
    int index = FindValueInArray(g_aNominateOwners, client);

    if(index == -1)
        return;
    
    char oldmap[256];
    GetArrayString(g_aNominateList, index, oldmap, 256);
    Call_StartForward(g_NominationsResetForward);
    Call_PushString(oldmap);
    Call_PushCell(GetArrayCell(g_aNominateOwners, index));
    Call_Finish();

    RemoveFromArray(g_aNominateOwners, index);
    RemoveFromArray(g_aNominateList, index);
    g_iNominateCount--;
}

public Action Command_SetNextmap(int client, int args)
{
    if(args < 1)
    {
        ReplyToCommand(client, "[\x04MCR\x01]  Usage: sm_setnextmap <map>");
        return Plugin_Handled;
    }

    char map[256];
    GetCmdArg(1, map, 256);

    if(!IsMapValid(map))
    {
        ReplyToCommand(client, "[\x04MCR\x01]  地图无效[%s]", map);
        return Plugin_Handled;
    }

    LogAction(client, -1, "\"%L\" changed nextmap to \"%s\"", client, map);

    SetNextMap(map);
    g_bMapVoteCompleted = true;

    return Plugin_Handled;
}

public void OnMapTimeLeftChanged()
{
    if(GetArraySize(g_aMapList))
        SetupTimeleftTimer();
}

void SetupTimeleftTimer()
{
    int timeLeft;
    if(GetMapTimeLeft(timeLeft) && timeLeft > 0)
    {
        if(timeLeft - 300 < 0 && !g_bMapVoteCompleted && !g_bHasVoteStarted)
            SetupWarningTimer(WarningType_Vote);
        else
        {
            if(g_tWarning == INVALID_HANDLE)
            {
                if(g_tVote != INVALID_HANDLE)
                {
                    KillTimer(g_tVote);
                    g_tVote = INVALID_HANDLE;
                }    

                int timeLimit;
                GetMapTimeLimit(timeLimit);
                g_tVote = CreateTimer(float(timeLimit*60 - 300), Timer_StartWarningTimer, _, TIMER_FLAG_NO_MAPCHANGE);
            }
        }        
    }
}

public Action Timer_StartWarningTimer(Handle timer)
{
    g_tVote = INVALID_HANDLE;
    
    if(!g_bWarningInProgress || g_tWarning == INVALID_HANDLE)
        SetupWarningTimer(WarningType_Vote);
}

public Action Timer_StartMapVote(Handle timer, Handle data)
{
    static int timePassed;

    if(!GetArraySize(g_aMapList) || g_bMapVoteCompleted || g_bHasVoteStarted)
    {
        g_tWarning = INVALID_HANDLE;
        return Plugin_Stop;
    }

    ResetPack(data);
    int warningMaxTime = ReadPackCell(data);
    int warningTimeRemaining = warningMaxTime - timePassed;

    char warningPhrase[32];
    ReadPackString(data, warningPhrase, 32);

    if(timePassed == 0)
    {
        switch(g_TimerLocation)
        {
            case TimerLocation_Center: PrintCenterTextAll(warningPhrase, warningTimeRemaining);
            case TimerLocation_Chat: PrintToChatAll("[\x04MCR\x01]  %s", warningPhrase, warningTimeRemaining);
            case TimerLocation_Hint: PrintHintTextToAll(warningPhrase, warningTimeRemaining);
            case TimerLocation_HUD: DisplayHUDToAll(warningPhrase, warningTimeRemaining);
        }
    }

    if(timePassed++ >= warningMaxTime)
    {
        if(timer == g_tRetry)
        {
            g_bWaitingForVote = false;
            g_tRetry = INVALID_HANDLE;
        }
        else
        {
            g_tWarning = INVALID_HANDLE;
        }
    
        timePassed = 0;
        MapChange mapChange = view_as<MapChange>(ReadPackCell(data));
        Handle hndl = view_as<Handle>(ReadPackCell(data));
        
        InitiateVote(mapChange, hndl);
        
        return Plugin_Stop;
    }
    return Plugin_Continue;
}

public Action Command_Mapvote(int client, int args)
{
    PrintToChatAll("[\x04MCR\x01]  已启动地图投票");

    SetupWarningTimer(WarningType_Vote, MapChange_MapEnd, INVALID_HANDLE, true);

    return Plugin_Handled;    
}

void InitiateVote(MapChange when, Handle inputlist = INVALID_HANDLE)
{
    g_bWaitingForVote = true;
    g_bWarningInProgress = false;
 
    if(IsVoteInProgress())
    {
        PrintToChatAll("[\x04MCR\x01]  投票进行中,将在%d秒后重试.", FAILURE_TIMER_LENGTH);
        Handle data;
        g_tRetry = CreateDataTimer(1.0, Timer_StartMapVote, data, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);

        WritePackCell(data, FAILURE_TIMER_LENGTH);

        if(g_iRunoffCount > 0)
            WritePackString(data, "有几张地图比例类似,投票重启剩余时间: \x07%d秒");
        else
            WritePackString(data, "离下张地图投票将开始还有: \x07%d秒");

        WritePackCell(data, view_as<int>(when));
        WritePackCell(data, view_as<int>(inputlist));
        ResetPack(data);

        return;
    }
    
    if(g_bMapVoteCompleted && g_bChangeMapInProgress)
        return;


    g_eChangeTime = when;
    
    g_bWaitingForVote = false;

    g_bHasVoteStarted = true;


    Handle menuStyle = GetMenuStyleHandle(view_as<MenuStyle>(0));

    if(menuStyle != INVALID_HANDLE)
        g_hVoteMenu = CreateMenuEx(menuStyle, Handler_MapVoteMenu, MenuAction_End | MenuAction_Display | MenuAction_DisplayItem | MenuAction_VoteCancel);
    else
        g_hVoteMenu = CreateMenu(Handler_MapVoteMenu, MenuAction_End | MenuAction_Display | MenuAction_DisplayItem | MenuAction_VoteCancel);

    Handle radioStyle = GetMenuStyleHandle(MenuStyle_Radio);

    if(GetMenuStyle(g_hVoteMenu) == radioStyle)
    {
        g_bBlockedSlots = true;
        AddMenuItem(g_hVoteMenu, LINE_ONE, "Choose something...", ITEMDRAW_DISABLED);
        AddMenuItem(g_hVoteMenu, LINE_TWO, "...will ya?", ITEMDRAW_DISABLED);
    }
    else
        g_bBlockedSlots = false;
    
    SetMenuOptionFlags(g_hVoteMenu, MENUFLAG_BUTTON_NOVOTE);
    
    SetMenuTitle(g_hVoteMenu, "选择下一张地图\n ");
    SetVoteResultCallback(g_hVoteMenu, Handler_MapVoteFinished);

    char map[256];

    if(inputlist == INVALID_HANDLE)
    {
        int nominateCount = GetArraySize(g_aNominateList);
        int voteSize = 5;

        int nominationsToAdd = nominateCount >= voteSize ? voteSize : nominateCount;

        for(int i = 0; i < nominationsToAdd; i++)
        {
            GetArrayString(g_aNominateList, i, map, 256);

            AddMapItem(g_hVoteMenu, map, g_bZombieEscape);
            RemoveStringFromArray(g_aNextMapList, map);

            Call_StartForward(g_NominationsResetForward);
            Call_PushString(map);
            Call_PushCell(GetArrayCell(g_aNominateOwners, i));
            Call_Finish();
        }

        for(int i = nominationsToAdd; i < nominateCount; i++)
        {
            GetArrayString(g_aNominateList, i, map, 256);

            Call_StartForward(g_NominationsResetForward);
            Call_PushString(map);
            Call_PushCell(GetArrayCell(g_aNominateOwners, i));
            Call_Finish();
        }

        int i = nominationsToAdd;
        int count = 0;
        int availableMaps = GetArraySize(g_aNextMapList);
        
        if(i < voteSize && availableMaps == 0)
        {
            if(i == 0)
            {
                LogError("No maps available for vote.");
                return;
            }
            else
            {
                LogMessage("Not enough maps to fill map list.");
                voteSize = i;
            }
        }

        while(i < voteSize)
        {
            GetArrayString(g_aNextMapList, count, map, 256);        
            count++;

            AddMapItem(g_hVoteMenu, map, g_bZombieEscape);
            i++;

            if(count >= availableMaps)
                break;
        }
        
        g_iNominateCount = 0;
        ClearArray(g_aNominateOwners);
        ClearArray(g_aNominateList);
        
        AddExtendToMenu(g_hVoteMenu, when);
    }
    else
    {
        int size = GetArraySize(inputlist);
        
        for(int i=0; i<size; i++)
        {
            GetArrayString(inputlist, i, map, 256);
            
            if(IsMapValid(map))
                AddMapItem(g_hVoteMenu, map, g_bZombieEscape);
            else if(StrEqual(map, VOTE_DONTCHANGE))
                AddMenuItem(g_hVoteMenu, VOTE_DONTCHANGE, "Don't Change");
            else if(StrEqual(map, VOTE_EXTEND))
                AddMenuItem(g_hVoteMenu, VOTE_EXTEND, "Extend Map");
        }
        CloseHandle(inputlist);
    }

    if(5 <= GetMaxPageItems(GetMenuStyle(g_hVoteMenu)))
        SetMenuPagination(g_hVoteMenu, MENU_NO_PAGINATION);
    
    VoteMenuToAll(g_hVoteMenu, 15);

    Call_StartForward(g_MapVoteStartedForward);
    Call_Finish();

    LogAction(-1, -1, "Voting for next map has started.");
    PrintToChatAll("[\x04MCR\x01]  下幅地图投票已开始.");
}

public void Handler_VoteFinishedGeneric(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    char map[256];
    GetMapItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], map, 256);

    Call_StartForward(g_MapVoteEndForward);
    Call_PushString(map);
    Call_Finish();

    if(strcmp(map, VOTE_EXTEND, false)==0)
    {
        g_iExtends++;
        
        int timeLimit;
        if(GetMapTimeLimit(timeLimit))
            if(timeLimit > 0)
                ExtendMapTimeLimit(1200);                        

        PrintToChatAll("[\x04MCR\x01]  当前地图已被延长 (%d/%d 票)", item_info[0][VOTEINFO_ITEM_VOTES], num_votes);
        LogAction(-1, -1, "Voting for next map has finished. The current map has been extended.");

        g_bHasVoteStarted = false;
        CreateNextVote();
        SetupTimeleftTimer();
    }
    else if(strcmp(map, VOTE_DONTCHANGE, false)==0)
    {
        PrintToChatAll("[\x04MCR\x01]  当前地图暂不更换 (%d/%d 票)", item_info[0][VOTEINFO_ITEM_VOTES], num_votes);
        LogAction(-1, -1, "Voting for next map has finished. 'No Change' was the winner");
        
        g_bHasVoteStarted = false;
        CreateNextVote();
        SetupTimeleftTimer();
    }
    else
    {
        if(g_eChangeTime == MapChange_Instant)
        {
            g_bChangeMapInProgress = true;
            CreateTimer(10.0 , Timer_ChangeMaprtv);
        }
        else if(g_eChangeTime == MapChange_RoundEnd)
        {
            g_bChangeMapAtRoundEnd = true;
            SetConVarInt(FindConVar("mp_timelimit"), 1);
        }

        SetNextMap(map);
        SetConVarString(FindConVar("nextlevel"), map);

        g_bHasVoteStarted = false;
        g_bMapVoteCompleted = true;
        
        PrintToChatAll("[\x04MCR\x01]  地图投票已结束,下一幅地图将为 %s. (%d/%d 票)", map, item_info[0][VOTEINFO_ITEM_VOTES], num_votes);
        LogAction(-1, -1, "Voting for next map has finished. Nextmap: %s.", map);
    }    
}

public void CG_OnRoundEnd(int winner)
{
    Event_RoundEnd(INVALID_HANDLE, "round_end", false);
}

public void Event_RoundEnd(Handle event, const char[] name, bool dontBroadcast)
{
    if(!g_bChangeMapAtRoundEnd)
        return;

    SetConVarInt(FindConVar("mp_halftime"), 0);
    SetConVarInt(FindConVar("mp_timelimit"), 0);
    SetConVarInt(FindConVar("mp_maxrounds"), 0);
    SetConVarInt(FindConVar("mp_roundtime"), 1);

    CreateTimer(35.0, Timer_ChangeMap, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);

    g_bChangeMapInProgress = true;
    g_bChangeMapAtRoundEnd = false;
}

public Action Timer_ChangeMaprtv(Handle hTimer)
{
    SetConVarInt(FindConVar("mp_halftime"), 0);
    SetConVarInt(FindConVar("mp_timelimit"), 0);
    SetConVarInt(FindConVar("mp_maxrounds"), 0);
    SetConVarInt(FindConVar("mp_roundtime"), 1);

    CS_TerminateRound(12.0, CSRoundEnd_Draw, true);

    CreateTimer(35.0, Timer_ChangeMap, INVALID_HANDLE, TIMER_FLAG_NO_MAPCHANGE);

    return Plugin_Stop;
}

public void Handler_MapVoteFinished(Menu menu, int num_votes, int num_clients, const int[][] client_info, int num_items, const int[][] item_info)
{
    if(num_items > 1 && g_iRunoffCount < 1)
    {
        g_iRunoffCount++;
        int highest_votes = item_info[0][VOTEINFO_ITEM_VOTES];
        int required_percent = 50;
        int required_votes = RoundToCeil(float(num_votes) * float(required_percent) / 100);
        
        if(highest_votes == item_info[1][VOTEINFO_ITEM_VOTES])
        {
            g_bHasVoteStarted = false;
            
            int iArraySize = ByteCountToCells(256);
            Handle mapList = CreateArray(iArraySize);

            for(int i = 0; i < num_items; i++)
            {
                if(item_info[i][VOTEINFO_ITEM_VOTES] == highest_votes)
                {
                    char map[256];
                    GetMapItem(menu, item_info[i][VOTEINFO_ITEM_INDEX], map, 256);
                    PushArrayString(mapList, map);
                }
                else
                    break;
            }
            
            PrintToChatAll("[\x04MCR\x01]  有%d幅地图票数相等,投票即将重启.", GetArraySize(mapList));
            SetupWarningTimer(WarningType_Revote, view_as<MapChange>(g_eChangeTime), mapList);
            return;
        }
        else if(highest_votes < required_votes)
        {
            g_bHasVoteStarted = false;
            
            int iArraySize = ByteCountToCells(256);
            Handle mapList = CreateArray(iArraySize);

            char map1[256];
            GetMapItem(menu, item_info[0][VOTEINFO_ITEM_INDEX], map1, 256);

            PushArrayString(mapList, map1);

            for(int i = 1; i < num_items; i++)
            {
                if(GetArraySize(mapList) < 2 || item_info[i][VOTEINFO_ITEM_VOTES] == item_info[i - 1][VOTEINFO_ITEM_VOTES])
                {
                    char map[256];
                    GetMapItem(menu, item_info[i][VOTEINFO_ITEM_INDEX], map, 256);
                    PushArrayString(mapList, map);
                }
                else
                    break;
            }
            PrintToChatAll("[\x04MCR\x01]  没有地图比例过半(%d%%票). 即将开始第二轮投票!", required_percent);
            SetupWarningTimer(WarningType_Revote, view_as<MapChange>(g_eChangeTime), mapList);
            return;
        }
    }

    Handler_VoteFinishedGeneric(menu, num_votes, num_clients, client_info, num_items, item_info);
}

public int Handler_MapVoteMenu(Handle menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_End:
        {
            g_hVoteMenu = INVALID_HANDLE;
            CloseHandle(menu);
        }
        case MenuAction_Display:
        {
            SetPanelTitle(view_as<Handle>(param2), "投票选择下幅地图 \n ");
        }
        case MenuAction_DisplayItem:
        {
            char map[256];
            char buffer[256];
            
            GetMenuItem(menu, param2, map, 256);
            
            if(StrEqual(map, VOTE_EXTEND, false))
                strcopy(buffer, 256, "延长当前地图");
            else if(StrEqual(map, VOTE_DONTCHANGE, false))
                strcopy(buffer, 256, "不要更换地图");
            else if(StrEqual(map, LINE_ONE, false))
                strcopy(buffer, 256, "选择你想玩的地铁图...");
            else if(StrEqual(map, LINE_TWO, false))
                strcopy(buffer, 256, "如果你选错可以输入 !revote 重新投票 ;-)");
            
            if(buffer[0] != '\0')
                return RedrawMenuItem(buffer);
        }
        case MenuAction_VoteCancel:
        {
            if(param1 == VoteCancel_NoVotes)
            {
                int count = GetMenuItemCount(menu);
                
                int item;
                char map[256];
                
                do
                {
                    int startInt = 0;
                    if(g_bBlockedSlots)
                        startInt = 2;
                    item = UTIL_GetRandomInt(startInt, count - 1);
                    GetMenuItem(menu, item, map, 256);
                }
                while(strcmp(map, VOTE_EXTEND, false)==0);
                
                SetNextMap(map);
                g_bMapVoteCompleted = true;
            }
            g_bHasVoteStarted = false;
        }
    }

    return 0;
}

public Action Timer_ChangeMap(Handle hTimer, Handle dp)
{
    g_bChangeMapInProgress = false;

    char map[256];
    
    if(dp == INVALID_HANDLE)
    {
        if(!GetNextMap(map, 256))
        {
            LogError("Timer_ChangeMap -> !GetNextMap");
            return Plugin_Stop;    
        }
    }
    else
    {
        ResetPack(dp);
        ReadPackString(dp, map, 256);
    }

    ForceChangeLevel(map, "Map Vote");
    
    return Plugin_Stop;
}

bool RemoveStringFromArray(Handle array, char[] str)
{
    int index = FindStringInArray(array, str);
    if(index != -1)
    {
        RemoveFromArray(array, index);
        return true;
    }

    return false;
}

void CreateNextVote()
{
    assert(g_aNextMapList)
    ClearArray(g_aNextMapList);
    
    bool neednicemap = false;
    /*if(FindPluginByFile("zombiereloaded.smx"))
    {
        char time[32];
        FormatTime(time, 64, "%H:%M:%S", GetTime());
        if(StrContains(time, "19:") == 0 || StrContains(time, "20:") == 0 || StrContains(time, "21:") == 0 || StrContains(time, "22:") == 0)
        {
            neednicemap = true;
            LogMessage("[%s] neednicemap = true", time);
        }
    }
*/
    Handle tempMaps = CloneArray(g_aMapList);
    
    char map[256];
    GetCurrentMap(map, 256);
    RemoveStringFromArray(tempMaps, map);
    
    int maxOld = 15;
    if(g_bZombieEscape) maxOld = 60;
    
    if(GetArraySize(tempMaps) > maxOld)
    {
        int asize = GetArraySize(g_aOldMapList);
        for(int i = 0; i < asize; i++)
        {
            GetArrayString(g_aOldMapList, i, map, 256);
            RemoveStringFromArray(tempMaps, map);
        }
    }
    else LogError("no enough to create NextVote Maplist");

    if(neednicemap)
    {
        for(int x = 0; x < GetArraySize(tempMaps); ++x)
        {
            GetArrayString(tempMaps, x, map, 256);
            if(!IsNiceMap(map))
            {
                RemoveStringFromArray(tempMaps, map);
                if(x > 0) x--;
            }
        }
    }
    else
    {
        for(int x = 0; x < GetArraySize(tempMaps); ++x)
        {
            GetArrayString(tempMaps, x, map, 256);
            // we remove big maps( >150 will broken fastdl .bz2), nice map, and only nominations
            if(IsNiceMap(map) || IsBigMap(map) || IsOnlyNomination(map) || IsOnlyAdmin(map) || IsOnlyVIP(map))
            {
                RemoveStringFromArray(tempMaps, map);
                if(x > 0) x--;
            }
        }
    }

    int players = GetClientCount(true); // no any ze server run with bot.
    for(int x = 0; x < GetArraySize(tempMaps); ++x)
    {
        GetArrayString(tempMaps, x, map, 256);
        // we remove map if player amount not match with configs
        int max = GetMaxPlayers(map);
        int min = GetMinPlayers(map);
        if((min != 0 && players < min) || (max != 0 && players > max))
        {
            RemoveStringFromArray(tempMaps, map);
            if(x > 0) x--;
        }
    }

    int limit = (5 < GetArraySize(tempMaps) ? 5 : GetArraySize(tempMaps));

    for(int i = 0; i < limit; i++)
    {
        int b = UTIL_GetRandomInt(0, GetArraySize(tempMaps) - 1);
        GetArrayString(tempMaps, b, map, 256);
        PushArrayString(g_aNextMapList, map);
        RemoveFromArray(tempMaps, b);
    }

    CloseHandle(tempMaps);
}

bool CanVoteStart()
{
    if(g_bWaitingForVote || g_bHasVoteStarted)
        return false;

    return true;
}

NominateResult InternalNominateMap(char[] map, bool force, int owner)
{
    if(!IsMapValid(map))
        return NominateResult_InvalidMap;

    if(FindStringInArray(g_aNominateList, map) != -1)
        return NominateResult_AlreadyInVote;
    
    if(IsOnlyVIP(map) && !IsClientVIP(owner))
        return NominateResult_OnlyVIP;
    
    if(IsOnlyAdmin(map) && !CheckCommandAccess(owner, "sm_map", ADMFLAG_CHANGEMAP, false))
        return NominateResult_OnlyAdmin;

    int index;

    if(owner && ((index = FindValueInArray(g_aNominateOwners, owner)) != -1))
    {
        char oldmap[256];
        GetArrayString(g_aNominateList, index, oldmap, 256);
        InternalRemoveNominationByOwner(owner);

        if(Store_GetClientCredits(owner) < GetMapPrice(map))
            return NominateResult_NoCredits;

        PushArrayString(g_aNominateList, map);
        PushArrayCell(g_aNominateOwners, owner);

        return NominateResult_Replaced;
    }

    if(g_iNominateCount >= 5 && !force)
        return NominateResult_VoteFull;

    if(Store_GetClientCredits(owner) < GetMapPrice(map))
        return NominateResult_NoCredits;
    
    int max = GetMaxPlayers(map);
    if(max != 0 && GetClientCount(true) > max)
        return NominateResult_MaxPlayers;
    
    int min = GetMinPlayers(map);
    if(min != 0 && GetClientCount(true) < min)
        return NominateResult_MinPlayers;

    PushArrayString(g_aNominateList, map);
    PushArrayCell(g_aNominateOwners, owner);
    g_iNominateCount++;

    while(GetArraySize(g_aNominateList) > 5)
    {
        char oldmap[256];
        GetArrayString(g_aNominateList, 0, oldmap, 256);
        Call_StartForward(g_NominationsResetForward);
        Call_PushString(oldmap);
        Call_PushCell(GetArrayCell(g_aNominateOwners, 0));
        Call_Finish();
        
        RemoveFromArray(g_aNominateList, 0);
        RemoveFromArray(g_aNominateOwners, 0);
    }

    return NominateResult_Added;
}

public int Native_NominateMap(Handle plugin, int numParams)
{
    int len;
    GetNativeStringLength(1, len);
    
    if(len <= 0)
      return false;
    
    char[] map = new char[len+1];
    GetNativeString(1, map, len+1);
    
    return view_as<int>(InternalNominateMap(map, GetNativeCell(2), GetNativeCell(3)));
}

bool InternalRemoveNominationByMap(char[] map)
{    
    for(int i = 0; i < GetArraySize(g_aNominateList); i++)
    {
        char oldmap[256];
        GetArrayString(g_aNominateList, i, oldmap, 256);

        if(strcmp(map, oldmap, false) == 0)
        {
            Call_StartForward(g_NominationsResetForward);
            Call_PushString(oldmap);
            Call_PushCell(GetArrayCell(g_aNominateOwners, i));
            Call_Finish();

            RemoveFromArray(g_aNominateList, i);
            RemoveFromArray(g_aNominateOwners, i);
            g_iNominateCount--;

            return true;
        }
    }
    
    return false;
}

public int Native_RemoveNominationByMap(Handle plugin, int numParams)
{
    int len;
    GetNativeStringLength(1, len);

    if(len <= 0)
      return false;
    
    char[] map = new char[len+1];
    GetNativeString(1, map, len+1);
    
    return InternalRemoveNominationByMap(map);
}

bool InternalRemoveNominationByOwner(int owner)
{    
    int index;

    if(owner && ((index = FindValueInArray(g_aNominateOwners, owner)) != -1))
    {
        char oldmap[256];
        GetArrayString(g_aNominateList, index, oldmap, 256);

        Call_StartForward(g_NominationsResetForward);
        Call_PushString(oldmap);
        Call_PushCell(owner);
        Call_Finish();

        RemoveFromArray(g_aNominateList, index);
        RemoveFromArray(g_aNominateOwners, index);
        g_iNominateCount--;
        
        int credits = GetMapPrice(oldmap);
        Store_SetClientCredits(owner, Store_GetClientCredits(owner)+credits, "nomination-退还");
        PrintToChat(owner, "[\x04MCR\x01]  \x04你预定的[\x0C%s\x04]已被取消,已退还%d信用点", oldmap, credits);

        return true;
    }
    
    return false;
}

public int Native_RemoveNominationByOwner(Handle plugin, int numParams)
{    
    return InternalRemoveNominationByOwner(GetNativeCell(1));
}

public int Native_InitiateVote(Handle plugin, int numParams)
{
    MapChange when = view_as<MapChange>(GetNativeCell(1));
    Handle inputarray = view_as<Handle>(GetNativeCell(2));
    
    LogAction(-1, -1, "Starting map vote because outside request");

    SetupWarningTimer(WarningType_Vote, when, inputarray);
}

public int Native_CanVoteStart(Handle plugin, int numParams)
{
    return CanVoteStart();    
}

public int Native_CheckVoteDone(Handle plugin, int numParams)
{
    return g_bMapVoteCompleted;
}

public int Native_GetExcludeMapList(Handle plugin, int numParams)
{
    Handle array = view_as<Handle>(GetNativeCell(1));
    
    if(array == INVALID_HANDLE)
        return;
    
    int size = GetArraySize(g_aOldMapList);
    char map[256];
    
    for(int i=0; i<size; i++)
    {
        GetArrayString(g_aOldMapList, i, map, 256);
        PushArrayString(array, map);    
    }
}

public int Native_GetNominatedMapList(Handle plugin, int numParams)
{
    Handle maparray = view_as<Handle>(GetNativeCell(1));
    Handle ownerarray = view_as<Handle>(GetNativeCell(2));
    
    if(maparray == INVALID_HANDLE)
        return;

    char map[256];

    for(int i = 0; i < GetArraySize(g_aNominateList); i++)
    {
        GetArrayString(g_aNominateList, i, map, 256);
        PushArrayString(maparray, map);

        if(ownerarray != INVALID_HANDLE)
        {
            int index = GetArrayCell(g_aNominateOwners, i);
            PushArrayCell(ownerarray, index);
        }
    }
}

public int Native_EndOfMapVoteEnabled(Handle plugin, int numParams)
{
    return true;
}

stock int SetupWarningTimer(WarningType type, MapChange when = MapChange_MapEnd, Handle mapList = INVALID_HANDLE, bool force = false)
{
    if(!GetArraySize(g_aMapList) || g_bChangeMapInProgress || g_bHasVoteStarted || (!force && g_bMapVoteCompleted))
        return;
    
    if(g_bWarningInProgress && g_tWarning != INVALID_HANDLE)
        KillTimer(g_tWarning);
    
    g_bWarningInProgress = true;
    
    int cvarTime;
    char translationKey[64];
    
    switch (type)
    {
        case WarningType_Vote:
        {
            cvarTime = 15;
            strcopy(translationKey, 64, "离下张地图投票将开始还有: \x07%d秒");
        }
        
        case WarningType_Revote:
        {
            cvarTime = 5;
            strcopy(translationKey, 64, "有几张地图比例类似,投票重启剩余时间: \x07%d秒");
        }
    }

    Handle data;
    g_tWarning = CreateDataTimer(1.0, Timer_StartMapVote, data, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
    WritePackCell(data, cvarTime);
    WritePackString(data, translationKey);
    WritePackCell(data, view_as<int>(when));
    WritePackCell(data, view_as<int>(mapList));
    ResetPack(data);
}

stock bool IsMapEndVoteAllowed()
{
    if(g_bMapVoteCompleted || g_bHasVoteStarted)
        return false;
    else
        return true;
}

public int Native_IsWarningTimer(Handle plugin, int numParams)
{
    return g_bWarningInProgress;
}

public int Native_CanNominate(Handle plugin, int numParams)
{
    if(g_bHasVoteStarted)
        return view_as<int>(CanNominate_No_VoteInProgress);
    
    if(g_bMapVoteCompleted)
        return view_as<int>(CanNominate_No_VoteComplete);
    
    if(g_iNominateCount >= 5)
        return view_as<int>(CanNominate_No_VoteFull);
    
    return view_as<int>(CanNominate_Yes);
}

void BuildKvMapData()
{
    if(g_hKvMapData != null)
        CloseHandle(g_hKvMapData);
    
    g_hKvMapData = CreateKeyValues("MapData", "", "");
    
    if(!FileExists("addons/sourcemod/configs/mapdata.txt"))
        KeyValuesToFile(g_hKvMapData, "addons/sourcemod/configs/mapdata.txt");
    else
        FileToKeyValues(g_hKvMapData, "addons/sourcemod/configs/mapdata.txt");

    KvRewind(g_hKvMapData);

    char map[128];
    GetCurrentMap(map, 128);
    AddMapData(map);
}

void AddMapData(char[] map)
{
    if(g_hKvMapData == null)
        return;

    if(!KvJumpToKey(g_hKvMapData, map))
    {
        KvJumpToKey(g_hKvMapData, map, true);
        KvSetString(g_hKvMapData, "Desc", "不详: 尚未明朗");
        KvSetNum(g_hKvMapData, "Price", 100);
        Format(map, 128, "maps/%s.bsp", map);
        KvSetNum(g_hKvMapData, "Size", FileSize(map)/1048576+1);
        KvSetNum(g_hKvMapData, "Nice", 0);
        KvSetNum(g_hKvMapData, "MinPlayers", 0);
        KvSetNum(g_hKvMapData, "MaxPlayers", 0);
        KvSetNum(g_hKvMapData, "OnlyNomination", 0);
        KvSetNum(g_hKvMapData, "OnlyAdmin", 0);
        KvSetNum(g_hKvMapData, "OnlyVIP", 0);
        KvRewind(g_hKvMapData);
        KeyValuesToFile(g_hKvMapData, "addons/sourcemod/configs/mapdata.txt");
    }

    KvRewind(g_hKvMapData);
}

void CheckMapData()
{
    if(g_hKvMapData == null)
        return;

    if(!KvGotoFirstSubKey(g_hKvMapData, true))
        return;

    char map[128], path[128];
    do
    {
        KvGetSectionName(g_hKvMapData, map, 128);
        Format(path, 128, "maps/%s.bsp", map);
        if(!FileExists(path))
        {
            LogMessage("Delete %s from mapdata", map);
            KvDeleteThis(g_hKvMapData);
            KvRewind(g_hKvMapData);
            KeyValuesToFile(g_hKvMapData, "addons/sourcemod/configs/mapdata.txt");
            if(!KvGotoFirstSubKey(g_hKvMapData, true))
                continue;
        }

        if(KvGetNum(g_hKvMapData, "MinPlayers", -1) == -1)
            KvSetNum(g_hKvMapData, "MinPlayers", 0);
        
        if(KvGetNum(g_hKvMapData, "MaxPlayers", -1) == -1)
            KvSetNum(g_hKvMapData, "MaxPlayers", 0);
        
        if(KvGetNum(g_hKvMapData, "OnlyNomination", -1) == -1)
            KvSetNum(g_hKvMapData, "OnlyNomination", 0);
        
        if(KvGetNum(g_hKvMapData, "OnlyAdmin", -1) == -1)
            KvSetNum(g_hKvMapData, "OnlyAdmin", 0);
        
        if(KvGetNum(g_hKvMapData, "OnlyVIP", -1) == -1)
            KvSetNum(g_hKvMapData, "OnlyVIP", 0);
    }
    while(KvGotoNextKey(g_hKvMapData, true))

    KvRewind(g_hKvMapData);

    Call_StartForward(g_MapDataLoadedForward);
    Call_Finish();
}

void CheckMapCycle()
{
    char path[128];
    Format(path, 128, "mapcycle.txt");

    int counts, number;

    Handle hFile;
    if((hFile = OpenFile(path, "r")) != INVALID_HANDLE)
    {
        char fileline[128];
        while(ReadFileLine(hFile, fileline, 128))
        {
            if(fileline[0] == '\0')
                continue;

            counts++;
        }
        CloseHandle(hFile);
    }
    
    Handle hDirectory;
    if((hDirectory = OpenDirectory("maps")) != INVALID_HANDLE)
    {
        FileType type = FileType_Unknown;
        char filename[128];
        while(ReadDirEntry(hDirectory, filename, 128, type))
        {
            if(type != FileType_File)
                continue;
            
            TrimString(filename);

            if(StrContains(filename, ".bsp", false) == -1)
                continue;
            
            if(!StrContains(filename, "de_", false) || !StrContains(filename, "cs_", false) || !StrContains(filename, "gd_", false) || !StrContains(filename, "train", false) || !StrContains(filename, "ar_", false))
            {
                char path2[128];
                Format(path2, 128, "maps/%s", filename);
                if(DeleteFile(path2))
                    LogMessage("Delete Offical map: %s", path2);
                
                continue;
            }

            number++;
        }
        CloseHandle(hDirectory);
    }
    
    if(counts == number)
        return;
    
    LogMessage("Build New MapCycle[old: %d current: %d]", counts, number);
    
    DeleteFile("gamemodes_server.txt");
    
    char mgname[32];

    if(FindPluginByFile("ct.smx"))                        //TTT
        strcopy(mgname, 32, "\"cg_ttt_maps\"");
    else if(FindPluginByFile("zombiereloaded.smx"))        // ZE
        strcopy(mgname, 32, "\"cg_ze_maps\"");
    else if(FindPluginByFile("KZTimerGlobal.smx"))        // KZ
        strcopy(mgname, 32, "\"cg_kz_maps\"");
    else if(FindPluginByFile("mg_stats.smx"))            // MG
        strcopy(mgname, 32, "\"cg_mg_maps\"");
    else if(FindPluginByFile("sm_hosties.smx"))            // JB
        strcopy(mgname, 32, "\"cg_jb_maps\"");

    Handle gamemode = OpenFile("gamemodes_server.txt", "w+");
    WriteFileLine(gamemode, "\"GameModes_Server.txt\"");
    WriteFileLine(gamemode, "{");
    WriteFileLine(gamemode, "\"gameTypes\"");
    WriteFileLine(gamemode, "{");
    WriteFileLine(gamemode, "\"classic\"");
    WriteFileLine(gamemode, "{");
    WriteFileLine(gamemode, "\"gameModes\"");
    WriteFileLine(gamemode, "{");
    WriteFileLine(gamemode, "\"casual\"");
    WriteFileLine(gamemode, "{");
    WriteFileLine(gamemode, "\"maxplayers\" \"64\"");
    WriteFileLine(gamemode, "\"exec\"");
    WriteFileLine(gamemode, "{");
    WriteFileLine(gamemode, "\"exec\" \"gamemode_casual.cfg\"");
    WriteFileLine(gamemode, "\"exec\" \"gamemode_casual_server.cfg\"");
    WriteFileLine(gamemode, "}");
    WriteFileLine(gamemode, "\"mapgroupsMP\"");
    WriteFileLine(gamemode, "{");
    
    char fixs_1[32];
    Format(fixs_1, 32, "%s \"0\"", mgname);
    WriteFileLine(gamemode, fixs_1);

    WriteFileLine(gamemode, "}");
    WriteFileLine(gamemode, "}");
    WriteFileLine(gamemode, "}");
    WriteFileLine(gamemode, "}");
    WriteFileLine(gamemode, "}");
    WriteFileLine(gamemode, "\"mapgroups\"");
    WriteFileLine(gamemode, "{");
    WriteFileLine(gamemode, mgname);
    WriteFileLine(gamemode, "{");

    char fixs_2[32];
    Format(fixs_2, 32, "\"name\" %s", mgname)
    WriteFileLine(gamemode, fixs_2);

    WriteFileLine(gamemode, "\"maps\"");
    WriteFileLine(gamemode, "{");

    if((hFile = OpenFile(path, "w+")) != INVALID_HANDLE)
    {
        if((hDirectory = OpenDirectory("maps")) != INVALID_HANDLE)
        {
            FileType type = FileType_Unknown;
            char filename[128], mapbuffer[128];
            while(ReadDirEntry(hDirectory, filename, 128, type))
            {
                if(type == FileType_File)
                {
                    if(StrContains(filename, ".bsp", false) != -1)
                    {
                        ReplaceString(filename, 128, ".bsp", "", false);
                        WriteFileLine(hFile, filename);
                        Format(mapbuffer, 128, "\"%s\" \"\"", filename);
                        WriteFileLine(gamemode, mapbuffer);
                        AddMapData(filename);
                    }
                }
            }
            CloseHandle(hDirectory);
        }
        CloseHandle(hFile);
    }

    WriteFileLine(gamemode, "}");
    WriteFileLine(gamemode, "}");
    WriteFileLine(gamemode, "}");
    WriteFileLine(gamemode, "}");
    
    CloseHandle(gamemode);
}

public void Event_WinPanel(Handle event, const char[] name, bool dontBroadcast)
{
    char cmap[128], nmap[128];
    GetCurrentMap(cmap, 128);
    GetNextMap(nmap, 128);
    if(!IsMapValid(nmap))
        GetArrayString(g_aMapList, UTIL_GetRandomInt(0, GetArraySize(g_aMapList)-1), nmap, 128);
    
    if(StrEqual(nmap, cmap))
        GetArrayString(g_aMapList, UTIL_GetRandomInt(0, GetArraySize(g_aMapList)-1), nmap, 128);
    
    Handle pack;
    CreateDataTimer(35.0, Timer_Monitor, pack, TIMER_FLAG_NO_MAPCHANGE);
    WritePackString(pack, nmap);
    ResetPack(pack);
}

public Action Timer_Monitor(Handle timer, Handle pack)
{
    char cmap[128], nmap[128];
    GetCurrentMap(cmap, 128);
    ReadPackString(pack, nmap, 128);

    if(StrEqual(nmap, cmap))
        return Plugin_Stop;

    LogError("Map has not been changed ? %s -> %s", cmap, nmap);
    //ForceChangeLevel(nmap, "BUG: Map not change");
    ServerCommand("map %s", nmap);

    return Plugin_Stop;
}

stock void GetMapItem(Handle menu, int position, char[] map, int mapLen)
{
    GetMenuItem(menu, position, map, mapLen);
}

stock void AddExtendToMenu(Handle menu, MapChange when)
{
    if((when == MapChange_Instant || when == MapChange_RoundEnd))
        AddMenuItem(menu, VOTE_DONTCHANGE, "Don't Change");
    else if(g_iExtends < 3)
        AddMenuItem(menu, VOTE_EXTEND, "Extend Map");
}

stock bool IsClientVIP(int client)
{
    return g_srvCSGOGAMERS ? CG_ClientIsVIP(client) : CheckCommandAccess(client, "check_isclientvip", ADMFLAG_RESERVATION, false);
}

stock void DisplayHUDToAll(const char[] warningPhrase, int time)
{
    char fmt[256];
    if(g_srvCSGOGAMERS)
    {
        FormatEx(fmt, 256, warningPhrase, time);
        CG_ShowGameTextAll(fmt, "1.2", "233 0 0", "-1.0", "0.32");
    }
    else
    {
        SetHudTextParams(-1.0, 0.32, 1.2, 233, 0, 0, 255, 0, 30.0, 0.0, 0.0); // Doc -> https://sm.alliedmods.net/new-api/halflife/SetHudTextParams
        for(int client = 1; client <= MaxClients; ++client)
            if(IsClientInGame(client) && !IsFakeClient(client))
            {
                FormatEx(fmt, 256, warningPhrase, time);
                ShowHudText(client, 20, fmt); // SaSuSi`s birthday is Apr 20, so i use channel 20, u can edit this.
            }
    }
}

stock bool CleanPlugin()
{
    // delete mapchooser
    if(FileExists("addons/sourcemod/plugins/mapchooser.smx"))
        if(!DeleteFile("addons/sourcemod/plugins/mapchooser.smx"))
            return false;
    
    // delete rockthevote
    if(FileExists("addons/sourcemod/plugins/rockthevote.smx"))
        if(!DeleteFile("addons/sourcemod/plugins/rockthevote.smx"))
            return false;
        
    // delete nominations
    if(FileExists("addons/sourcemod/plugins/nominations.smx"))
        if(!DeleteFile("addons/sourcemod/plugins/nominations.smx"))
            return false;
        
    // delete mapchooser_extended
    if(FileExists("addons/sourcemod/plugins/mapchooser_extended.smx"))
        if(!DeleteFile("addons/sourcemod/plugins/mapchooser_extended.smx"))
            return false;
    
    // delete rockthevote_extended
    if(FileExists("addons/sourcemod/plugins/rockthevote_extended.smx"))
        if(!DeleteFile("addons/sourcemod/plugins/rockthevote_extended.smx"))
            return false;
        
    // delete nominations_extended
    if(FileExists("addons/sourcemod/plugins/nominations_extended.smx"))
        if(!DeleteFile("addons/sourcemod/plugins/nominations_extended.smx"))
            return false;
    
    return true;
}