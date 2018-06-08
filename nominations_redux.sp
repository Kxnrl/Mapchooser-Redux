#pragma semicolon 1
#pragma newdecls required

#include <mapchooser_redux>
#include <smutils>

#undef REQUIRE_PLUGIN
#include <store>
#include <shop>


ArrayList g_aMapList;
Handle g_hMapMenu;
int g_iMapFileSerial = -1;
bool g_pStore;
bool g_pShop;

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
    version     = MCR_VERSION,
    url         = "https://kxnrl.com"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    MarkNativeAsOptional("Store_GetClientCredits");
    MarkNativeAsOptional("Store_SetClientCredits");
    
    MarkNativeAsOptional("MG_Shop_ClientEarnMoney");
    MarkNativeAsOptional("MG_Shop_ClientCostMoney");

    return APLRes_Success;
}

public void OnPluginStart()
{
    SMUtils_SetChatPrefix("[\x02M\x04C\x0CR\x01]");
    SMUtils_SetChatSpaces("   ");
    SMUtils_SetChatConSnd(false);
    SMUtils_SetTextDest(HUD_PRINTCENTER);
    
    LoadTranslations("com.kxnrl.mcr.translations");
    
    int arraySize = ByteCountToCells(256);    
    g_aMapList = CreateArray(arraySize);

    g_aMapTrie = CreateTrie();
    g_aNominated_Auth = CreateTrie();
    g_aNominated_Name = CreateTrie();
}

public void OnLibraryAdded(const char[] name)
{
    if(strcmp(name, "store") == 0)
        g_pStore = true;
    else if(strcmp(name, "shop-core") == 0)
        g_pShop = true;
}

public void OnLibraryRemoved(const char[] name)
{
    if(strcmp(name, "store") == 0)
        g_pStore = false;
    else if(strcmp(name, "shop-core") == 0)
        g_pShop = false;
}

public void OnConfigsExecuted()
{
    g_pStore = LibraryExists("store");
    g_pShop = LibraryExists("shop-core");

    if(ReadMapList(g_aMapList, g_iMapFileSerial, "nominations", MAPLIST_FLAG_CLEARARRAY|MAPLIST_FLAG_MAPSFOLDER) == INVALID_HANDLE)
        if(g_iMapFileSerial == -1)
            SetFailState("Unable to create a valid map list.");

    CreateTimer(90.0, Timer_Broadcast, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
    char map[128];
    GetCurrentMap(map, 128);
    RemoveFromTrie(g_aNominated_Auth, map);
    RemoveFromTrie(g_aNominated_Name, map);

    if(g_hKvMapData != null)
        CloseHandle(g_hKvMapData);
    g_hKvMapData = null;
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

    if(StrContains(sArgs, "nominat", false) == -1 && strcmp(sArgs, "nextmap", false) != 0)
        return;

    if(!IsNominateAllowed(client))
        return;

    AttemptNominate(client);
}

void AttemptNominate(int client)
{
    SetMenuTitle(g_hMapMenu, "%T\n ", "nominate menu title", client);
    DisplayMenu(g_hMapMenu, client, MENU_TIME_FOREVER);
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
        if(GetMapDesc(map, szTrans, 256, true, FindConVar("mcr_include_descnametag").BoolValue))
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
            char map[128];
            GetMenuItem(menu, param2, map, 128);        

            NominateResult result = NominateMap(map, false, param1);

            if(result == NominateResult_NoCredits)
            {
                Chat(param1, "%T", "NominateResult_NoCredits", param1, map);
                return 0;
            }

            if(result == NominateResult_InvalidMap)
            {
                Chat(param1, "%T", "NominateResult_InvalidMap", param1, map);
                return 0;
            }

            if(result == NominateResult_AlreadyInVote)
            {
                Chat(param1, "%T", "NominateResult_AlreadyInVote", param1);
                return 0;
            }
            
            if(result == NominateResult_VoteFull)
            {
                Chat(param1, "%T", "NominateResult_VoteFull", param1);
                return 0;
            }
            
            if(result == NominateResult_OnlyAdmin)
            {
                Chat(param1, "%T", "NominateResult_OnlyAdmin", param1);
                return 0;
            }
            
            if(result == NominateResult_OnlyVIP)
            {
                Chat(param1, "%T", "NominateResult_OnlyVIP", param1);
                return 0;
            }

            if(result == NominateResult_MinPlayers)
            {
                Chat(param1, "%T", "NominateResult_MinPlayers", param1, GetMinPlayers(map));
                return 0;
            }
            
            if(result == NominateResult_MaxPlayers)
            {
                Chat(param1, "%T", "NominateResult_MaxPlayers", param1, GetMaxPlayers(map));
                return 0;
            }

            SetTrieValue(g_aMapTrie, map, MAPSTATUS_DISABLED|MAPSTATUS_EXCLUDE_NOMINATED);
            
            if(g_pStore)
            {
                int credits = GetMapPrice(map);
                Store_SetClientCredits(param1, Store_GetClientCredits(param1)-credits, "nomination-nominate");
                Chat(param1, "%T", "nominate nominate cost", param1, map, credits);
            }
            else if(g_pShop)
            {
                int credits = GetMapPrice(map);
                MG_Shop_ClientCostMoney(param1, credits, "nomination-nominate");
                Chat(param1, "%T", "nominate nominate cost", param1, map, credits);
            }

            char m_szAuth[32], m_szName[32];
            GetClientAuthId(param1, AuthId_Steam2, m_szAuth, 32, true);
            GetClientName(param1, m_szName, 32);
            SetTrieString(g_aNominated_Auth, map, m_szAuth, true);
            SetTrieString(g_aNominated_Name, map, m_szName, true);

            LogMessage("[MCR]  \"%L\" nominated %s", param1, map);

            if(result == NominateResult_Replaced)
                tChatAll("%t", "nominate changed map", param1, map);
            else
                tChatAll("%t", "nominate nominate map", param1, map);
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
                    Format(display, sizeof(display), "%s (%T)\n%s", buffer, "nominate menu current Map", param1, trans);
                    return RedrawMenuItem(display);
                }
                
                if((status & MAPSTATUS_EXCLUDE_PREVIOUS) == MAPSTATUS_EXCLUDE_PREVIOUS)
                {
                    Format(display, sizeof(display), "%s (%T)\n%s", buffer, "nominate menu recently played", param1, trans);
                    return RedrawMenuItem(display);
                }
                
                if((status & MAPSTATUS_EXCLUDE_NOMINATED) == MAPSTATUS_EXCLUDE_NOMINATED)
                {
                    Format(display, sizeof(display), "%s (%T)\n%s", buffer, "nominate menu was nominated", param1, trans);
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
            Chat(client, "%T", "nominate vote in progress", client);
            return false;
        }

        case CanNominate_No_VoteComplete:
        {
            char map[128];
            GetNextMap(map, 128);
            Chat(client, "%T", "nominate vote complete", client, map);
            return false;
        }
        
        case CanNominate_No_VoteFull:
        {
            Chat(client, "%T", "nominate full vote", client);
            return false;
        }
    }
    
    return true;
}

public void OnMapDataLoaded()
{
    if(g_hKvMapData != null)
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
        tChatAll("%t", "nominated by name", m_szName, m_szAuth);
    else
        tChatAll("%t", "nominated by client", client, m_szAuth);

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