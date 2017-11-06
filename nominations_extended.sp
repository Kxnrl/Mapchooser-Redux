#include <mapchooser_extended>
#include <store>

#pragma newdecls required

ArrayList g_aMapList;
Handle g_hMapMenu;
int g_iMapFileSerial = -1;
bool g_bIncludeName = false;

#define MAPSTATUS_ENABLED (1<<0)
#define MAPSTATUS_DISABLED (1<<1)
#define MAPSTATUS_EXCLUDE_CURRENT (1<<2)
#define MAPSTATUS_EXCLUDE_PREVIOUS (1<<3)
#define MAPSTATUS_EXCLUDE_NOMINATED (1<<4)

Handle g_aMapTrie;
Handle g_aNominated_Auth;
Handle g_aNominated_Name;

public Plugin myinfo =
{
    name        = "Nominations Redux",
    author      = "Kyle",
    description = "Provides Map Nominations",
    version     = MCE_VERSION,
    url         = "http://steamcommunity.com/id/_xQy_/"
};

public void OnPluginStart()
{
    LoadTranslations("common.phrases");
    LoadTranslations("nominations.phrases");
    LoadTranslations("basetriggers.phrases"); // for Next Map phrase
    LoadTranslations("mapchooser_extended.phrases");

    int arraySize = ByteCountToCells(256);    
    g_aMapList = CreateArray(arraySize);

    g_aMapTrie = CreateTrie();
    g_aNominated_Auth = CreateTrie();
    g_aNominated_Name = CreateTrie();
}

public void OnConfigsExecuted()
{
    if(ReadMapList(g_aMapList, g_iMapFileSerial, "nominations", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER) == INVALID_HANDLE)
        if(g_iMapFileSerial == -1)
            SetFailState("Unable to create a valid map list.");

    CreateTimer(90.0, Timer_Broadcast, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
    
    g_bIncludeName = (FindPluginByFile("zombiereloaded.smx") != INVALID_HANDLE);
}

public void OnMapEnd()
{
    char map[128];
    GetCurrentMap(map, 128);
    RemoveFromTrie(g_aNominated_Auth, map);
    RemoveFromTrie(g_aNominated_Name, map);
    
    if(g_hKvMapData != INVALID_HANDLE)
        CloseHandle(g_hKvMapData);
    g_hKvMapData = INVALID_HANDLE;
}

public void OnNominationRemoved(const char[] map, int owner)
{
    int status;

    if(!GetTrieValue(g_aMapTrie, map, status))
        return;    

    if((status & MAPSTATUS_EXCLUDE_NOMINATED) != MAPSTATUS_EXCLUDE_NOMINATED)
        return;

    SetTrieValue(g_aMapTrie, map, MAPSTATUS_ENABLED);    
}

public void OnClientSayCommand_Post(int client, const char[] command, const char[] sArgs)
{
    if(!client)
        return;

    if(StrContains(sArgs, "nominat", false) == -1)
        return;

    if(!IsNominateAllowed(client))
        return;

    AttemptNominate(client);
}

void AttemptNominate(int client)
{
    SetMenuTitle(g_hMapMenu, "%T\n ", "Nominate Title", client);
    DisplayMenu(g_hMapMenu, client, MENU_TIME_FOREVER);

    return;
}

void BuildMapMenu()
{
    if(g_hMapMenu != INVALID_HANDLE)
    {
        CloseHandle(g_hMapMenu);
        g_hMapMenu = INVALID_HANDLE;
    }

    ClearTrie(g_aMapTrie);

    g_hMapMenu = CreateMenu(Handler_MapSelectMenu, MENU_ACTIONS_DEFAULT|MenuAction_DrawItem|MenuAction_DisplayItem);

    char map[128];
    
    ArrayList excludeMaps = CreateArray(ByteCountToCells(128));
    GetExcludeMapList(excludeMaps);

    char currentMap[32];
    GetCurrentMap(currentMap, 32);
    
    for(int i = 0; i < GetArraySize(g_aMapList); i++)
    {
        int status = MAPSTATUS_ENABLED;

        GetArrayString(g_aMapList, i, map, 128);

        if(StrEqual(map, currentMap))
            status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_CURRENT;

        if(status == MAPSTATUS_ENABLED)
            if(FindStringInArray(excludeMaps, map) != -1)
            status = MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_PREVIOUS;

        char szTrans[256];
        if(GetMapDesc(map, szTrans, 256, true, g_bIncludeName))
            AddMenuItem(g_hMapMenu, map, szTrans);
        else
            AddMenuItem(g_hMapMenu, map, map);

        SetTrieValue(g_aMapTrie, map, status);
    }

    SetMenuExitButton(g_hMapMenu, true);

    if(excludeMaps != INVALID_HANDLE)
        CloseHandle(excludeMaps);
}

public int Handler_MapSelectMenu(Handle menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char map[128], name[64];
            GetMenuItem(menu, param2, map, 128);        

            GetClientName(param1, name, 64);

            NominateResult2 result = NominateMap2(map, false, param1);

            if(result == NominateResult_NoCredits)
            {
                PrintToChat(param1, "[\x04MCE\x01]  \x04你的信用点余额不足,预定[\x0C%s\x04]失败", map);
                return 0;
            }

            if(result == NominateResult_InvalidMap)
            {
                PrintToChat(param1, "[\x04MCE\x01]  预定[\x04%s\x01]失败", map);
                return 0;
            }

            if(result == NominateResult_AlreadyInVote)
            {
                PrintToChat(param1, "[\x04MCE\x01]  %t", "Map Already Nominated");
                return 0;
            }
            
            if(result == NominateResult_VoteFull)
            {
                PrintToChat(param1, "[\x04MCE\x01]  %t", "Max Nominations");
                return 0;
            }
            
            if(result == NominateResult_OnlyAdmin)
            {
                PrintToChat(param1, "[\x04MCE\x01]  \x07该地图只有管理员才能直接更换");
                return 0;
            }
            
            if(result == NominateResult_OnlyVIP)
            {
                PrintToChat(param1, "[\x04MCE\x01]  \x07该地图只有VIP才能预定");
                return 0;
            }

            if(result == NominateResult_MinPlayers)
            {
                PrintToChat(param1, "[\x04MCE\x01]  \x07该地图需要当前服务器人数大于\x04%d人\x07才能预定", GetMinPlayers(map));
                return 0;
            }
            
            if(result == NominateResult_MaxPlayers)
            {
                PrintToChat(param1, "[\x04MCE\x01]  \x07该地图需要当前服务器人数小于\x04%d人\x07才能预定", GetMaxPlayers(map));
                return 0;
            }

            SetTrieValue(g_aMapTrie, map, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED);
            
            int credits = GetMapPrice(map);
            Store_SetClientCredits(param1, Store_GetClientCredits(param1)-credits, "nomination-预定");
            PrintToChat(param1, "[\x04MCE\x01]  \x04你预定[\x0C%s\x04]花费了%d信用点", map, credits);

            char m_szAuth[32], m_szName[32];
            GetClientAuthId(param1, AuthId_Steam2, m_szAuth, 32, true);
            GetClientName(param1, m_szName, 32)
            SetTrieString(g_aNominated_Auth, map, m_szAuth, true);
            SetTrieString(g_aNominated_Name, map, m_szName, true);

            LogMessage("%s nominated %s", name, map);

            if(result == NominateResult_Replaced)
                PrintToChatAll("[\x04MCE\x01]  %t", "Map Nomination Changed", name, map);
            else
                PrintToChatAll("[\x04MCE\x01]  %t", "Map Nominated", name, map);
        }

        case MenuAction_DrawItem:
        {
            char map[128];
            GetMenuItem(menu, param2, map, 128);

            int status;

            if(!GetTrieValue(g_aMapTrie, map, status))
            {
                LogError("case MenuAction_DrawItem: Menu selection of item not in trie. Major logic problem somewhere.");
                return ITEMDRAW_DEFAULT;
            }

            if((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
                return ITEMDRAW_DISABLED;    
    
            return ITEMDRAW_DEFAULT;
        }
        
        case MenuAction_DisplayItem:
        {
            char map[128];
            GetMenuItem(menu, param2, map, 128);

            int status;
            
            if(!GetTrieValue(g_aMapTrie, map, status))
            {
                LogError("case MenuAction_DisplayItem: Menu selection of item not in trie. Major logic problem somewhere.");
                return 0;
            }
            
            char buffer[100];
            char display[150];
            char trans[128];
            strcopy(buffer, 100, map);
            GetMapDesc(map, trans, 128, false, false);

            if((status & MAPSTATUS_DISABLED) == MAPSTATUS_DISABLED)
            {
                if((status & MAPSTATUS_EXCLUDE_CURRENT) == MAPSTATUS_EXCLUDE_CURRENT)
                {
                    Format(display, sizeof(display), "%s (%T)\n%s", buffer, "Current Map", param1, trans);
                    return RedrawMenuItem(display);
                }
                
                if((status & MAPSTATUS_EXCLUDE_PREVIOUS) == MAPSTATUS_EXCLUDE_PREVIOUS)
                {
                    Format(display, sizeof(display), "%s (%T)\n%s", buffer, "Recently Played", param1, trans);
                    return RedrawMenuItem(display);
                }
                
                if((status & MAPSTATUS_EXCLUDE_NOMINATED) == MAPSTATUS_EXCLUDE_NOMINATED)
                {
                    Format(display, sizeof(display), "%s (%T)\n%s", buffer, "Nominated", param1, trans);
                    return RedrawMenuItem(display);
                }
            }
            
            return 0;
        }
    }

    return 0;
}

stock bool IsNominateAllowed(int client)
{
    CanNominateResult result = CanNominate();
    
    switch(result)
    {
        case CanNominate_No_VoteInProgress:
        {
            PrintToChat(client, "[\x04MCE\x01]  %t", "Nextmap Voting Started");
            return false;
        }
        
        case CanNominate_No_VoteComplete:
        {
            char map[128];
            GetNextMap(map, 128);
            PrintToChat(client, "[\x04MCE\x01]  %t", "Next Map", map);
            return false;
        }
        
        case CanNominate_No_VoteFull:
        {
            PrintToChat(client, "[\x04MCE\x01]  %t", "Max Nominations");
            return false;
        }
    }
    
    return true;
}

public void OnMapDataLoaded()
{
    if(g_hKvMapData != INVALID_HANDLE)
        CloseHandle(g_hKvMapData);

    g_hKvMapData = CreateKeyValues("MapData", "", "");
    FileToKeyValues(g_hKvMapData, "addons/sourcemod/configs/mapdata.txt");
    KvRewind(g_hKvMapData);

    BuildMapMenu();
}

public Action Timer_Broadcast(Handle timer)
{
    char map[128];
    GetCurrentMap(map, 128);
    
    char m_szAuth[32];
    if(!GetTrieString(g_aNominated_Auth, map, m_szAuth, 32))
        return Plugin_Stop;
    
    char m_szName[32];
    if(!GetTrieString(g_aNominated_Name, map, m_szName, 32))
        return Plugin_Stop;
    
    int client = FindClientByAuth(m_szAuth);
    
    ReplaceString(m_szAuth, 32, "STEAM_1:", "");
    
    if(!client)
        PrintToChatAll("[\x04MCE\x01]   当前地图是\x0C%s\x01(\x04%s\x01)预定的", m_szName, m_szAuth);
    else
        PrintToChatAll("[\x04MCE\x01]   当前地图是\x0C%N\x01(\x04%s\x01)预定的", client, m_szAuth);

    return Plugin_Continue;
}

int FindClientByAuth(const char[] steamid)
{
    char m_szAuth[32];
    for(int client = 1; client <= MaxClients; ++client)
        if(IsClientAuthorized(client))
            if(GetClientAuthId(client, AuthId_Steam2, m_szAuth, 32, true))
                if(StrEqual(m_szAuth, steamid))
                    return client;

    return 0;
}